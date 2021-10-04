SELECT json_agg(result)
FROM (
    SELECT
        source.link_id as external_link_id,
        ST_AsGeoJSON(ST_Transform(source.geom, 4326))::jsonb as shape,
        CASE
            WHEN source.ajosuunta = 2 THEN 'bidirectional'
            WHEN source.ajosuunta = 3 THEN 'backward'
            WHEN source.ajosuunta = 4 THEN 'forward'
            ELSE 'unknown'
        END AS direction,
        ST_Length(source.geom) as estimated_length_in_metres
    FROM :schema.dr_linkki source
) result