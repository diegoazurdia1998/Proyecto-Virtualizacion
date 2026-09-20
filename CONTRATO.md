# Contrato de interfaz — El Quetzal

Equipo **Virtual Insanity** · Virtualización · Ingeniería en Informática y Sistemas · URL

Acuerdos cerrados en la reunión inicial. Todo lo que está aquí es fijo: si algo cambia,
se cambia primero en este archivo y se avisa al grupo.

---

## 1. Identificadores del equipo

| Dato | Valor |
|---|---|
| Nombre del equipo | Virtual Insanity |
| Hostname de la VM | `srv-elquetzal-virtualinsanity` |
| Namespace en Docker Hub | `virtual4insanity` |
| Repositorio | https://github.com/diegoazurdia1998/Proyecto-Virtualizacion |
| Etiqueta de imágenes | `virtual4insanity/elquetzal-<servicio>:1.0` |

## 2. Integrantes y roles

Los carnés van sembrados en la base de datos, se ven en la UI y quedan registrados en
cada pedido.

| Nombre | Carné | Rol |
|---|---|---|
| Rochelle Giulianne Esquivel Vargas | 1283220 | Infraestructura y gateway |
| Oscar Javier Ortíz Pocón | 1182222 | Datos y persistencia |
| Diego Andrés Azurdia Ortíz | 2528119 | Backend de dominio |
| Diego Oswaldo Orellana Morales | 1163722 | Frontend Vue |
| Susana Paola García García | 1224323 | Orquestación, costos y documentación |

## 3. Estructura del repositorio

```
Proyecto-Virtualizacion/
├── .env.example
├── .gitignore
├── CONTRATO.md
├── README.md
├── docker-compose.yml
├── docker-compose.override.yml   Publica puertos mientras no existe el gateway
├── backend/          catalogo/ inventario/ clientes/ pedidos/ reportes/
├── database/         script de inicialización, esquemas y seeds
├── docs/             diagrama, modelo de datos, mapa de propiedad, costos, evidencias
├── frontend/         proyecto Vue
└── gateway/          Dockerfile de nginx y nginx.conf, scripts de la VM
```

## 4. Nombres de servicios en la red Docker

Estos nombres son los que usa nginx y los que usan los servicios entre sí. No se cambian.

| Servicio | Nombre en la red | Puerto interno | Publicado al host |
|---|---|---|---|
| Gateway (nginx) | `gateway` | 80 | 8080 |
| Catálogo | `api-catalogo` | 5000 | no |
| Inventario | `api-inventario` | 5000 | no |
| Clientes | `api-clientes` | 5000 | no |
| Pedidos | `api-pedidos` | 5000 | no |
| Reportes | `api-reportes` | 5000 | no |
| Postgres | `db` | 5432 | no |

Red interna: `elquetzal-net`. Volumen de datos: `elquetzal-pgdata`.

Mientras el gateway no esté listo, el `docker-compose.override.yml` publica cada servicio al
host para poder probarlo: inventario 5000, catálogo 5001, clientes 5002, pedidos 5003,
reportes 5004 y Postgres 5432. Ese archivo se elimina cuando el gateway entre, y la tabla de
arriba vuelve a ser la única verdad.

## 5. Bases de datos y usuarios

Un solo motor Postgres, una base por microservicio, cada una con su usuario. Ningún
servicio entra a la base de otro: si necesita un dato ajeno, lo pide por HTTP.

| Servicio | Base de datos | Usuario |
|---|---|---|
| Catálogo | `db_catalogo` | `usr_catalogo` |
| Inventario | `db_inventario` | `usr_inventario` |
| Clientes | `db_clientes` | `usr_clientes` |
| Pedidos | `db_pedidos` | `usr_pedidos` |
| Reportes | `db_reportes` | `usr_reportes` |

Las contraseñas viven en el `.env`, nunca en el código ni en el repo.

## 6. Rutas de la API

El gateway enruta `/api/<servicio>/` a cada microservicio y sirve el build de Vue en `/`.
Todos los servicios exponen `GET /api/<servicio>/health` que responde `{"status":"ok"}`.

