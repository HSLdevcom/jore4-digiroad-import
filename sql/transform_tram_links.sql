-- Transform tram infrastructure links into the Digiroad schema.
--
-- The tram links are loaded by `tram_infraLinks.sql` into the staging table
-- `infrastructure_network.infrastructure_link` as EPSG:4326 geography. Here they
-- are projected to EPSG:3067 (the coordinate system used by Digiroad) and given
-- integer IDs so that they can be consumed by the routing schema the same way as
-- Digiroad links.
--
-- These links are intentionally kept separate from the Digiroad `dr_linkki`
-- table so that the GeoPackage fixup layer (which applies to Digiroad bus links
-- only) does not affect tram links.

DROP TABLE IF EXISTS :schema.hsl_tram_linkki;

CREATE TABLE :schema.hsl_tram_linkki AS
SELECT
    -- Tram link IDs from MML are > 2_000_000_000.
    -- This keeps tram link IDs apart from Digiroad-originated IDs (< 1_000_000_000)
    -- and HSL fixup IDs (>= 1_000_000_000).
    src.external_link_id::bigint AS id,
    src.external_link_id::text AS link_id,
    CASE
        WHEN src.direction = 'bidirectional' THEN 2
        WHEN src.direction = 'backward' THEN 3
        WHEN src.direction = 'forward' THEN 4
    END AS ajosuunta,
    ST_Transform(src.shape::geometry, 3067) AS geom
FROM infrastructure_network.infrastructure_link src
WHERE src.external_link_source IN ('temp_hsl_tram', 'hsl_tram');

-- Add data integrity constraints.
ALTER TABLE :schema.hsl_tram_linkki
    ALTER COLUMN id SET NOT NULL,
    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN ajosuunta SET NOT NULL,
    ALTER COLUMN geom SET NOT NULL,

    ADD CONSTRAINT hsl_tram_linkki_pkey PRIMARY KEY (id),
    ADD CONSTRAINT uk_hsl_tram_linkki_link_id UNIQUE (link_id);

CREATE INDEX hsl_tram_linkki_geom_idx ON :schema.hsl_tram_linkki USING gist (geom);
