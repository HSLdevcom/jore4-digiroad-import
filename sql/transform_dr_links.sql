DROP TABLE IF EXISTS digiroad.dr_linkki;

CREATE TABLE digiroad.dr_linkki AS
SELECT
    src.gid AS gid,
    src.link_id AS link_id,
    src.link_mmlid AS link_mmlid,
    src.segm_id AS segm_id,
    src.kuntakoodi AS kuntakoodi,
    src.hallinn_lk AS hallinn_lk,
    src.toiminn_lk AS toiminn_lk,
    src.linkkityyp AS linkkityyp,
    src.tienumero AS tienumero,
    src.tieosanro AS tieosanro,
    src.silta_alik AS silta_alik,
    src.ajorata AS ajorata,
    src.aet AS aet,
    src.let AS let,
    src.ajosuunta AS ajosuunta,
    src.tienimi_su AS tienimi_su,
    src.tienimi_ru AS tienimi_ru,
    src.tienimi_sa AS tienimi_sa,
    src.ens_talo_o AS ens_talo_o,
    src.ens_talo_v AS ens_talo_v,
    src.viim_tal_o AS viim_tal_o,
    src.viim_tal_v AS viim_tal_v,
    src.muokkauspv AS muokkauspv,
    src.sij_tark AS sij_tark,
    src.kor_tark AS kor_tark,
    src.alku_paalu AS alku_paalu,
    src.lopp_paalu AS lopp_paalu,
    src.geom_flip AS geom_flip,
    src.link_tila AS link_tila,
    src.geom_lahde AS geom_lahde,
    src.mtk_tie_lk AS mtk_tie_lk,
    src.tien_kasvu AS tien_kasvu,
    (ST_Dump(src.geom)).geom AS geom_dump
FROM digiroad.dr_linkki_in src
WHERE src.kuntakoodi IN (
     -- Filter in nine HSL member municipalities.
     49, -- Espoo,
     91, -- Helsinki
    235, -- Kauniainen
    245, -- Kerava
    257, -- Kirkkonummi
    753, -- Sipoo
    755, -- Siuntio
    858, -- Tuusula
     92  -- Vantaa
);

UPDATE digiroad.dr_linkki SET geom_dump = ST_SetSRID(geom_dump, 3067);

SELECT AddGeometryColumn('digiroad', 'dr_linkki', 'geom', 3067, 'LINESTRING', 3);
UPDATE digiroad.dr_linkki SET geom = ST_Force3D(geom_dump);
ALTER TABLE digiroad.dr_linkki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE digiroad.dr_linkki DROP COLUMN geom_dump;

ALTER TABLE digiroad.dr_linkki ADD COLUMN geog geography(LINESTRINGZ, 4326);
UPDATE digiroad.dr_linkki SET geog = Geography(ST_Transform(geom, 4326));
ALTER TABLE digiroad.dr_linkki ALTER COLUMN geog SET NOT NULL;
