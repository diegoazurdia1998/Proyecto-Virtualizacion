-- Reportes no guarda datos de negocio: los pide por HTTP a los otros servicios.
-- Su base guarda el último cálculo del dashboard y la bitácora de consultas.

CREATE TABLE metricas_cache (
    clave       VARCHAR(40) PRIMARY KEY,
    valor       JSONB       NOT NULL,
    generado_en TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE TABLE bitacora_consultas (
    id            SERIAL PRIMARY KEY,
    reporte       VARCHAR(40) NOT NULL,
    carne         VARCHAR(10),
    consultado_en TIMESTAMP   NOT NULL DEFAULT NOW()
);
