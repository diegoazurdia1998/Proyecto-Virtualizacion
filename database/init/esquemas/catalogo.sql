-- Catálogo: fuente de verdad de las categorías y del equipo de desarrollo.
-- No guarda stock ni precios: eso vive en inventario.

CREATE TABLE categorias (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(60) NOT NULL UNIQUE,
    descripcion VARCHAR(160),
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Los carnés del equipo salen de aquí hacia la UI (evidencia personalizada).
CREATE TABLE equipo (
    carne  VARCHAR(10) PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    rol    VARCHAR(60) NOT NULL
);
