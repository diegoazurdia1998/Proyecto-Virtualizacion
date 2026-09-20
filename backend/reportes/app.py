import os
from datetime import datetime
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
PEDIDOS_SERVICE_URL = os.getenv("PEDIDOS_SERVICE_URL", "http://api-pedidos:5000")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/dashboard', methods=['GET'])
def get_dashboard():
    # 1. Obtener lista de productos desde el microservicio de inventario
    try:
        resp_inv = requests.get(f"{INVENTARIO_SERVICE_URL}/productos", timeout=5)
        if resp_inv.status_code != 200:
            return jsonify({"error": "Fallo al consultar el servicio de inventario"}), 502
        productos = resp_inv.json()
    except requests.exceptions.RequestException as e:
        return jsonify({"error": "No se pudo conectar con api-inventario", "detalle": str(e)}), 503

    # 2. Obtener lista de pedidos desde el microservicio de pedidos
    try:
        resp_ped = requests.get(f"{PEDIDOS_SERVICE_URL}/pedidos", timeout=5)
        if resp_ped.status_code != 200:
            return jsonify({"error": "Fallo al consultar el servicio de pedidos"}), 502
        pedidos = resp_ped.json()
    except requests.exceptions.RequestException as e:
        return jsonify({"error": "No se pudo conectar con api-pedidos", "detalle": str(e)}), 503

    # 3. Calcular métricas de inventario
    total_productos = len(productos)
    valor_inventario = 0.0
    stock_bajo = []

    for item in productos:
        stock = int(item.get("stock", 0))
        precio = float(item.get("precio", 0.0))
        valor_inventario += (stock * precio)

        # Umbral fijado en el contrato: menos de 10 unidades
        if stock < 10:
            stock_bajo.append({
                "sku": item.get("sku"),
                "nombre": item.get("nombre"),
                "stock": stock
            })

    # 4. Calcular pedidos del día actual
    hoy_str = datetime.now().strftime("%Y-%m-%d")
    pedidos_hoy = 0

    for ped in pedidos:
        fecha_ped = ped.get("fecha", "")
        # Extrae la porción de fecha YYYY-MM-DD del timestamp ISO
        if fecha_ped and fecha_ped[:10] == hoy_str:
            pedidos_hoy += 1

    # 5. Registrar consulta en bitacora de db_reportes (opcional/auditoría)
    try:
        with db.get_cursor(commit=True) as cur:
            cur.execute("INSERT INTO bitacora_consultas (endpoint) VALUES ('/dashboard');")
    except Exception:
        pass  # Si la tabla aún no existe, no interrumpe la respuesta del dashboard

    # 6. Respuesta idéntica al contrato
    resultado = {
        "total_productos": total_productos,
        "valor_inventario": round(valor_inventario, 2),
        "pedidos_hoy": pedidos_hoy,
        "stock_bajo": stock_bajo
    }

    return jsonify(resultado), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)