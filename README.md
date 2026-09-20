# El Quetzal sobre infraestructura virtualizada

Equipo **Virtual Insanity** · Virtualización · Ingeniería en Informática y Sistemas · Universidad Rafael Landívar

Aplicación web de inventario y pedidos para Distribuidora El Quetzal, S.A., construida como una
arquitectura de microservicios en contenedores. Todo el stack corre dentro de una máquina virtual
Ubuntu Server provisionada en VirtualBox.

## Qué hace

- **Inventario:** listar, crear, editar y eliminar productos (SKU, nombre, categoría, precio en Q y stock).
- **Pedidos:** se arma un pedido con productos y cantidades. El sistema valida el stock, rechaza el
  pedido completo si algún producto no alcanza y, al confirmar, descuenta el inventario en una sola
  transacción. Cada pedido guarda el carné del integrante que lo creó.
- **Dashboard:** total de productos, valor del inventario en quetzales, pedidos del día y alerta de
  stock bajo.

## Arquitectura

| Componente | Nombre en la red | Puerto interno | Qué hace |
|---|---|---|---|
| Gateway (nginx) | `gateway` | 80 | Sirve el build de Vue en `/` y enruta `/api/<servicio>/` |
| Catálogo | `api-catalogo` | 5000 | Categorías y catálogo de productos |
| Inventario | `api-inventario` | 5000 | Productos, stock y descuento transaccional |
| Clientes | `api-clientes` | 5000 | Clientes de la distribuidora |
| Pedidos | `api-pedidos` | 5000 | Crea pedidos y le pide el descuento a inventario |
| Reportes | `api-reportes` | 5000 | Métricas del dashboard |
| Base de datos | `db` | 5432 | Postgres 16 con cinco bases, una por servicio |

Los microservicios son Flask con gunicorn. Solo el gateway sale al host; el resto se comunica por
nombre dentro de la red interna `elquetzal-net`. Las credenciales viajan por variables de entorno,
nunca en el código.

Las rutas de la API y los formatos JSON están en [`CONTRATO.md`](CONTRATO.md). El detalle de las
bases, usuarios y seeds está en [`database/README.md`](database/README.md).

## Requisitos

- Docker Engine y Docker Compose
- Node.js 18 o superior, solo si vas a trabajar el frontend en modo desarrollo

## Cómo levantarlo

**1. Clonar y preparar las variables de entorno.**

```bash
git clone https://github.com/diegoazurdia1998/Proyecto-Virtualizacion.git
cd Proyecto-Virtualizacion
cp .env.example .env
```

Abrí el `.env` y poné las contraseñas reales. Usen las mismas en todo el equipo para que los datos
coincidan. El `.env` no se sube al repo.

**2. Levantar el stack.**

```bash
docker compose up -d --build
docker compose ps
```

La primera vez, Postgres crea las cinco bases con sus usuarios y carga los seeds con los carnés del
equipo. Ese script solo corre cuando el volumen está vacío.

**3. Comprobar que responde.**

```bash
curl http://localhost:5000/health
curl http://localhost:5000/productos
```

Deberías ver los productos de prueba con el carné de quien los registró.

### Acceso a los servicios mientras no existe el gateway

El archivo `docker-compose.override.yml` publica el puerto de cada servicio al host para poder
probarlos de forma directa. Compose lo lee solo, no hay que indicarlo.

| Servicio | Puerto en el host |
|---|---|
| Inventario | 5000 |
| Catálogo | 5001 |
| Clientes | 5002 |
| Pedidos | 5003 |
| Reportes | 5004 |
| Postgres | 5432 |

Cuando el gateway entre, este archivo se elimina: la app se abrirá por un solo puerto y Postgres
deja de publicarse.

### Frontend en modo desarrollo

```bash
cd frontend
npm install
npm run dev
```

Queda en `http://localhost:5173`. Vite hace de gateway provisional: manda cada `/api/<servicio>/` al
puerto correspondiente de la tabla de arriba. En producción ese ruteo lo hace nginx y el proxy de
Vite no se usa.

## Probar el flujo de pedidos

El camino feliz y el rechazo por stock, desde la línea de comandos:

```bash
# Pedido válido: descuenta el stock y devuelve el total calculado por el servidor
curl -X POST http://localhost:5003/pedidos \
  -H "Content-Type: application/json" \
  -d '{"carne":"1182222","cliente_id":1,"items":[{"sku":"QTZ-001","cantidad":2}]}'

# Pedido rechazado: pide más de lo que hay y no toca el inventario
curl -X POST http://localhost:5003/pedidos \
  -H "Content-Type: application/json" \
  -d '{"carne":"1182222","cliente_id":1,"items":[{"sku":"QTZ-012","cantidad":500}]}'
```

El segundo responde `409` con el detalle de lo solicitado contra lo disponible. El stock queda
intacto: la validación vive en el servidor, no en el navegador.

### Prueba de persistencia

```bash
docker compose down
docker compose up -d
```

Los datos sobreviven porque viven en el volumen nombrado `elquetzal-pgdata`. Para empezar desde
cero y que los seeds vuelvan a cargarse, hay que borrar el volumen a propósito:

```bash
docker compose down
docker volume rm elquetzal-pgdata
docker compose up -d
```

## Estructura del repositorio

```
Proyecto-Virtualizacion/
├── backend/          catalogo/ inventario/ clientes/ pedidos/ reportes/ (cada uno con su Dockerfile)
├── database/         script de inicialización, esquemas y seeds
├── docs/             enunciado, diagrama, modelo de datos, anexo de costos y evidencias
├── frontend/         proyecto Vue
├── gateway/          nginx.conf y Dockerfile del gateway
├── docker-compose.yml
├── docker-compose.override.yml
├── .env.example
└── CONTRATO.md
```

## Equipo

| Integrante | Carné | Área |
|---|---|---|
| Rochelle Giulianne Esquivel Vargas | 1283220 | Infraestructura y gateway |
| Oscar Javier Ortíz Pocón | 1182222 | Datos y persistencia |
| Diego Andrés Azurdia Ortíz | 2528119 | Backend de dominio |
| Diego Oswaldo Orellana Morales | 1163722 | Frontend Vue |
| Susana Paola García García | 1224323 | Orquestación, costos y documentación |

## Datos del proyecto

| Dato | Valor |
|---|---|
| Hostname de la VM | `srv-elquetzal-virtualinsanity` |
| Namespace en Docker Hub | `virtual4insanity` |
| Etiqueta de las imágenes | `virtual4insanity/elquetzal-<servicio>:1.0` |

## Trabajo en el repositorio

Cada quien trabaja en su propia rama y abre un Pull Request. Nadie hace push directo a `main`.
Los commits van cortos y descriptivos, por ejemplo `feat(pedidos): valida stock antes de confirmar`.
Si un cambio toca el área de otro integrante, se avisa al grupo para que pueda explicarlo.

## Pendientes

- Gateway nginx: `nginx.conf`, Dockerfile, build de producción del frontend y descomentar el
  servicio en el `docker-compose.yml`.
- Publicar las imágenes en el Docker Hub del equipo.
- Anexo de costos y documento de arquitectura.