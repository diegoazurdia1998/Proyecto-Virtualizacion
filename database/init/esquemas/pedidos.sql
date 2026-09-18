-- Pedidos: encabezado y detalle. El carné del integrante que lo creó es
-- obligatorio y queda persistido (evidencia personalizada).
-- cliente_id y sku no llevan llave foránea: viven en otras bases.

CREATE TABLE pedidos (
    id         SERIAL PRIMARY KEY,
    cliente_id INTEGER       NOT NULL,
    carne      VARCHAR(10)   NOT NULL,
    estado     VARCHAR(12)   NOT NULL DEFAULT 'CONFIRMADO'
               CHECK (estado IN ('CONFIRMADO','RECHAZADO','ANULADO')),
    total      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    creado_en  TIMESTAMP     NOT NULL DEFAULT NOW()
);

CREATE TABLE pedido_detalle (
    id              SERIAL PRIMARY KEY,
    pedido_id       INTEGER       NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    sku             VARCHAR(20)   NOT NULL,
    nombre_producto VARCHAR(100)  NOT NULL,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

CREATE INDEX idx_pedidos_fecha ON pedidos (creado_en);
CREATE INDEX idx_pedidos_carne ON pedidos (carne);
CREATE INDEX idx_detalle_pedido ON pedido_detalle (pedido_id);
