ALTER TABLE :schema.dr_pysakki

    ALTER COLUMN gid SET NOT NULL,
    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN valtak_id SET NOT NULL,
    ALTER COLUMN kuntakoodi SET NOT NULL,
    ALTER COLUMN koord_x SET NOT NULL,
    ALTER COLUMN koord_y SET NOT NULL,
    ALTER COLUMN sijainti_m SET NOT NULL,
    ALTER COLUMN vaik_suunt SET NOT NULL,
    ALTER COLUMN geom SET NOT NULL,

    ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (gid),
    ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id);
