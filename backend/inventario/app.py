from flask import Flask, jsonify, request
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

# CRUD de productos según Contrato
@app.route('/productos', methods=['GET'])
def get_productos():
    query = "SELECT id, sku, nombre, categoria, precio::float, stock FROM productos ORDER BY id ASC;"
    try:
        with db.get_cursor() as cur:
            cur.execute(query)
            return jsonify(cur.fetchall()), 200
    except Exception as e:
        return jsonify({"error": "error_db", "detalle": str(e)}), 500

@app.route('/productos', methods=['POST'])
def create_producto():
    data = request.get_json() or {}
    sku = data.get("sku")
    nombre = data.get("nombre")
    categoria = data.get("categoria")
    precio = data.get("precio")
    stock = data.get("stock")

    if not all([sku, nombre, categoria, precio is not None, stock is not None]):
        return jsonify({"error": "campos_incompletos"}), 400

    query = """
        INSERT INTO productos (sku, nombre, categoria, precio, stock)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id, sku, nombre, categoria, precio::float, stock;
    """
    try:
        with db.get_cursor(commit=True) as cur:
            cur.execute(query, (sku, nombre, categoria, precio, stock))
            return jsonify(cur.fetchone()), 201
    except Exception as e:
        return jsonify({"error": "error_db", "detalle": str(e)}), 500

@app.route('/productos/<int:prod_id>', methods=['PUT'])
def update_producto(prod_id):
    data = request.get_json() or {}
    query = """
        UPDATE productos 
        SET nombre = COALESCE(%s, nombre),
            categoria = COALESCE(%s, categoria),
            precio = COALESCE(%s, precio),
            stock = COALESCE(%s, stock)
        WHERE id = %s
        RETURNING id, sku, nombre, categoria, precio::float, stock;
    """
    try:
        with db.get_cursor(commit=True) as cur:
            cur.execute(query, (data.get("nombre"), data.get("categoria"), data.get("precio"), data.get("stock"), prod_id))
            actualizado = cur.fetchone()
            if not actualizado:
                return jsonify({"error": "producto_no_encontrado"}), 404
            return jsonify(actualizado), 200
    except Exception as e:
        return jsonify({"error": "error_db", "detalle": str(e)}), 500

@app.route('/productos/<int:prod_id>', methods=['DELETE'])
def delete_producto(prod_id):
    query = "DELETE FROM productos WHERE id = %s RETURNING id;"
    try:
        with db.get_cursor(commit=True) as cur:
            cur.execute(query, (prod_id,))
            eliminado = cur.fetchone()
            if not eliminado:
                return jsonify({"error": "producto_no_encontrado"}), 404
            return jsonify({"status": "deleted", "id": prod_id}), 200
    except Exception as e:
        return jsonify({"error": "error_db", "detalle": str(e)}), 500

# Endpoint Transaccional Atómico invocado por el servicio de Pedidos
@app.route('/descontar-stock', methods=['POST'])
def descontar_stock():
    data = request.get_json() or {}
    items = data.get("items", [])
    carne = data.get("carne")

    if not items:
        return jsonify({"error": "items_requeridos"}), 400

    detalle_faltante = []
    productos_a_descontar = []
    total_pedido = 0.0

    # Usamos conexión directa para controlar BEGIN, COMMIT y ROLLBACK explícitos
    with db.get_connection() as conn:
        try:
            with conn.cursor() as cur:
                for item in items:
                    sku = item.get("sku")
                    cantidad = int(item.get("cantidad", 0))

                    # Bloqueo de fila exclusivo durante la transacción
                    cur.execute("""
                        SELECT id, sku, nombre, precio::float, stock
                        FROM productos
                        WHERE sku = %s
                        FOR UPDATE;
                    """, (sku,))
                    prod = cur.fetchone()

                    if not prod:
                        detalle_faltante.append({"sku": sku, "solicitado": cantidad, "disponible": 0})
                    elif prod[4] < cantidad:
                        detalle_faltante.append({"sku": sku, "solicitado": cantidad, "disponible": prod[4]})
                    else:
                        subtotal = prod[3] * cantidad
                        total_pedido += subtotal
                        productos_a_descontar.append({
                            "id": prod[0],
                            "sku": sku,
                            "nombre": prod[2],
                            "cantidad": cantidad,
                            "precio": prod[3],
                            "subtotal": round(subtotal, 2),
                            "nuevo_stock": prod[4] - cantidad
                        })

                # Si algún SKU no tiene stock suficiente, revertir y retornar HTTP 409
                if detalle_faltante:
                    conn.rollback()
                    return jsonify({
                        "error": "stock_insuficiente",
                        "detalle": detalle_faltante
                    }), 409

                # Si todo está en orden, descontar y registrar movimientos
                for p in productos_a_descontar:
                    cur.execute(
                        "UPDATE productos SET stock = %s, actualizado_en = NOW() WHERE id = %s;",
                        (p["nuevo_stock"], p["id"])
                    )
                    cur.execute("""
                        INSERT INTO movimientos_stock (producto_id, tipo, cantidad, carne)
                        VALUES (%s, 'SALIDA', %s, %s);
                    """, (p["id"], p["cantidad"], carne))

                conn.commit()

                return jsonify({
                    "status": "stock_descontado",
                    "total": round(total_pedido, 2),
                    "items_procesados": productos_a_descontar
                }), 200

        except Exception as e:
            conn.rollback()
            return jsonify({"error": "error_transaccion", "detalle": str(e)}), 500
        
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)