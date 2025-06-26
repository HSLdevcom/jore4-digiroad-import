DROP SCHEMA IF EXISTS :schema CASCADE;

CREATE SCHEMA :schema;

REFRESH MATERIALIZED VIEW :source_schema.dr_linkki_fixup;

CREATE TABLE :schema.dr_linkki AS
SELECT
    src.id,
    src.link_id,
    src.geom AS geom_orig
FROM :source_schema.dr_linkki_fixup src
WHERE
    src.linkkityyp IN (
        1, -- Moottoritien osa
        2, -- Moniajorataisen tien osa, joka ei ole moottoritie
        3, -- Yksiajorataisen tien osa
        4, -- Moottoriliikennetien osa
        5, -- Kiertoliittymän osa
        6, -- Ramppi
        7, -- Levähdysalue
    --  8, -- Pyörätie tai yhdistetty pyörätie ja jalkakäytävä
    --  9, -- Jalankulkualueen osa, esim. kävelykatu tai jalkakäytävä
    -- 10, -- Huolto- tai pelastustien osa
       11, -- Liitännäisliikennealueen osa
       12, -- Ajopolku, maastoajoneuvolla ajettavissa olevat tiet
    -- 13, -- Huoltoaukko moottoritiellä
    -- 14, -- Erikoiskuljetusyhteys ilman puomia
    -- 15, -- Erikoiskuljetusyhteys puomilla
       21, -- Lossi
       99  -- Ei tietoa (esiintyy vain rakenteilla olevilla tielinkeillä)
    );

-- Apply geometry conversion for dr_linkki table that is suitable for MVT format.
SELECT AddGeometryColumn(:'schema', 'dr_linkki', 'geom', 4326, 'LINESTRING', 2);
UPDATE :schema.dr_linkki SET geom = ST_Transform(ST_Force2D(geom_orig), 4326);
ALTER TABLE :schema.dr_linkki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_linkki DROP COLUMN geom_orig;

-- Copy dr_pysakki table from source schema.
CREATE TABLE :schema.dr_pysakki AS
SELECT
    src.id,
    src.link_id,
    src.kuntakoodi,
    src.geom AS geom_orig
FROM :source_schema.dr_pysakki_fixup src
INNER JOIN :schema.dr_linkki link USING (link_id);

-- Apply geometry conversion for dr_pysakki table that is suitable for MVT format.
SELECT AddGeometryColumn(:'schema', 'dr_pysakki', 'geom', 4326, 'POINT', 2);
UPDATE :schema.dr_pysakki SET geom = ST_Transform(ST_Force2D(geom_orig), 4326);
ALTER TABLE :schema.dr_pysakki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_pysakki DROP COLUMN geom_orig;

-- Add data integrity constraints to dr_linkki table.
ALTER TABLE :schema.dr_linkki ALTER COLUMN link_id SET NOT NULL;

ALTER TABLE :schema.dr_linkki ADD CONSTRAINT dr_linkki_pkey PRIMARY KEY (id);
ALTER TABLE :schema.dr_linkki ADD CONSTRAINT uk_dr_linkki_link_id UNIQUE (link_id);

-- Add data integrity constraints to dr_pysakki table.
ALTER TABLE :schema.dr_pysakki ALTER COLUMN id SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN kuntakoodi SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (id);
ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id);
