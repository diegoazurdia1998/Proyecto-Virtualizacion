import os
import requests
from flask import Flask, jsonify
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

INVENTARIO_SERVICE_URL = os.getenv("INVENTARIO_SERVICE_URL", "http://api-inventario:5000")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/categorias', methods=['GET'])
def get_categorias():
    query = "SELECT id, nombre FROM categorias ORDER BY id ASC;"
    try:
        with db.get_cursor() as cur:
            cur.execute(query)
            categorias = cur.fetchall()
            return jsonify(categorias), 200
    except Exception as e:
        return jsonify({"error": "Error al consultar categorias", "detalle": str(e)}), 500

@app.route('/equipo', methods=['GET'])
def get_equipo():
    # Consulta a la tabla equipo en db_catalogo para carnés en UI
    query = "SELECT carne, nombre, rol FROM equipo ORDER BY id ASC;"
    try:
        with db.get_cursor() as cur:
            cur.execute(query)
            equipo = cur.fetchall()
            return jsonify(equipo), 200
    except Exception as e:
        return jsonify({"error": "Error al consultar equipo", "detalle": str(e)}), 500

@app.route('/productos', methods=['GET'])
def get_productos_catalogo():
    # Respeta la regla: pide los productos por HTTP al dueño de la tabla (inventario)
    try:
        resp = requests.get(f"{INVENTARIO_SERVICE_URL}/productos", timeout=5)
        return jsonify(resp.json()), resp.status_code
    except requests.exceptions.RequestException as e:
        return jsonify({"error": "No se pudo comunicar con el servicio de inventario", "detalle": str(e)}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)