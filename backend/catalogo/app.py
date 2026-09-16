from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/categorias', methods=['GET'])
def get_categorias():
    mock_categorias = [
        {"id": 1, "nombre": "Abarrotes"},
        {"id": 2, "nombre": "Bebidas"},
        {"id": 3, "nombre": "Limpieza"}
    ]
    return jsonify(mock_categorias), 200

@app.route('/productos', methods=['GET'])
def get_productos():
    mock_productos = [
        {"id": 1, "sku": "QTZ-001", "nombre": "Café molido 500g", "categoria": "Abarrotes", "precio": 45.50},
        {"id": 2, "sku": "QTZ-007", "nombre": "Azúcar 1kg", "categoria": "Abarrotes", "precio": 9.50}
    ]
    return jsonify(mock_productos), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)