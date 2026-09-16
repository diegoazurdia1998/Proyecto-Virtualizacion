from flask import Flask, jsonify, request

app = Flask(__name__)

MOCK_INVENTARIO = [
    {"id": 1, "sku": "QTZ-001", "nombre": "Café molido 500g", "categoria": "Abarrotes", "precio": 45.50, "stock": 120},
    {"id": 2, "sku": "QTZ-007", "nombre": "Azúcar 1kg", "categoria": "Abarrotes", "precio": 9.50, "stock": 2}
]

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/productos', methods=['GET'])
def get_productos():
    return jsonify(MOCK_INVENTARIO), 200

@app.route('/productos', methods=['POST'])
def create_producto():
    data = request.get_json() or {}
    nuevo = {
        "id": len(MOCK_INVENTARIO) + 1,
        "sku": data.get("sku", "QTZ-999"),
        "nombre": data.get("nombre", "Producto Demo"),
        "categoria": data.get("categoria", "General"),
        "precio": float(data.get("precio", 0.0)),
        "stock": int(data.get("stock", 0))
    }
    MOCK_INVENTARIO.append(nuevo)
    return jsonify(nuevo), 201

@app.route('/productos/<int:prod_id>', methods=['PUT'])
def update_producto(prod_id):
    data = request.get_json() or {}
    for item in MOCK_INVENTARIO:
        if item["id"] == prod_id:
            item.update(data)
            return jsonify(item), 200
    return jsonify({"error": "not_found"}), 404

@app.route('/productos/<int:prod_id>', methods=['DELETE'])
def delete_producto(prod_id):
    global MOCK_INVENTARIO
    MOCK_INVENTARIO = [i for i in MOCK_INVENTARIO if i["id"] != prod_id]
    return jsonify({"status": "deleted"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)