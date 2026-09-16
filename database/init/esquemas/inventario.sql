-- Inventario: dueño de los productos y del stock.
-- El CHECK de stock es la última línea de defensa de la regla de negocio:
-- aunque la aplicación falle, la base no deja que el stock quede negativo.

CREATE TABLE productos (
    id             SERIAL PRIMARY KEY,
    sku            VARCHAR(20)   NOT NULL UNIQUE,
    nombre         VARCHAR(100)  NOT NULL,
    categoria      VARCHAR(60)   NOT NULL,
    precio         NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    stock          INTEGER       NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo   INTEGER       NOT NULL DEFAULT 10,
    creado_por     VARCHAR(10),
    creado_en      TIMESTAMP     NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- Bitácora de cada entrada y salida de stock. Deja rastro de qué pedido
-- descontó qué producto y qué carné lo hizo.
CREATE TABLE movimientos_stock (
    id          SERIAL PRIMARY KEY,
    producto_id INTEGER     NOT NULL REFERENCES productos(id),
    tipo        VARCHAR(10) NOT NULL CHECK (tipo IN ('ENTRADA','SALIDA','AJUSTE')),
    cantidad    INTEGER     NOT NULL CHECK (cantidad > 0),
    pedido_id   INTEGER,
    carne       VARCHAR(10),
    creado_en   TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_productos_categoria ON productos (categoria);
CREATE INDEX idx_movimientos_producto ON movimientos_stock (producto_id);
