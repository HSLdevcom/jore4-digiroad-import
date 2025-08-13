-- NOTE! All SQL statements in this file must be idempotent, meaning that
-- the statements must be able to be executed multiple times without creating
-- duplicate rows in the database.

-- Some commented SELECT statements have been left in the code between
-- subqueries. They serve as a hint that it is worth checking the results of the
-- intermediate processing steps if changes are made to them.


-- Set the 'schema' variable to its default value if it is not defined.
\if :{?schema}
\else
  \set schema 'digiroad'
\endif


-- Upsert geometries used to exclude Digiroad links to be replaced by HSL's
-- custom ones.
WITH
drl_fix AS (
    SELECT
        fid,
        ST_GeomFromEWKT(geom_ewkt) AS geom
    FROM (
        VALUES
            -- Exclude two links of which one is a duplicate and another is
            -- fixed for the `ajosuunta` property.
            (1, 'SRID=3067;LINESTRING(385272.0 6672146.0 0 0, 385291.0 6672159.0 0 0)'), -- Kamppi

            -- Make more accurate geometry for an existing Digiroad link and add
            -- two tram trails next to it.
            (2, 'SRID=3067;LINESTRING(386431.8 6673623.4 0 0, 386433.9 6673625.9 0 0)'), -- Viides linja (Karhupuisto)

            -- Make more accurate geometry.
            (3, 'SRID=3067;LINESTRING(387030.1 6675075.1 0 0, 387025.4 6675097.3 0 0)')  -- H3051-H3025 (Sturenkatu)
    ) AS t(fid, geom_ewkt)
),
inserts AS (
    INSERT INTO :schema.fix_layer_link_exclusion_geometry (
        fid, geom
    )
    SELECT fid, geom
    FROM drl_fix
    WHERE fid NOT IN (
        SELECT fid from :schema.fix_layer_link_exclusion_geometry
    )
    ORDER BY fid
    RETURNING fid, geom
),
updates AS (
    UPDATE :schema.fix_layer_link_exclusion_geometry AS exc
    SET geom = fix.geom
    FROM drl_fix fix
    WHERE
        exc.fid = fix.fid
        AND exc.geom <> fix.geom
    RETURNING exc.fid, fix.geom
)
SELECT fid, ST_AsEWKT(geom) AS geom_ewkt, true AS is_new FROM inserts
UNION
SELECT fid, ST_AsEWKT(geom) AS geom_ewkt, false AS is_new FROM updates
ORDER BY fid;


CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA :schema;

-- Commented out because these columns are currently added to fixup.gpkg
-- ALTER TABLE :schema.fix_layer_link ADD COLUMN original_link_id text;
-- ALTER TABLE :schema.fix_layer_link ADD COLUMN description text;
-- ALTER TABLE :schema.fix_layer_stop_point ADD COLUMN yllapitaja integer;
-- ALTER TABLE :schema.fix_layer_stop_point ADD COLUMN yllap_tunn text;

ALTER TABLE :schema.fix_layer_link ADD COLUMN start_location_m_on_original_link double precision;


