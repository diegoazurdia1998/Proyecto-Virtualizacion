-- Productos de prueba. Los tres últimos quedan por debajo del stock mínimo
-- a propósito, para que la alerta de stock bajo del dashboard tenga qué mostrar.
INSERT INTO productos (sku, nombre, categoria, precio, stock, stock_minimo, creado_por) VALUES
    ('QTZ-001', 'Café molido 500g',          'Abarrotes',      45.50, 120, 10, '1182222'),
    ('QTZ-002', 'Aceite vegetal 1L',         'Abarrotes',      28.75,  80, 10, '1182222'),
    ('QTZ-003', 'Gaseosa 2.5L',              'Bebidas',        18.00, 200, 20, '1283220'),
    ('QTZ-004', 'Agua pura 1 galón',         'Bebidas',        12.50, 150, 20, '1283220'),
    ('QTZ-005', 'Leche entera 1L',           'Lácteos',        14.25,  60, 15, '2528119'),
    ('QTZ-006', 'Queso fresco libra',        'Lácteos',        38.00,  40, 10, '2528119'),
    ('QTZ-007', 'Detergente en polvo 1kg',   'Limpieza',       32.90,  75, 10, '1163722'),
    ('QTZ-008', 'Jabón de lavar trastos',    'Limpieza',        9.75, 110, 15, '1163722'),
    ('QTZ-009', 'Frijol negro quintal',      'Granos básicos', 610.00,  25,  5, '1224323'),
    ('QTZ-010', 'Arroz blanco quintal',      'Granos básicos', 480.00,  30,  5, '1224323'),
    ('QTZ-011', 'Azúcar blanca 5 libras',    'Granos básicos',  42.00,   6, 10, '1182222'),
    ('QTZ-012', 'Maíz blanco quintal',       'Granos básicos', 395.00,   3,  5, '1182222');

INSERT INTO movimientos_stock (producto_id, tipo, cantidad, carne) VALUES
    (1,  'ENTRADA', 120, '1182222'),
    (11, 'ENTRADA',   6, '1182222'),
    (12, 'ENTRADA',   3, '1182222');
