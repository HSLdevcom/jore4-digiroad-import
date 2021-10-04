-- create a temporary table for storing the data read from the CSV file
DROP TABLE IF EXISTS infrastructure_network.infrastructure_link_tmp;
CREATE TABLE infrastructure_network.infrastructure_link_tmp (
    external_link_id text PRIMARY KEY,
    external_link_source text,
    shape jsonb,
    direction text,
    estimated_length_in_metres double precision
);

-- import data from the csv file
-- the \copy command must be single-line
-- the \copy command does not allow substituting variables, thus building it as a string first
\set copy_command '\\copy infrastructure_network.infrastructure_link_tmp (external_link_id, external_link_source, shape, direction, estimated_length_in_metres) FROM ' :'csvfile' 'WITH (FORMAT CSV, HEADER);'
:copy_command

-- upserting data to the infrastructure_link table
-- warning: this will not delete links that are no longer in use!
INSERT INTO infrastructure_network.infrastructure_link
    (external_link_id, external_link_source, shape, direction, estimated_length_in_metres)
    SELECT 
        external_link_id,
        external_link_source,
        ST_GeomFromGeoJSON(shape) as shape,
        direction,
        estimated_length_in_metres
    FROM infrastructure_network.infrastructure_link_tmp
    ON CONFLICT (external_link_id, external_link_source) DO UPDATE SET
        external_link_source = excluded.external_link_source,
        shape = excluded.shape,
        direction = excluded.direction,
        estimated_length_in_metres = excluded.estimated_length_in_metres;

-- dropping temporary table
DROP TABLE infrastructure_network.infrastructure_link_tmp;