-- Add HSL supplementary links that are missing from Digiroad. The links added
-- here connect two Digiroad links to each other or form a loop along one
-- Digiroad link.
--
-- After this, in the next operation, we topologically connect all new links to
-- the network by splitting existing Digiroad links if necessary.
WITH
-- Define the required input data which consists of the following:
--  * start link ID
--  * end link ID
--  * the direction of traffic flow using Digiroad code values
--  * position on the start link
--  * position on the end link
--  * intermediary point along the new link
--  * whether the new link is usable by trams
drl_fix AS (
    SELECT
        row_number() OVER () AS rn,
        from_link_id,
        to_link_id,
        joint_link_ajosuunta,
        from_link_terminus_opt,
        closest_point_ewkt_on_to_link_opt,
        interim_points_arr,
        is_tram
    FROM (
        VALUES
            -- E1023-E1051, E1030-E1050, E1051-E1031, E1051-E1065
            (
                '2bb7397d-9202-4f21-9551-312b9a78706e:2',
                '80a80136-2f0f-45ef-bcf7-013258c4404d:2',
                4,
                'SRID=3067;POINT(378880.7 6678133.0)',
                'SRID=3067;POINT(378932.2 6678113.7)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(378881.1 6678115.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378882.2 6678113.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378883.9 6678112.0)')
                ],
                false
            ),
            -- E1062-E1061, E1065-E1062
            (
                'e29cbf11-be7f-44ce-9ae2-844fc6089450:2',
                'e29cbf11-be7f-44ce-9ae2-844fc6089450:2',
                4,
                'SRID=3067;POINT(378760.9 6678007.1)',
                'SRID=3067;POINT(378806.6 6678008.1)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(378754.6 6677998.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378762.7 6677969.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378767.0 6677957.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378771.1 6677953.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378776.3 6677952.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378803.5 6677951.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378808.7 6677952.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378811.2 6677954.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378813.0 6677961.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378811.7 6678003.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378810.3 6678005.2)')
                ],
                false
            ),
            -- E1142-E1144, E1142-E1147, E1145-E1142, E1146-E1142
            (
                '8293a5ea-e5c8-4ca6-af95-249d74884de8:3',
                '8293a5ea-e5c8-4ca6-af95-249d74884de8:3',
                4,
                'end',
                'end',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(379976.3 6678697.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380011.8 6678736.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380022.0 6678732.4)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380025.7 6678734.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380026.9 6678736.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380027.1 6678741.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380022.3 6678747.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380025.9 6678766.4)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380027.6 6678769.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380050.2 6678781.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380063.3 6678783.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380071.9 6678784.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380074.6 6678784.4)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380077.1 6678783.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380079.3 6678780.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380079.9 6678776.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380079.3 6678772.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380076.1 6678768.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380071.3 6678767.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380059.8 6678766.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380050.7 6678763.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380041.4 6678759.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380031.2 6678753.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380022.2 6678747.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(380011.8 6678736.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(379976.3 6678697.3)')
                ],
                false
            ),
            -- E1147-E1154, E1970-E1146
            ('a9302c4c-2811-4bb5-8682-996859b824a8:2', 'e79d9285-97e3-420f-b5b4-a035ddb8a237:2', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[], false),
            -- E2002-E2104
            (
                '87bf3b53-a499-4f2e-a177-637050f84c1b:1',
                'ba5f5c42-c85f-42e3-befe-81b950e5010d:1',
                2,
                'end',
                'SRID=3067;POINT(377760.6 6673329.3)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(377755.4 6673413.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377749.4 6673405.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377744.5 6673395.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377734.4 6673365.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377735.1 6673361.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377739.2 6673354.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377756.1 6673338.4)')
                ],
                false
            ),
            -- E2004-E2005, E2019-E2004, E2028-E2190
            (
                '51a4af08-5b1f-4efd-a91c-86eb6a488531:1',
                '51a4af08-5b1f-4efd-a91c-86eb6a488531:1',
                4,
                'start',
                NULL::text,
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(378441.3 6673309.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378402.9 6673299.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378407.1 6673282.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378408.9 6673279.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378413.9 6673278.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378455.3 6673287.6)')
                ],
                false
            ),
            -- Kulttuuriaukio: E2002-E2104, E2002-2108, E2105-E2002, E2108-E2002
            (
                'c1c1013c-bdf6-4fd2-8d48-dfec5b99e639:1',
                'c1c1013c-bdf6-4fd2-8d48-dfec5b99e639:1',
                4,
                'SRID=3067;POINT(378116.7 6673212.9)',
                'SRID=3067;POINT(378113.3 6673226.1)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(378166.3 6673225.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378168.1 6673229.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378167.8 6673236.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(378162.8 6673237.8)')
                ],
                false
            ),
            -- E2014-E2158, E2158-E2015
            (
                'fe5b9225-7004-4dfb-8929-fe0b6fed5558:1',
                'fe5b9225-7004-4dfb-8929-fe0b6fed5558:1',
                4,
                'start',
                'start',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(377844.5 6672516.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377828.9 6672508.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377829.9 6672503.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377832.4 6672501.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377836.9 6672499.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377839.7 6672499.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377842.6 6672502.4)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(377843.5 6672504.6)')
                ],
                false
            ),
            -- E2180-E2014
            ('44d535a1-901e-44a5-9d30-b1cf1d242a8e:1', 'c60da352-e00f-4b86-8e1f-177a2af5e909:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[], false),
            -- E4043-E4037, E4043-E4038, E4043-E4045
            -- * !!! Requires a linkkityyp of value 8
            ('85a74090-a925-493e-98af-600a0514c988:1', '9d158c71-e75b-46a8-a7c1-01fdd1eb35b3:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[], false),
            -- E4417-E3157, E4418-E3157
            (
                'a38b6c59-6c3b-49b3-92b9-5bd00199455a:1',
                '30253b50-4f61-4ff9-ae58-5bf71b891e8d:1',
                3,
                NULL::text,
                'SRID=3067;POINT(374259.2 6671674.2)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(374319.1 6671679.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(374285.9 6671674.6)')
                ],
                false
            ),
            -- Viides linja
            (
                '7c8ba8ec-fe5d-4ec0-8b5b-c55ed52242fb:1',
                '6cfdc892-3cc0-45d5-a8d1-dbcc2f401528:1',
                3,
                'end',
                NULL::text,
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(386470.8 6673589.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386461.2 6673596.4)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386421.9 6673628.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386414.0 6673635.5)')
                ],
                false
            ),
            -- H0255-H0257, H2091-H0255
            (
                'fd260f4d-37be-44c8-b97a-ac3c5f78def9:1',
                '7c8ba8ec-fe5d-4ec0-8b5b-c55ed52242fb:1',
                3,
                'start',
                'SRID=3067;POINT(386475.5 6673581.8)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(386396.0 6673675.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386400.4 6673664.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386408.0 6673654.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386467.8 6673604.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386472.9 6673596.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386474.6 6673592.2)')
                ],
                true
            ),
            -- H0256-H2418
            (
                '6cfdc892-3cc0-45d5-a8d1-dbcc2f401528:1',
                '7c8ba8ec-fe5d-4ec0-8b5b-c55ed52242fb:1',
                4,
                'SRID=3067;POINT(386401.5 6673654.3)',
                'SRID=3067;POINT(386465.3 6673569.0)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(386465.7 6673600.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386470.2 6673593.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386471.8 6673584.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386471.1 6673580.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(386469.5 6673576.4)')
                ],
                true
            ),
            -- H1014-H1233 #1
            (
                'acb37d77-5079-493a-a1f4-424261bea78d:1',
                '95fe1737-9919-4fbd-8d3e-1de0fc7950e6:1',
                4,
                'SRID=3067;POINT(384842.8 6671584.7)',
                'SRID=3067;POINT(384882.4 6671596.6)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(384869.2 6671591.9)')
                ],
                false
            ),
            -- H1014-H1233 #2
            (
                '95fe1737-9919-4fbd-8d3e-1de0fc7950e6:1',
                'a23476f4-1599-4e32-8777-dc3a49ef87eb:1',
                4,
                'SRID=3067;POINT(384882.4 6671596.6)',
                'start',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(384887.6 6671599.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(384925.6 6671624.4)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(384928.9 6671628.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(384928.9 6671628.1)')
                ],
                false
            ),
            -- H1405-H1448, H1419-H1448, H1448-H1404, H1448-H1418
            (
                'd09d038e-02ad-464a-960b-ba5d2c928caa:1',
                'd09d038e-02ad-464a-960b-ba5d2c928caa:1',
                4,
                'SRID=3067;POINT(382147.5 6675785.5)',
                'SRID=3067;POINT(382118.5 6675758.7)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(382137.4 6675794.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382118.7 6675796.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382114.6 6675791.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382113.0 6675764.9)')
                ],
                false
            ),
            -- H1723-H1668, H1724-H1723
            (
                '45432a5f-7306-4341-b191-35783d047498:1',
                'c44fcdc9-a9a3-4e42-96ac-9f87e507afd0:1',
                4,
                'SRID=3067;POINT(382962.3 6677526.8)',
                'SRID=3067;POINT(383000.8 6677479.9)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(382948.4 6677507.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382947.4 6677483.7)')
                ],
                false
            ),
            -- H2041-H2059, H2047-H2059, H2050-H2059 #1
            ('7c985dfd-e37f-47ed-b564-569994464215:1', 'a935dcb1-9fda-4d2c-a2af-6871c2c1ec4b:1', 4, 'end', 'end', ARRAY[]::geometry(Point)[], false),
            -- H2041-H2059, H2047-H2059, H2050-H2059 #2
            (
                'a935dcb1-9fda-4d2c-a2af-6871c2c1ec4b:1',
                '97ad845a-6574-4233-96a8-9a5870ed6dc3:1',
                4,
                'end',
                'end',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(385907.8 6672181.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(385920.0 6672169.6)')
                ],
                false
            ),
            -- H2149-H2340
            ('613734c1-5b21-4eee-8448-bc1ec3d64f99:1', 'c0b90c9d-9f1e-46ce-a5b8-a1e87b8ee172:1', 2, 'end', NULL::text, ARRAY[]::geometry(Point)[], false),
            -- H2513-H2509
            ('09c05d9c-4e9c-4555-be25-3e4e3acfb45a:1', '162a1100-a761-42b6-9464-fd3969b2dacc:2', 4, 'start', NULL::text, ARRAY[]::geometry(Point)[], false),
            -- H3051-H3025
            (
                'cc2ecce2-6eec-4414-921a-3a902b7f8926:1',
                'f4353d3e-1026-4ed5-928a-3890b8eede71:1',
                4,
                'SRID=3067;POINT(386998.1 6675079.4)',
                'SRID=3067;POINT(387028.0 6675124.7)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(387017.5 6675098.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(387025.4 6675111.9)')
                ],
                false
            ),
            -- H4011-H4308, H4491-H4308
            (
                'd7c8b621-2a55-42f2-a7ae-6ec250aba44d:2',
                '112ddb0d-c5ec-416a-ae00-988584f81801:2',
                4,
                'SRID=3067;POINT(393337.5 6676320.2)',
                'start',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(393344.1 6676320.5)')
                ],
                false
            ),
            -- H4095-H4313, H4095-H4530, H4098-H4313
            ('2ec4db39-72b1-4d7f-814c-51478dada733:1', 'f74eaeba-a1ff-4571-bcfd-c7d9ff609d5d:2', 4, 'start', 'SRID=3067;POINT(391184.3 6672469.0)', ARRAY[]::geometry(Point)[], false),
            -- H4098-H4096, H4313-H4096, H4317-H4096
            ('bfcc78f4-57de-46db-ac15-06a58f7612c0:1', '1b15c5b9-eb21-4cb1-bb40-a8d974f71879:2', 3, 'start', 'SRID=3067;POINT(391184.4 6672459.4)', ARRAY[]::geometry(Point)[], false),
            -- H4716-H4161
            ('d7a34688-52d5-40b6-aeaa-915602fb4ba7:2', '9cbe8c14-4ad8-4435-b918-31b4d339e55e:2', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[], false),
            -- Ka1703-Ka1730, Ka1706-Ka1730, Ka1730-Ka1704, Ka1730-Ka1705, Ka1732-Ka1704, Ka1781-Ka1705 #1
            -- * !!! Requires a linkkityyp of value 8
            ('ba1a3173-532a-48c7-ad41-4e9e32f1be71:1', 'b1ea93b0-c50b-459f-9c4f-90eb5e0238a2:1', 2, 'start', NULL::text, ARRAY[]::geometry(Point)[], false),
            -- Ka1703-Ka1730, Ka1706-Ka1730, Ka1730-Ka1704, Ka1730-Ka1705, Ka1732-Ka1704, Ka1781-Ka1705 #2
            -- * !!! Requires a linkkityyp of value 8
            (
                'ba1a3173-532a-48c7-ad41-4e9e32f1be71:1',
                '44dc1e56-79fb-452b-b35c-7ccb2b17b8aa:1',
                2,
                'start',
                'SRID=3067;POINT(374484.6 6677247.9)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(374489.6 6677207.4)')
                ],
                false
            ),
            -- Ka1745-Ka1747, Ka1770-Ka1772
            (
                'e67615ab-eade-4e07-98b0-f18a83577d2b:2',
                '0362b78f-0b9c-4b71-94a0-1e04c707f3e6:2',
                2,
                'SRID=3067;POINT(374604.2 6678068.9)',
                'start',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(374597.1 6678071.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(374592.6 6678073.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(374563.0 6678084.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(374557.2 6678089.6)')
                ],
                false
            ),
            -- Mä8000-Mä8052
            ('b88ca87e-59c0-4a21-9a56-6e5db65e2519:1', 'd7120fe2-8a7e-4cdc-8b26-ed8c20276bc0:2', 2, 'start', NULL::text, ARRAY[]::geometry(Point)[], false),
            -- Tu6354-Tu6393, Tu6393-Tu6353
            (
                'a6c4aa9c-420a-4532-b5fd-8038b7fd938e:2',
                'a6c4aa9c-420a-4532-b5fd-8038b7fd938e:2',
                4,
                'SRID=3067;POINT(390934.9 6707931.8)',
                'SRID=3067;POINT(390847.5 6707941.3)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(390936.1 6707947.2)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(390907.4 6707950.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(390882.5 6707955.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(390861.0 6707961.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(390849.8 6707961.1)')
                ],
                false
            ),
            -- V1503-V1520, V1503-V1521, V1560-V1506, V1560-V1521, V1561-V1521, V1567-V1521
            ('d82301f3-8aca-42d7-ae61-49c721c1be30:2', 'f0fbd3a0-3697-49ee-a6d9-50f4b34ac499:2', 4, 'start', NULL::text, ARRAY[]::geometry(Point)[], false),
            -- V1565-V1505, V1565-V1560, V1565-V1567
            ('d82301f3-8aca-42d7-ae61-49c721c1be30:2', 'f0fbd3a0-3697-49ee-a6d9-50f4b34ac499:2', 3, 'end', NULL::text, ARRAY[]::geometry(Point)[], false),
            -- V1704-V1746, V1704-V1748, V1715-V1707, V1715-V1767, V1715-V1799, V1744-1799
            ('7ddd8c8a-50d5-463a-a679-178047c1787c:2', '141d4255-937a-4004-b8d6-de826ae6d63e:2', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[], false),
            -- V1722-V1711, V1722-V1743, V1745-V1798, V1747-V1707, V1747-V1798, V1758-V1711, V1758-V1743, V1767-V1711
            ('bd44ed9d-5333-4ca8-992d-665fc122f26b:1', 'f7f991b5-c5f5-40bf-b13b-2ebe2883d952:2', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[], false),
            -- V3301-V3314, V3303-V3301, V3306-V3301, V3314-V3316
            (
                '3d3612a5-76ca-4137-964e-a35f79782720:2',
                '3d3612a5-76ca-4137-964e-a35f79782720:2',
                4,
                'SRID=3067;POINT(382586.0 6691919.9)',
                'SRID=3067;POINT(382582.4 6691974.3)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(382605.2 6691922.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382608.8 6691923.9)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382605.2 6691965.1)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(382587.6 6691974.0)')
                ],
                false
            ),
            -- V9702-V9720 #1
            (
                'b292d21d-f1b9-487f-b789-6dc031b23938:3',
                'a8952e3b-91dd-4c2c-8a57-cce81076e9b9:1',
                2,
                'start',
                'SRID=3067;POINT(395683.1 6687934.0)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(395690.8 6687927.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395687.5 6687928.8)')
                ],
                false
            ),
            -- V9702-V9720 #2
            (
                '04e4bdd8-002a-43d2-b2ad-af7ba984aab9:2',
                'dd9bc311-857e-44eb-b729-4c415b6367fe:2',
                2,
                'end',
                'SRID=3067;POINT(395790.9 6688103.6)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(395782.3 6687982.8)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395794.7 6687998.7)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395801.3 6688008.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395810.7 6688026.0)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395821.8 6688050.3)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395822.5 6688054.5)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395821.7 6688056.6)'),
                    ST_GeomFromEWKT('SRID=3067;POINT(395794.4 6688097.7)')
                ],
                false
            )
    ) AS t(from_link_id, to_link_id, joint_link_ajosuunta, from_link_terminus_opt, closest_point_ewkt_on_to_link_opt, interim_points_arr, is_tram)
),
-- Refine the input data further by adding geometric endpoints of the connection
-- links.
drl_fix_2 AS (
    SELECT
        rn,
        from_link_id,
        to_link_id,
        ST_Force3D(start_point_on_from_drl.geom) AS start_point,
        ST_Force3D(
            ST_LineInterpolatePoint(
                to_drl.geom,
                split_fraction.n
            )
        ) AS end_point,
        joint_link_ajosuunta,
        split_fraction.n AS split_fraction,
        interim_points_arr,
        is_tram
    FROM drl_fix
    INNER JOIN :schema.dr_linkki from_drl ON from_drl.link_id = drl_fix.from_link_id
    INNER JOIN :schema.dr_linkki to_drl ON to_drl.link_id = drl_fix.to_link_id
    CROSS JOIN LATERAL (
        SELECT
            CASE
                WHEN from_link_terminus_opt = 'start' THEN ST_StartPoint(from_drl.geom)
                WHEN from_link_terminus_opt = 'end' THEN ST_EndPoint(from_drl.geom)
                WHEN from_link_terminus_opt IS NOT NULL THEN
                    ST_LineInterpolatePoint(
                        from_drl.geom,
                        ST_LineLocatePoint(
                            from_drl.geom,
                            ST_ClosestPoint(
                                from_drl.geom,
                                ST_GeomFromEWKT(from_link_terminus_opt)
                            )
                        )
                    )
                ELSE
                    ST_LineInterpolatePoint(
                        from_drl.geom,
                        ST_LineLocatePoint(
                            from_drl.geom,
                            ST_ClosestPoint(from_drl.geom, to_drl.geom)
                        )
                    )
            END AS geom
    ) start_point_on_from_drl
    CROSS JOIN LATERAL (
        SELECT
            CASE
                WHEN closest_point_ewkt_on_to_link_opt = 'start' THEN ST_StartPoint(to_drl.geom)
                WHEN closest_point_ewkt_on_to_link_opt = 'end' THEN ST_EndPoint(to_drl.geom)
                WHEN closest_point_ewkt_on_to_link_opt IS NOT NULL
                    THEN ST_GeomFromEWKT(closest_point_ewkt_on_to_link_opt)
                ELSE ST_ClosestPoint(to_drl.geom, start_point_on_from_drl.geom)
            END AS geom
    ) closest_point_on_to_drl
    CROSS JOIN LATERAL (
        SELECT ST_LineLocatePoint(to_drl.geom, closest_point_on_to_drl.geom) AS n
    ) split_fraction
)
-- SELECT rn, from_link_id, to_link_id, ST_AsEWKT(start_point) AS start_point, ST_AsEWKT(end_point) AS end_point, joint_link_ajosuunta, split_fraction, interim_points_arr FROM drl_fix_2 ORDER BY rn;
, exclusion_multipolygon AS (
    -- Collect all fix layer links into a MultiLineString object and transform it to a MultiPolygon
    -- object by expanding the collected lines by 0.5 meters in all directions.
    SELECT ST_Buffer(ST_Collect(geom), 0.5) AS geom
    FROM :schema.fix_layer_link
),
-- Create actual LineString geometry for the joint links and attach required
-- properties.
joint_links AS (
    SELECT
        rn,
        ST_AddMeasure( -- add 4th dimension (M value, linear referencing)
            interp_line.geom,
            0,
            ST_Length(interp_line.geom)
        ) AS geom,
        joint_link_ajosuunta AS ajosuunta,
        from_drl.kuntakoodi,
        99 AS linkkityyp,
        0 AS silta_alik,
        3 AS link_tila,
        CASE
            WHEN fix.from_link_id = fix.to_link_id THEN
                'HSL''s supplementary loop link for bus traffic.'
            ELSE
                'HSL''s supplementary joint link connecting Digiroad links.'
        END AS description,
        is_tram
    FROM drl_fix_2 fix
    INNER JOIN :schema.dr_linkki from_drl ON from_drl.link_id = fix.from_link_id
    CROSS JOIN LATERAL (
        SELECT
            ST_Z(start_point) AS z_start,
            ST_Z(end_point) AS z_end
    ) z
    CROSS JOIN LATERAL (
        -- Create line geometry and interpolate values for Z axis (height).
        SELECT ST_SetSRID(ST_MakeLine(points_z.geom), 3067) AS geom
        FROM (
            SELECT
                i,
                ST_MakePoint(
                    ST_X(pt),
                    ST_Y(pt),
                    z_start + (z_end - z_start) * ST_LineLocatePoint(polyline_2d.geom, pt)
                ) AS geom
            FROM (
                SELECT
                    ST_SetSRID(
                        ST_MakeLine(
                            ST_Force2D(start_point) || interim_points_arr || ST_Force2D(end_point)
                        ),
                        3067
                    ) AS geom
            ) polyline_2d
            CROSS JOIN LATERAL (
                SELECT
                    i,
                    ST_PointN(polyline_2d.geom, i) AS pt
                FROM generate_series(1, ST_NumPoints(polyline_2d.geom)) AS i
            ) vertices
            ORDER BY i
        ) points_z
    ) interp_line
    -- Filter out joint links that are already added to the fix_layer_link table.
    LEFT JOIN exclusion_multipolygon exc_pol ON ST_Covers(exc_pol.geom, interp_line.geom)
    WHERE exc_pol.geom IS NULL -- anti-join
)
-- SELECT rn, ST_AsEWKT(geom) AS geom, ajosuunta FROM joint_links ORDER BY rn;
INSERT INTO :schema.fix_layer_link (
    fid,
    link_id,
    internal_id,
    ajosuunta,
    kuntakoodi,
    linkkityyp,
    silta_alik,
    link_tila,
    is_generic_bus, is_tall_electric_bus,
    is_tram,
    is_train, is_metro, is_ferry,
    description,
    geom
)
SELECT
    generated_fid.n AS fid,
    'hsl:' || gen_random_uuid() || ':1' AS link_id,
    1000000000 + generated_fid.n AS internal_id,
    joint_links.ajosuunta,
    joint_links.kuntakoodi,
    joint_links.linkkityyp,
    joint_links.silta_alik,
    joint_links.link_tila,
    true, true,
    is_tram,
    false, false, false,
    description,
    joint_links.geom
