-- Clientes: las tiendas y mayoristas a los que El Quetzal despacha.

CREATE TABLE clientes (
    id         SERIAL PRIMARY KEY,
    nit        VARCHAR(15)  NOT NULL UNIQUE,
    nombre     VARCHAR(100) NOT NULL,
    direccion  VARCHAR(160),
    telefono   VARCHAR(20),
    email      VARCHAR(100),
    activo     BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_por VARCHAR(10),
    creado_en  TIMESTAMP    NOT NULL DEFAULT NOW()
);
