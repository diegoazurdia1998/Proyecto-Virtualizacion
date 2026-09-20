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

@app.route('/clientes', methods=['GET'])
def get_clientes():
    query = "SELECT id, nombre, nit, direccion FROM clientes ORDER BY id ASC;"
    try:
        with db.get_cursor() as cur:
            cur.execute(query)
            clientes = cur.fetchall()
            return jsonify(clientes), 200
    except Exception as e:
        return jsonify({"error": "Error al consultar clientes", "detalle": str(e)}), 500

@app.route('/clientes', methods=['POST'])
def create_cliente():
    data = request.get_json() or {}
    nombre = data.get("nombre")
    nit = data.get("nit")
    direccion = data.get("direccion")

    if not nombre or not nit or not direccion:
        return jsonify({"error": "campos_requeridos", "mensaje": "nombre, nit y direccion son obligatorios"}), 400

    query = """
        INSERT INTO clientes (nombre, nit, direccion)
        VALUES (%s, %s, %s)
        RETURNING id, nombre, nit, direccion;
    """
    try:
        with db.get_cursor(commit=True) as cur:
            cur.execute(query, (nombre, nit, direccion))
            nuevo = cur.fetchone()
            return jsonify(nuevo), 201
    except Exception as e:
        return jsonify({"error": "Error al crear cliente", "detalle": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)