FROM joint_links
CROSS JOIN LATERAL (
    SELECT num_existing_links.n + rn AS n
    FROM (
        SELECT coalesce(max(fid), 0) AS n
        FROM :schema.fix_layer_link
    ) num_existing_links
) generated_fid
ORDER BY fid;


REFRESH MATERIALIZED VIEW :schema.dr_linkki_fixup;

-- This operation is intended for cases where a Digiroad/HSL supplementary road
-- link forms a T-junction with an MML road link, but the supplementary link is
-- not topologically connected to the MML link. The solution is to split the MML
-- link into parts so that all Digiroad/HSL supplementary links topologically
-- connect at junction points.
WITH
-- Find the connection/junction points as fractions of the length of the links
-- to be splitted. The fractions are floats between 0 and 1.
mml_link_split_fractions AS (
    SELECT
        link_mml.link_id AS link_id,
        array_agg(
            DISTINCT junctions.fraction
            ORDER BY junctions.fraction
        ) junction_point_fractions
    FROM :schema.dr_linkki_fixup link_mml
    INNER JOIN :schema.dr_linkki_fixup link_supp
        ON ST_DWithin(link_mml.geom, link_supp.geom, 0.5)
    CROSS JOIN LATERAL (
        SELECT 0 AS fraction

        UNION ALL
        SELECT ST_LineLocatePoint(link_mml.geom, start_point.geom)
        FROM (
            SELECT ST_StartPoint(link_supp.geom) AS geom
        ) start_point
        WHERE start_point.geom <-> link_mml.geom <= 0.5

        UNION ALL
        SELECT ST_LineLocatePoint(link_mml.geom, end_point.geom)
        FROM (
            SELECT ST_EndPoint(link_supp.geom) AS geom
        ) end_point
        WHERE end_point.geom <-> link_mml.geom <= 0.5

        UNION ALL
        SELECT 1
    ) junctions
    WHERE
        link_mml.hsl_infra_source = 'digiroad_r_mml'

        AND link_mml.linkkityyp IN (
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
        )

        AND link_supp.hsl_infra_source <> 'digiroad_r_mml'

        AND
        (
            -- Identify the MML links to be splitted so that the supplementary
            -- link is close to the MML link, but either endpoint of the MML
            -- link is not close.
            (
                ST_StartPoint(link_supp.geom) <-> link_mml.geom <= 0.5
                AND
                ST_StartPoint(link_supp.geom) <-> ST_StartPoint(link_mml.geom) > 0.5
                AND
                ST_StartPoint(link_supp.geom) <-> ST_EndPoint(link_mml.geom) > 0.5
            ) OR (
                ST_EndPoint(link_supp.geom) <-> link_mml.geom <= 0.5
                AND
                ST_EndPoint(link_supp.geom) <-> ST_StartPoint(link_mml.geom) > 0.5
                AND
                ST_EndPoint(link_supp.geom) <-> ST_EndPoint(link_mml.geom) > 0.5
            )
        )

        AND link_supp.linkkityyp IN (
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
        )
    GROUP BY link_mml.link_id
),
-- For each sublink, define it as a fractional range relative to the original
-- link. The range can be like, for example, [0.25, 0.75]. For each sublink,
-- there is one less range compared to the number of junction points calculated
-- in the previous subquery.
sublink_fractional_ranges AS (
    SELECT
        link_id,
        row_number() OVER (
            PARTITION BY link_id
            ORDER BY start_fraction
        ) AS seq,
        count(*) OVER (
            PARTITION BY link_id
        ) AS total,
        start_fraction,
        end_fraction
    FROM (
        SELECT
            link_id,
            junction_point_fraction AS start_fraction,
            lead(junction_point_fraction) OVER (
                PARTITION BY link_id
                ORDER BY junction_point_fraction
            ) AS end_fraction
        FROM (
            SELECT
                link_id,
                unnest(junction_point_fractions) AS junction_point_fraction
            FROM mml_link_split_fractions
        ) unnested
    ) ranges
    WHERE end_fraction IS NOT NULL
    ORDER BY link_id, seq
),
-- Create sublink geometries with required properties attached. We also need to
-- redefine the M-values ​​(4th dimension) for the starting points of the new
-- links resulting from each splitting (partitioning), so that we can later
-- associate the stop points associated with the original link with the correct
-- sublink.
splitted_sublinks AS (
    SELECT
        l.kuntakoodi,
        l.ajosuunta,
        l.linkkityyp,
        l.silta_alik,
        l.link_tila,
        l.tienimi_su,
        l.tienimi_ru,
        r.link_id AS original_mml_link_id,
        r.seq,
        'MML-originated Digiroad link divided into parts so that Digiroad/HSL supplementary links can be topologically connected to the network. Part ' || seq || '/' || total || '.' AS description,
        CASE
            WHEN r.seq = 1 THEN 0
            ELSE sum(len._2d) OVER (
                PARTITION BY r.link_id
                ORDER BY r.seq
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
        END AS start_location_m_on_original_link,
        ST_AddMeasure(substr.geom_3d, 0, len._2d) AS geom
    FROM sublink_fractional_ranges r
    INNER JOIN :schema.dr_linkki_fixup l USING (link_id)
    CROSS JOIN LATERAL (
        SELECT ST_LineSubstring(ST_Force3D(l.geom), r.start_fraction, r.end_fraction) AS geom_3d
    ) substr
    CROSS JOIN LATERAL (
        SELECT ST_Length(substr.geom_3d) AS _2d
    ) len
)
-- SELECT original_mml_link_id, seq, start_location_m_on_original_link, ST_AsEWKT(geom) AS geom FROM splitted_sublinks;
, splitted_sublinks_with_id AS (
    SELECT
        num_existing_links.n + numbered.order AS generated_fid,
        original_mml_link_id,
        kuntakoodi,
        ajosuunta,
        linkkityyp,
        silta_alik,
        link_tila,
        tienimi_su,
        tienimi_ru,
        seq,
        description,
        start_location_m_on_original_link,
        geom
    FROM (
        SELECT
            *,
            row_number() OVER (
                ORDER BY
                    kuntakoodi,
                    coalesce(tienimi_su, tienimi_ru),
                    original_mml_link_id,
                    seq
            ) AS order
        FROM splitted_sublinks
    ) numbered
    CROSS JOIN (
        SELECT coalesce(max(fid), 0) AS n
        FROM :schema.fix_layer_link
    ) num_existing_links
)
-- SELECT original_mml_link_id, kuntakoodi, tienimi_su, ST_AsEWKT(geom) AS geom FROM splitted_sublinks_with_id;
INSERT INTO :schema.fix_layer_link (
    fid,
    link_id,
    internal_id,
    original_link_id,
    start_location_m_on_original_link,
    ajosuunta,
    kuntakoodi, linkkityyp, silta_alik, link_tila,
    tienimi_su, tienimi_ru,
    is_generic_bus, is_tall_electric_bus, is_tram, is_train, is_metro, is_ferry,
    description,
    geom
)
SELECT
    generated_fid AS fid,
    'hsl:' || gen_random_uuid() || ':1' AS link_id,
    1000000000 + generated_fid AS internal_id,
    original_mml_link_id,
    start_location_m_on_original_link,
    ajosuunta,
    kuntakoodi,
    linkkityyp,
    silta_alik,
    link_tila,
    tienimi_su,
    tienimi_ru,
    true, true, false, false, false, false,
    description,
    geom
FROM splitted_sublinks_with_id
ORDER BY fid;

-- This is needed if accessing the dr_linkki_fixup view after updating
-- underlying data.
REFRESH MATERIALIZED VIEW :schema.dr_linkki_fixup;


-- Add "fixup layer" links to fix incorrect directions of traffic flow in
-- original Digiroad links or the splitted ones.
WITH
drl_fix AS (
    SELECT
        row_number() OVER () AS rn,
        t.link_id,
        t.ajosuunta,
        drl.ajosuunta AS original_ajosuunta,
        CASE
            WHEN t.linkkityyp_override IS NOT NULL THEN t.linkkityyp_override
            WHEN drl.linkkityyp = 8 THEN 99
            ELSE drl.linkkityyp
        END AS linkkityyp,
        drl.linkkityyp AS original_linkkityyp,
        CASE
            WHEN t.linkkityyp_override IS NOT NULL OR drl.linkkityyp = 8
                THEN 'Correct link type suitable for bus traffic.'
            WHEN t.ajosuunta = 2 AND drl.ajosuunta <> 2
                THEN 'Change one-way link to bidirectional.'
            WHEN t.ajosuunta <> 2 AND drl.ajosuunta = 2
                THEN 'Change bidirectional link to one-way.'
            ELSE 'Reverse direction of traffic flow on link.'
        END AS description
    FROM (
        VALUES
            ('410f5711-d069-4ec0-af9a-d536a090ec1e:1', 2, NULL), -- E2045-E2047, E2046-E2048, E2047-E2045
            ('85a74090-a925-493e-98af-600a0514c988:1', 2, 3),    -- E4043-E4037, E4043-E4038, E4043-E4045
            ('9b0bf1ed-05ce-4abc-9615-9c235695c411:1', 2, NULL), -- E6157-E6154 #1, E6160-6154
            ('3e30342b-d503-4363-8677-ca41dc8117f2:1', 2, NULL), -- E6157-E6154 #2
            ('090a7323-cd39-406a-8936-74ec353c7a35:1', 2, NULL), -- E6157-E6154 #3
            ('d158f0c6-908c-4583-b6f8-5f26777f40a0:1', 2, NULL), -- E6157-E6154 #4
            ('b6fa3249-ac65-4d5a-93d2-14c9b7546a9d:1', 2, NULL), -- H1215-H1273 #1, H1215-H0201, H1215-H1907, H1224-H1214, H1260-H1214, H1906-H1214, H1908-H1214
            ('fb11285c-eac2-4e17-a59c-afb9066b45b1:1', 2, NULL), -- H1215-H1273 #2
            ('e83faae9-0af1-4e94-a2de-76c7584f1155:1', 2, NULL), -- H1215-H1273 #3
            ('29a09932-0025-4e22-ada2-7b09f0ce9e72:1', 2, NULL), -- H1224-H1254, H1273-H1232
            ('d3fa6401-52bf-4fea-8534-b36e1b5ad601:1', 3, NULL), -- H1240-H1217 #1
            ('34e7f4db-5db4-46a8-85e7-f98620515ed6:1', 3, NULL), -- H1240-H1217 #2
            ('6d8fc9bd-44f1-4cae-9edd-23792359f121:1', 3, NULL), -- H1240-H1217 #3
            ('a3a9cb75-d24e-4aa1-9d66-d952b35b5264:1', 2, NULL), -- H1378-H2071, H1918-H2071
            ('52feba80-36b0-4de2-8a16-c0553ab84521:1', 2, NULL), -- H1648-H1646, H1648-H1665, H1727-H1646, H1740-H1665
            ('90c18863-d335-47e1-b281-b1da4a6ec33a:1', 4, NULL), -- H2061-H2401, H2401-H2403, H2403-H2405, H2403-H2129, H2508-H2418 #1
            ('9a8f077c-97b2-4edd-8793-1d74008fcecd:1', 4, NULL), -- H2061-H2401, H2401-H2403, H2403-H2405, H2403-H2129, H2508-H2418 #2
            ('ea80b030-20c7-4544-80a3-99151717654a:1', 4, NULL), -- H2061-H2401, H2401-H2403, H2403-H2405, H2403-H2129, H2508-H2418 #3
            ('0014f0ad-10de-43df-84d3-2252d85f69b7:3', 2, NULL), -- H3254-H3256, H3254-H3258, H3458-H3256
            ('387891de-7a31-48c0-ac4f-8f4148827932:2', 2, NULL), -- H3466-H3241
            ('5d633e8b-f729-4c5a-a8e9-84e791195a33:1', 2, NULL), -- H4675-H4673
            ('276e86a6-2380-4bb7-8f73-cbbe360925dc:1', 3, NULL), -- Järvenpää terminal (e.g. Jä2118-Jä2121)
            ('b88ca87e-59c0-4a21-9a56-6e5db65e2519:1', 2, NULL), -- Mä8000-Mä8052
            ('9606dd80-768a-4b66-9d53-e3d550a10c13:1', 2, NULL), -- Nu7000-Nu8170, Nu8021-Nu7000
            ('1e317f36-462b-4b86-9f0f-9a3abd475138:2', 2, NULL), -- V6429-V6431 #1
            ('3a791287-b76b-45c8-85b4-ff72a5c35f48:2', 2, NULL), -- V6429-V6431 #2
            ('7423375d-81d6-437e-8e70-b95a96ac7b07:2', 2, NULL)  -- V6429-V6431 #3
    ) AS t(link_id, ajosuunta, linkkityyp_override)

    -- Filter out links already corrected in the fix_layer_link table or the
    -- links that are possibly fixed in the future Digiroad data release.

    INNER JOIN :schema.dr_linkki drl USING (link_id)
    LEFT JOIN :schema.fix_layer_link fll
        ON fll.original_link_id = t.link_id
            AND fll.ajosuunta = t.ajosuunta
    WHERE
        fll.original_link_id IS NULL -- anti-join
        AND (
            drl.ajosuunta <> t.ajosuunta
            OR drl.linkkityyp = 8
        )
)
-- SELECT * FROM drl_fix ORDER BY rn;
, new_links AS (
    SELECT
        generated_fid.n AS fid,
        'hsl:' || drl.link_id AS link_id,
        1000000000 + generated_fid.n AS internal_id,
        drl.link_id AS original_link_id,
        drl_fix.ajosuunta,
        kuntakoodi,
        drl_fix.linkkityyp,
        silta_alik, link_tila,
        tienimi_su, tienimi_ru,
        true AS is_generic_bus,
        true AS is_tall_electric_bus,
        false AS is_tram,
        false AS is_train,
        false AS is_metro,
        false AS is_ferry,
        description,
        geom
    FROM drl_fix
    INNER JOIN :schema.dr_linkki drl USING (link_id)
    CROSS JOIN LATERAL (
        SELECT num_existing_links.n + drl_fix.rn AS n
        FROM (
            SELECT coalesce(max(fid), 0) AS n
            FROM :schema.fix_layer_link
        ) num_existing_links
    ) generated_fid
    WHERE drl.link_id NOT IN (
        SELECT original_link_id
        FROM :schema.fix_layer_link
        WHERE original_link_id IS NOT NULL
    )
)
-- SELECT * FROM new_links ORDER BY fid;
, inserts AS (
    INSERT INTO :schema.fix_layer_link (
        fid, link_id, internal_id, original_link_id,
        ajosuunta, kuntakoodi, linkkityyp, silta_alik, link_tila,
        tienimi_su, tienimi_ru,
        is_generic_bus, is_tall_electric_bus, is_tram, is_train, is_metro, is_ferry,
        description,
        geom
    )
    SELECT
        fid, link_id, internal_id, original_link_id,
        ajosuunta, kuntakoodi, linkkityyp, silta_alik, link_tila,
        tienimi_su, tienimi_ru,
        is_generic_bus, is_tall_electric_bus, is_tram, is_train, is_metro, is_ferry,
        description,
        geom
    FROM new_links
    ORDER BY fid
    RETURNING link_id
)
-- SELECT * FROM inserts
, updateable_fix_layer_links AS (
    SELECT
        fll.fid,
        fll.link_id,
        fll.original_link_id,
        fll.ajosuunta,
        fix.ajosuunta AS correct_ajosuunta,
        CASE
            WHEN fll.description IS NOT NULL THEN
                fll.description || ' ' || fix.description
            ELSE fix.description
        END AS description
    FROM :schema.fix_layer_link fll
    INNER JOIN drl_fix fix ON fix.link_id = fll.original_link_id
    WHERE fll.ajosuunta <> fix.ajosuunta
)
-- SELECT * FROM updateable_fix_layer_links;
, updates AS (
    UPDATE :schema.fix_layer_link AS l
    SET
        ajosuunta = u.correct_ajosuunta,
        description = u.description
    FROM updateable_fix_layer_links u
    WHERE l.link_id = u.link_id
    RETURNING l.fid, l.link_id, l.original_link_id, l.ajosuunta
)
-- Print previously splitted links whose direction was updated.
SELECT * FROM updates ORDER BY fid;


-- Move Digiroad stop points along splitted links to new target links.
WITH
drp_fix AS (
    SELECT DISTINCT
        drp.id AS stop_point_id,
        first_value(fll.link_id) OVER ( -- take first if multiple matches (very rare corner case)
            PARTITION BY fll.original_link_id
            ORDER BY fll.start_location_m_on_original_link
        ) AS new_link_id
    FROM :schema.dr_pysakki drp
    INNER JOIN :schema.fix_layer_link fll ON fll.original_link_id = drp.link_id
    WHERE
        drp.valtak_id NOT IN (
            SELECT valtak_id FROM :schema.fix_layer_stop_point
        )
        AND (
            fll.start_location_m_on_original_link IS NULL
            OR (
                -- This condition may match to two consecutive links if stop
                -- point is located at the boundary point of two links.
                drp.sijainti_m >= fll.start_location_m_on_original_link
                AND drp.sijainti_m <= (fll.start_location_m_on_original_link + ST_Length(fll.geom))
            )
        )
),
-- Calculate new 'sijainti_m' value for each stop point.
drp_fix_2 AS (
    SELECT
        row_number() OVER (
            ORDER BY drp.matk_tunn, drp.valtak_id
        ) AS rn,
        drp.*,
        fix.new_link_id,
        CASE
            WHEN fll.start_location_m_on_original_link IS NULL THEN drp.sijainti_m
            ELSE drp.sijainti_m - fll.start_location_m_on_original_link
        END AS new_sijainti_m
    FROM drp_fix fix
    INNER JOIN :schema.dr_pysakki drp ON drp.id = fix.stop_point_id
    INNER JOIN :schema.fix_layer_link fll ON fll.link_id = fix.new_link_id
)
INSERT INTO :schema.fix_layer_stop_point (
    fid,
    internal_id,
    valtak_id,
    yllapitaja,
    yllap_tunn,
    link_id,
    matk_tunn,
    vaik_suunt,
    sijainti_m,
    kuntakoodi,
    nimi_su,
    nimi_ru,
    geom
)
SELECT
    generated_fid.n,
    1000000000 + generated_fid.n,
    valtak_id,
    yllapitaja,
    yllap_tunn,
    new_link_id,
    matk_tunn,
    vaik_suunt,
    new_sijainti_m,
    kuntakoodi,
    nimi_su,
    nimi_ru,
    geom
FROM drp_fix_2
CROSS JOIN LATERAL (
    SELECT num_existing_stops.n + rn AS n
    FROM (
        SELECT coalesce(max(fid), 0) AS n
        FROM :schema.fix_layer_stop_point
    ) num_existing_stops
) generated_fid;


ALTER TABLE :schema.fix_layer_link DROP COLUMN start_location_m_on_original_link;
ALTER TABLE :schema.fix_layer_link DROP COLUMN internal_id CASCADE;

ALTER TABLE :schema.fix_layer_stop_point DROP COLUMN internal_id;
ALTER TABLE :schema.fix_layer_stop_point DROP COLUMN kuntakoodi;

-- Now you can run the rewrite_fixup_geopkg.sh script file to update the
-- GeoPackage file (fixup.gpkg).
