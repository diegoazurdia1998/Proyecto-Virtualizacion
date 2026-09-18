from flask import Flask, jsonify, request
from datetime import datetime

app = Flask(__name__)

MOCK_PEDIDOS = [
    {
        "pedido_id": 1,
        "carne": "2528119",
        "cliente_id": 1,
        "fecha": "2026-09-15T10:30:00",
        "total": 91.00,
        "estado": "CONFIRMADO"
    }
]

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/pedidos', methods=['GET'])
def get_pedidos():
    return jsonify(MOCK_PEDIDOS), 200

@app.route('/pedidos', methods=['POST'])
def create_pedido():
    data = request.get_json() or {}
    carne = data.get("carne")
    cliente_id = data.get("cliente_id")
    items = data.get("items", [])

    if not carne or not items:
        return jsonify({"error": "datos_incompletos"}), 400

    # Simulación de validación de stock según el contrato (Fase 1: Mock)
    for item in items:
        if item.get("sku") == "QTZ-007" and item.get("cantidad", 0) > 2:
            return jsonify({
                "error": "stock_insuficiente",
                "detalle": [
                    {"sku": "QTZ-007", "solicitado": item.get("cantidad"), "disponible": 2}
                ]
            }), 409

    nuevo_pedido = {
        "pedido_id": len(MOCK_PEDIDOS) + 1,
        "carne": str(carne),
        "fecha": datetime.now().isoformat(timespec='seconds'),
        "total": 136.50,
        "estado": "CONFIRMADO"
    }
    MOCK_PEDIDOS.append(nuevo_pedido)
    return jsonify(nuevo_pedido), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)