| Método y ruta | Servicio | Qué hace |
|---|---|---|
| `GET /api/catalogo/categorias` | catálogo | Lista de categorías |
| `GET /api/catalogo/productos` | catálogo | Catálogo de productos |
| `GET /api/catalogo/equipo` | catálogo | Integrantes del equipo con su carné |
| `GET /api/inventario/productos` | inventario | Lista productos con stock |
| `POST /api/inventario/productos` | inventario | Crea producto |
| `PUT /api/inventario/productos/<id>` | inventario | Edita producto |
| `DELETE /api/inventario/productos/<id>` | inventario | Elimina producto |
| `GET /api/clientes/clientes` | clientes | Lista de clientes |
| `POST /api/clientes/clientes` | clientes | Crea cliente |
| `POST /api/pedidos/pedidos` | pedidos | Crea pedido y descuenta stock |
| `GET /api/pedidos/pedidos` | pedidos | Lista de pedidos con carné |
| `GET /api/reportes/dashboard` | reportes | Métricas del dashboard |

`POST /descontar-stock` de inventario es de uso interno: lo llama el servicio de pedidos por
la red de Docker y no se expone en el gateway.

### Formato de un producto

```json
{
  "id": 1,
  "sku": "QTZ-001",
  "nombre": "Café molido 500g",
  "categoria": "Abarrotes",
  "precio": 45.50,
  "stock": 120
}
```

## 7. Transacción crítica: POST /api/pedidos/pedidos

Es el único endpoint que no se puede improvisar. El frontend manda:

```json
{
  "carne": "1182222",
  "cliente_id": 3,
  "items": [
    { "sku": "QTZ-001", "cantidad": 2 },
    { "sku": "QTZ-007", "cantidad": 1 }
  ]
}
```

El total no se envía: lo calcula el servicio con el precio que está en la base, para que el
navegador no pueda alterarlo.

Respuesta cuando el pedido se confirma (HTTP 201):

```json
{
  "pedido_id": 12,
  "carne": "1182222",
  "fecha": "2026-09-12T14:30:00",
  "total": 136.50,
  "estado": "CONFIRMADO"
}
```

Respuesta cuando algún producto no alcanza (HTTP 409). No se descuenta nada y el pedido
no se crea:

```json
{
  "error": "stock_insuficiente",
  "detalle": [
    { "sku": "QTZ-007", "solicitado": 5, "disponible": 2 }
  ]
}
```

Regla: la validación de stock y el descuento van dentro de una sola transacción. O se
confirma el pedido completo y se descuentan todos los productos, o no pasa nada.

Como pedidos e inventario tienen bases separadas, la transacción la ejecuta el servicio de
**inventario** sobre `db_inventario`, y pedidos se la pide por HTTP. Dentro de esa
transacción, cada producto se bloquea con `SELECT ... FOR UPDATE` y el stock se descuenta
restando, nunca escribiendo un valor absoluto.

Si un pedido trae el mismo SKU en varios renglones, las cantidades se suman antes de
validar. De lo contrario cada renglón se compara contra el mismo stock inicial y entre
todos alcanzan a descontar más de lo que hay.

## 8. Dashboard

`GET /api/reportes/dashboard` responde:

```json
{
  "total_productos": 48,
  "valor_inventario": 152430.75,
  "pedidos_hoy": 6,
  "stock_bajo": [
    { "sku": "QTZ-007", "nombre": "Azúcar 1kg", "stock": 2 }
  ]
}
```

Umbral de stock bajo: menos de 10 unidades. Las métricas las calcula el servicio de
reportes consultando a inventario y a pedidos; el frontend solo las muestra.

## 9. Reglas de trabajo en el repo

- Ramas: `main` (solo código integrado y probado), `develop` (integración),
  `feature/<area>-<tarea>`.
- Nadie hace push directo a `main`.
- Pull Request hacia `develop`, con al menos un compañero que revise y apruebe.
- Commits cortos y descriptivos, por ejemplo `feat(pedidos): valida stock antes de confirmar`.
- Cada quien trabaja en su carpeta. Si hay que tocar la carpeta de otro, se avisa al grupo
  para que pueda explicar el cambio en la defensa.
- El archivo `.env` real nunca se sube. Solo se versiona `.env.example`.