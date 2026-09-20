from flask import Flask, jsonify, request
import requests
from config import Config
from db import Database

app = Flask(__name__)
db = Database(
    host=Config.DB_HOST,
    port=Config.DB_PORT,
    dbname=Config.DB_NAME,
    user=Config.DB_USER,
    password=Config.DB_PASSWORD
)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/pedidos', methods=['GET'])
def get_pedidos():
    # Usamos creado_en AS fecha para respetar el contrato JSON
    query = """
        SELECT id AS pedido_id, carne, cliente_id, creado_en AS fecha, total::float, estado 
        FROM pedidos 
        ORDER BY id DESC;
    """
    try:
        with db.get_cursor() as cur:
            cur.execute(query)
            pedidos = cur.fetchall()
            for p in pedidos:
                if p.get("fecha"):
                    p["fecha"] = p["fecha"].isoformat()
            return jsonify(pedidos), 200
    except Exception as e:
        return jsonify({"error": "error_db", "detalle": str(e)}), 500


@app.route('/pedidos', methods=['POST'])
def create_pedido():
    data = request.get_json() or {}
    carne = data.get("carne")
    cliente_id = data.get("cliente_id")
    items = data.get("items", [])

    if not carne or not cliente_id or not items:
        return jsonify({"error": "datos_incompletos", "mensaje": "carne, cliente_id e items son obligatorios"}), 400

    # 1. Validación y descuento atómico vía HTTP al microservicio de inventario
    url_inventario = f"{Config.INVENTARIO_SERVICE_URL}/descontar-stock"
    try:
        resp_inv = requests.post(url_inventario, json={"items": items, "carne": str(carne)}, timeout=10)
    except requests.exceptions.RequestException as e:
        return jsonify({"error": "servicio_inventario_no_disponible", "detalle": str(e)}), 503

    if resp_inv.status_code != 200:
        return jsonify(resp_inv.json()), resp_inv.status_code

    datos_inventario = resp_inv.json()
    total_pedido = datos_inventario.get("total", 0.0)
    items_procesados = datos_inventario.get("items_procesados", [])

    # 2. Insertar cabecera usando creado_en (DEFAULT NOW())
    query_pedido = """
        INSERT INTO pedidos (carne, cliente_id, total, estado)
        VALUES (%s, %s, %s, 'CONFIRMADO')
        RETURNING id, carne, creado_en, total::float, estado;
    """
    query_detalle = """
        INSERT INTO pedido_detalle (pedido_id, sku, nombre_producto, cantidad, precio_unitario)
        VALUES (%s, %s, %s, %s, %s);
    """

    with db.get_connection() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(query_pedido, (str(carne), cliente_id, total_pedido))
                pedido_creado = cur.fetchone()
                pedido_id = pedido_creado[0]
                fecha_pedido = pedido_creado[2].isoformat()

                for item in items_procesados:
                    cur.execute(query_detalle, (
                        pedido_id,
                        item["sku"],
                        item["nombre"],
                        item["cantidad"],
                        item["precio"]
                    ))

                conn.commit()

                return jsonify({
                    "pedido_id": pedido_id,
                    "carne": str(carne),
                    "fecha": fecha_pedido,
                    "total": total_pedido,
                    "estado": "CONFIRMADO"
                }), 201

        except Exception as e:
            conn.rollback()
            return jsonify({"error": "error_guardando_pedido", "detalle": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)