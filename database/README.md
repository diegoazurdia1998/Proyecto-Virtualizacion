# Capa de datos — El Quetzal

Un solo motor Postgres con cinco bases independientes, una por microservicio, cada una
con su propio usuario. Responsable: Oscar Javier Ortíz Pocón (1182222).

## Qué hay en esta carpeta

```
database/
├── docker-compose.db.yml    Compose de prueba, solo para levantar la BD sola
├── init/
│   ├── 01-crear-bases.sh    Crea usuarios, bases, y aplica esquemas y seeds
│   ├── esquemas/            Tablas de cada servicio
│   └── seeds/               Datos de prueba, incluidos los carnés del equipo
└── README.md
```

La imagen de Postgres ejecuta `01-crear-bases.sh` sola, la primera vez que arranca y
solo si el volumen está vacío. Si el volumen ya tiene datos, no vuelve a correr.

## Cómo se conecta cada servicio

Todos apuntan al host `db`, puerto `5432`, dentro de la red interna de Docker. Postgres
no se publica al host en el compose final: solo el gateway sale al exterior.

| Servicio | Base | Usuario | Variables que lee del .env |
|---|---|---|---|
| catálogo | `db_catalogo` | `usr_catalogo` | `CATALOGO_DB`, `CATALOGO_DB_USER`, `CATALOGO_DB_PASSWORD` |
| inventario | `db_inventario` | `usr_inventario` | `INVENTARIO_DB`, `INVENTARIO_DB_USER`, `INVENTARIO_DB_PASSWORD` |
| clientes | `db_clientes` | `usr_clientes` | `CLIENTES_DB`, `CLIENTES_DB_USER`, `CLIENTES_DB_PASSWORD` |
| pedidos | `db_pedidos` | `usr_pedidos` | `PEDIDOS_DB`, `PEDIDOS_DB_USER`, `PEDIDOS_DB_PASSWORD` |
| reportes | `db_reportes` | `usr_reportes` | `REPORTES_DB`, `REPORTES_DB_USER`, `REPORTES_DB_PASSWORD` |

Cadena de conexión para Flask:

```
postgresql://usr_inventario:CLAVE@db:5432/db_inventario
```

Ningún usuario puede conectarse a la base de otro servicio. Está revocado a propósito:
si inventario necesita un dato de clientes, lo pide por HTTP, no por SQL. Eso se puede
comprobar en la demo.

## Qué tabla vive en cada base

| Base | Tablas | Nota |
|---|---|---|
| `db_catalogo` | `categorias`, `equipo` | `equipo` alimenta los carnés que se ven en la UI |
| `db_inventario` | `productos`, `movimientos_stock` | Dueño del stock. Aquí ocurre el descuento atómico |
| `db_clientes` | `clientes` | |
| `db_pedidos` | `pedidos`, `pedido_detalle` | `carne` es obligatorio en cada pedido |
| `db_reportes` | `metricas_cache`, `bitacora_consultas` | No guarda datos de negocio, solo el cálculo |

No hay llaves foráneas entre bases porque están separadas. `pedidos.cliente_id` y
`pedido_detalle.sku` son referencias lógicas que el servicio valida por HTTP.

## La regla de negocio, desde la base

`productos.stock` tiene un `CHECK (stock >= 0)`. Si la aplicación intentara descontar más
de lo que hay, Postgres rechaza el UPDATE y la transacción completa se revierte. Probado:

```sql
BEGIN;
UPDATE productos SET stock = stock - 5  WHERE sku = 'QTZ-001';  -- alcanza
UPDATE productos SET stock = stock - 10 WHERE sku = 'QTZ-012';  -- solo hay 3
COMMIT;
-- ERROR: violates check constraint "productos_stock_check" → ROLLBACK
-- Ningún producto se movió, ni siquiera el primero.
```

Para el servicio de pedidos, el orden correcto es: abrir transacción, bloquear las filas
con `SELECT ... FOR UPDATE`, descontar, registrar el movimiento y hacer commit. El
`FOR UPDATE` evita que dos pedidos simultáneos lean el mismo stock.

## Consultas del dashboard

```sql
-- Total de productos y valor del inventario en Q (db_inventario)
SELECT COUNT(*) AS total_productos,
       COALESCE(SUM(precio * stock), 0) AS valor_inventario
FROM productos;

-- Alerta de stock bajo (db_inventario)
SELECT sku, nombre, stock FROM productos
WHERE stock < stock_minimo ORDER BY stock;

-- Pedidos del día (db_pedidos)
SELECT COUNT(*) FROM pedidos
WHERE creado_en::date = CURRENT_DATE AND estado = 'CONFIRMADO';
```

## Cómo probarlo

Desde la raíz del repo, con el `.env` ya creado a partir de `.env.example`:

```bash
docker compose -f database/docker-compose.db.yml up -d
docker logs elquetzal-db-1182222        # debe terminar en "Las 5 bases quedaron listas"
docker exec -it elquetzal-db-1182222 psql -U usr_inventario -d db_inventario -c "\dt"
```

Prueba de persistencia, que es criterio de evaluación:

```bash
docker compose -f database/docker-compose.db.yml down
docker compose -f database/docker-compose.db.yml up -d
# Los datos siguen ahí porque el volumen elquetzal-pgdata no se borra.
```

Ojo: `down -v` sí borra el volumen. Solo usarlo cuando se quiera volver a correr los
scripts de init desde cero.

## Datos de prueba

Cinco categorías, doce productos con precios en quetzales, cinco clientes y dos pedidos
con fecha del día. Los productos QTZ-011 y QTZ-012 quedan a propósito por debajo de su
stock mínimo para que la alerta del dashboard tenga qué mostrar. Los cinco carnés del
equipo están sembrados en `equipo` y repartidos en `productos.creado_por`,
`clientes.creado_por` y `pedidos.carne`.
