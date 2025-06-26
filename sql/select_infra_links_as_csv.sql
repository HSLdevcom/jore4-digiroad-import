COPY (
    SELECT
        source.link_id as external_link_id,
        source.hsl_infra_source as external_link_source,
        ST_AsGeoJSON(ST_Transform(source.geom, 4326))::jsonb as shape,
        CASE
            WHEN source.ajosuunta = 2 THEN 'bidirectional'
            WHEN source.ajosuunta = 3 THEN 'backward'
            WHEN source.ajosuunta = 4 THEN 'forward'
        END AS direction,
        ST_Length(source.geom) as estimated_length_in_metres
    FROM :schema.dr_linkki_fixup source
    WHERE
        source.ajosuunta IN (2, 3, 4) -- filter out possibly invalid links
        AND source.linkkityyp IN (
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

) TO STDOUT WITH (FORMAT CSV, HEADER)
