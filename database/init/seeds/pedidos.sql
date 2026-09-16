-- Dos pedidos de ejemplo con fecha de hoy, para que el dashboard muestre
-- "pedidos del día" desde el primer arranque.
INSERT INTO pedidos (cliente_id, carne, estado, total) VALUES
    (1, '1182222', 'CONFIRMADO', 227.50),
    (3, '2528119', 'CONFIRMADO', 189.75);

INSERT INTO pedido_detalle (pedido_id, sku, nombre_producto, cantidad, precio_unitario) VALUES
    (1, 'QTZ-001', 'Café molido 500g',        5, 45.50),
    (2, 'QTZ-003', 'Gaseosa 2.5L',           10, 18.00),
    (2, 'QTZ-008', 'Jabón de lavar trastos',  1,  9.75);
