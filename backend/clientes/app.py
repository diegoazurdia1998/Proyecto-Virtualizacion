from flask import Flask, jsonify, request

app = Flask(__name__)

MOCK_CLIENTES = [
    {"id": 1, "nombre": "Tienda La Bendición", "nit": "1234567-8", "direccion": "Zona 1, Ciudad de Guatemala"},
    {"id": 2, "nombre": "Abarrotes El Triunfo", "nit": "8765432-1", "direccion": "Zona 11, Ciudad de Guatemala"},
    {"id": 3, "nombre": "Minisuper Express", "nit": "9988776-5", "direccion": "Mixco, Guatemala"}
]

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/clientes', methods=['GET'])
def get_clientes():
    return jsonify(MOCK_CLIENTES), 200

@app.route('/clientes', methods=['POST'])
def create_cliente():
    data = request.get_json() or {}
    nuevo = {
        "id": len(MOCK_CLIENTES) + 1,
        "nombre": data.get("nombre", ""),
        "nit": data.get("nit", ""),
        "direccion": data.get("direccion", "")
    }
    MOCK_CLIENTES.append(nuevo)
    return jsonify(nuevo), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)