#!/bin/bash
# Crea una base de datos y un usuario por microservicio, aplica su esquema y sus seeds.
# La imagen de Postgres lo ejecuta sola la primera vez que arranca, cuando el
# volumen está vacío. Las claves vienen del .env, nunca del código.
set -e

INIT_DIR="/docker-entrypoint-initdb.d"

crear_base() {
  local base="$1" usuario="$2" clave="$3" archivo="$4"

  echo ">> Creando base $base con usuario $usuario"

  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres <<EOSQL
CREATE USER $usuario WITH PASSWORD '$clave';
CREATE DATABASE $base OWNER $usuario ENCODING 'UTF8';
REVOKE CONNECT ON DATABASE $base FROM PUBLIC;
GRANT ALL PRIVILEGES ON DATABASE $base TO $usuario;
EOSQL

  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$base" \
       -c "ALTER SCHEMA public OWNER TO $usuario;"

  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$base" \
       -f "$INIT_DIR/esquemas/$archivo.sql"

  if [ -f "$INIT_DIR/seeds/$archivo.sql" ]; then
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$base" \
         -f "$INIT_DIR/seeds/$archivo.sql"
  fi

  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$base" <<EOSQL
GRANT ALL ON ALL TABLES IN SCHEMA public TO $usuario;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO $usuario;
EOSQL
}

crear_base "$CATALOGO_DB"   "$CATALOGO_DB_USER"   "$CATALOGO_DB_PASSWORD"   catalogo
crear_base "$INVENTARIO_DB" "$INVENTARIO_DB_USER" "$INVENTARIO_DB_PASSWORD" inventario
crear_base "$CLIENTES_DB"   "$CLIENTES_DB_USER"   "$CLIENTES_DB_PASSWORD"   clientes
crear_base "$PEDIDOS_DB"    "$PEDIDOS_DB_USER"    "$PEDIDOS_DB_PASSWORD"    pedidos
crear_base "$REPORTES_DB"   "$REPORTES_DB_USER"   "$REPORTES_DB_PASSWORD"   reportes

echo ">> Las 5 bases de El Quetzal quedaron listas."
