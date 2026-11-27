-- Infraestructura de recepción probada en aislamiento; no es una migración publicada.
CREATE TABLE sc_sync_contexto (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    epoca TEXT NOT NULL CHECK (length(epoca) = 32 AND epoca NOT GLOB '*[^0-9a-f]*')
);
CREATE TABLE sc_sync_revisiones (
    entidad TEXT NOT NULL CHECK (length(entidad) BETWEEN 1 AND 32),
    registro TEXT NOT NULL CHECK (length(registro) = 32 AND registro NOT GLOB '*[^0-9a-f]*'),
    revision INTEGER NOT NULL CHECK (typeof(revision) = 'integer' AND revision BETWEEN 1 AND 9007199254740991),
    PRIMARY KEY (entidad, registro)
);
CREATE TABLE sc_sync_recibos (
    nodo TEXT NOT NULL CHECK (length(nodo) = 32 AND nodo NOT GLOB '*[^0-9a-f]*'),
    operacion TEXT NOT NULL CHECK (length(operacion) = 32 AND operacion NOT GLOB '*[^0-9a-f]*'),
    epoca TEXT NOT NULL CHECK (length(epoca) = 32 AND epoca NOT GLOB '*[^0-9a-f]*'),
    huella BLOB NOT NULL CHECK (typeof(huella) = 'blob' AND length(huella) = 32),
    resultado TEXT NOT NULL CHECK (resultado IN ('aplicado', 'conflicto')),
    revision INTEGER NOT NULL CHECK (typeof(revision) = 'integer' AND revision BETWEEN 0 AND 9007199254740991),
    PRIMARY KEY (nodo, operacion)
);
CREATE TABLE sc_sync_conflictos (
    nodo TEXT NOT NULL,
    operacion TEXT NOT NULL,
    actual TEXT CHECK (actual IS NULL OR (json_valid(actual) AND json_type(actual) = 'object'
        AND length(CAST(actual AS BLOB)) <= 65536)),
    propuesta TEXT NOT NULL CHECK (json_valid(propuesta) AND json_type(propuesta) = 'object'
        AND length(CAST(propuesta AS BLOB)) <= 69632),
    PRIMARY KEY (nodo, operacion),
    FOREIGN KEY (nodo, operacion) REFERENCES sc_sync_recibos(nodo, operacion) ON DELETE RESTRICT
);
