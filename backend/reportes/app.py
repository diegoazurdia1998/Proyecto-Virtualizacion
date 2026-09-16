from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/dashboard', methods=['GET'])
def get_dashboard():
    # Responde exactamente según el formato pactado en el contrato
    data = {
        "total_productos": 48,
        "valor_inventario": 152430.75,
        "pedidos_hoy": 6,
        "stock_bajo": [
            {"sku": "QTZ-007", "nombre": "Azúcar 1kg", "stock": 2}
        ]
    }
    return jsonify(data), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)