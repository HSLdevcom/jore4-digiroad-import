-- NOTE! All SQL statements in this file must be idempotent, meaning that
-- the statements must be able to be executed multiple times without creating
-- duplicate rows in the database.


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
            (1, 'SRID=3067;LINESTRING(385272.0 6672146.0 0 0, 385291.0 6672159.0 0 0)') -- Viikki
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


-- Add HSL supplementary links that are missing from Digiroad.
-- After this, in the next operation, we topologically connect all new links to
-- the network by splitting existing Digiroad links if necessary.
WITH
drl_fix AS (
    SELECT
        row_number() OVER () AS rn,
        from_link_id,
        to_link_id,
        joint_link_ajosuunta,
        from_link_terminus_opt,
        closest_point_ewkt_on_to_link_opt,
        interim_points_arr
    FROM (
        VALUES
            -- E1970-E1146
            ('a9302c4c-2811-4bb5-8682-996859b824a8:1', 'e79d9285-97e3-420f-b5b4-a035ddb8a237:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[]),
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
                ]
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
                ]
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
                ]
            ),
            -- E2180-E2014, E2196-E2180
            ('44d535a1-901e-44a5-9d30-b1cf1d242a8e:1', 'c60da352-e00f-4b86-8e1f-177a2af5e909:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[]),
            -- E4258-E4931
            ('d18af8a7-6d4e-4237-8843-8cde8a44e5ec:1', 'cdb8591b-68d7-4d44-947b-3540abfee994:1', 4, 'start', NULL::text, ARRAY[]::geometry(Point)[]),
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
                ]
            ),
            -- H2041-H2059, H2047-H2059, H2050-H2059 #1
            (
                '97ad845a-6574-4233-96a8-9a5870ed6dc3:1',
                '2ce16faa-76d8-46b7-974b-9d39d52dd8b7:1',
                3,
                'end',
                'SRID=3067;POINT(385909.3 6672180.4)',
                ARRAY[
                    ST_GeomFromEWKT('SRID=3067;POINT(385921.3 6672169.7)')
                ]
            ),
            -- H2041-H2059, H2047-H2059, H2050-H2059 #2
            ('a935dcb1-9fda-4d2c-a2af-6871c2c1ec4b:1', '2ce16faa-76d8-46b7-974b-9d39d52dd8b7:1', 4, 'end', 'SRID=3067;POINT(385909.3 6672180.4)', ARRAY[]::geometry(Point)[]),
            -- H2041-H2059, H2047-H2059, H2050-H2059 #3
            ('7c985dfd-e37f-47ed-b564-569994464215:1', 'a935dcb1-9fda-4d2c-a2af-6871c2c1ec4b:1', 4, 'end', 'SRID=3067;POINT(385892.7 6672193.2)', ARRAY[]::geometry(Point)[]),
            -- H4716-H4161
            ('d7a34688-52d5-40b6-aeaa-915602fb4ba7:1', '9cbe8c14-4ad8-4435-b918-31b4d339e55e:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[]),
            -- Mä8000-Mä8052
            ('b88ca87e-59c0-4a21-9a56-6e5db65e2519:1', 'd7120fe2-8a7e-4cdc-8b26-ed8c20276bc0:2', 2, 'start', NULL::text, ARRAY[]::geometry(Point)[]),
            -- V1560-V1506, V1560-V1521, V1561-V1521, V1567-V1521
            ('d82301f3-8aca-42d7-ae61-49c721c1be30:1', 'f0fbd3a0-3697-49ee-a6d9-50f4b34ac499:1', 4, 'start', NULL::text, ARRAY[]::geometry(Point)[]),
            -- V1565-V1505, V1565-V1560, V1565-V1567
            ('d82301f3-8aca-42d7-ae61-49c721c1be30:1', 'f0fbd3a0-3697-49ee-a6d9-50f4b34ac499:1', 3, 'end', NULL::text, ARRAY[]::geometry(Point)[]),
            -- V1704-V1746, V1704-V1748, V1715-V1707, V1715-V1767, V1715-V1799, V1744-1799
            ('7ddd8c8a-50d5-463a-a679-178047c1787c:1', '141d4255-937a-4004-b8d6-de826ae6d63e:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[]),
            -- V1722-V1711, V1722-V1743, V1745-V1798, V1747-V1798, V1758-V1711, V1758-V1743, V1767-V1711
            ('bd44ed9d-5333-4ca8-992d-665fc122f26b:1', 'f7f991b5-c5f5-40bf-b13b-2ebe2883d952:1', 2, NULL::text, NULL::text, ARRAY[]::geometry(Point)[])
    ) AS t(from_link_id, to_link_id, joint_link_ajosuunta, from_link_terminus_opt, closest_point_ewkt_on_to_link_opt, interim_points_arr)
),
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
        interim_points_arr
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
joint_links AS (
    SELECT
        rn,
        ST_AddMeasure(
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
        END AS description
    FROM drl_fix_2 fix
    INNER JOIN :schema.dr_linkki from_drl ON from_drl.link_id = fix.from_link_id
    CROSS JOIN LATERAL (
        SELECT
            ST_Z(start_point) AS z_start,
            ST_Z(end_point) AS z_end
    ) z
    CROSS JOIN LATERAL (
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
    is_generic_bus, is_tall_electric_bus, is_tram, is_train, is_metro, is_ferry,
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
    true, true, false, false, false, false,
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
        AND link_supp.hsl_infra_source <> 'digiroad_r_mml'

        AND
        (
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
    GROUP BY link_mml.link_id
),
mml_link_split_fraction_ranges AS (
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
mml_link_split_substrings AS (
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
    FROM mml_link_split_fraction_ranges r
    INNER JOIN :schema.dr_linkki_fixup l USING (link_id)
    CROSS JOIN LATERAL (
        SELECT ST_LineSubstring(ST_Force3D(l.geom), r.start_fraction, r.end_fraction) AS geom_3d
    ) substr
    CROSS JOIN LATERAL (
        SELECT ST_Length(substr.geom_3d) AS _2d
    ) len
)
-- SELECT original_mml_link_id, seq, start_location_m_on_original_link, ST_AsEWKT(geom) AS geom FROM mml_link_split_substrings;
, mml_link_split_substrings_with_id AS (
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
        FROM mml_link_split_substrings
    ) numbered
    CROSS JOIN (
        SELECT coalesce(max(fid), 0) AS n
        FROM :schema.fix_layer_link
    ) num_existing_links
)
-- SELECT original_mml_link_id, kuntakoodi, tienimi_su, ST_AsEWKT(geom) AS geom FROM mml_link_split_substrings_with_id;
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
FROM mml_link_split_substrings_with_id
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
            WHEN t.ajosuunta = 2 AND drl.ajosuunta <> 2
                THEN 'Change one-way link to bidirectional.'
            WHEN t.ajosuunta <> 2 AND drl.ajosuunta = 2
                THEN 'Change bidirectional link to one-way.'
            ELSE 'Reverse direction of traffic flow on link.'
        END AS description
    FROM (
        VALUES
            ('9b0bf1ed-05ce-4abc-9615-9c235695c411:1', 2), -- E6157-E6154 #1
            ('3e30342b-d503-4363-8677-ca41dc8117f2:1', 2), -- E6157-E6154 #2
            ('090a7323-cd39-406a-8936-74ec353c7a35:1', 2), -- E6157-E6154 #3
            ('d158f0c6-908c-4583-b6f8-5f26777f40a0:1', 2), -- E6157-E6154 #4
            ('b6fa3249-ac65-4d5a-93d2-14c9b7546a9d:1', 2), -- H1215-H1273 #1
            ('fb11285c-eac2-4e17-a59c-afb9066b45b1:1', 2), -- H1215-H1273 #2
            ('e83faae9-0af1-4e94-a2de-76c7584f1155:1', 2), -- H1215-H1273 #3
            ('29a09932-0025-4e22-ada2-7b09f0ce9e72:1', 2), -- H1224-H1254, H1273-H1232
            ('52feba80-36b0-4de2-8a16-c0553ab84521:1', 2), -- H1648-H1646, H1648-H1665, H1740-H1665
            ('c6877c6b-1a4d-444a-a1e5-9d956a1903df:1', 4), -- H2061-H2520, H2061-H2521 #1
            ('b64c424c-2cb0-41e5-aec3-264b36a2e00c:1', 4), -- H2061-H2520, H2061-H2521 #2
            ('0014f0ad-10de-43df-84d3-2252d85f69b7:2', 2), -- H3254-H3256, H3254-H3258, H3458-H3256
            ('387891de-7a31-48c0-ac4f-8f4148827932:1', 2), -- H3466-H3241
            ('276e86a6-2380-4bb7-8f73-cbbe360925dc:1', 3), -- Järvenpää terminal (e.g. Jä2118-Jä2121)
            ('b88ca87e-59c0-4a21-9a56-6e5db65e2519:1', 2), -- Mä8000-Mä8052
            ('84ea4463-e7b2-455c-8cc7-c600ebddc9ee:1', 2), -- V6429-V6431 #1
            ('a8c0e727-e0fb-4aaf-8dbc-19ea2e74af70:1', 2), -- V6429-V6431 #2
            ('7423375d-81d6-437e-8e70-b95a96ac7b07:1', 2)  -- V6429-V6431 #3
    ) AS t(link_id, ajosuunta)

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
        kuntakoodi, linkkityyp, silta_alik, link_tila,
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
