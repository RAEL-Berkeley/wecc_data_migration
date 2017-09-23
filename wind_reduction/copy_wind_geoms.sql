-- Copy over geometry info for wind plants from the switch_gis schema.
-- On switch-db2, go to temp directory and execute:
-- pg_dump --table public.proposed_projects_from_backup --table public.proposed_projects_project_id_seq --no-owner --file proposed_projects_from_backup.pg_dump --format c switch_gis
-- pg_restore --dbname switch_wecc --no-owner proposed_projects_from_backup.pg_dump

-- Alter generation_plant table to include polygon area of plant, and multiline geometry of connection to grid

-- Test the merge statement .. Looked good to me. 
-- I also tested that all matching rows had NULL geom columns
SELECT *, ST_Centroid(proposed_projects_from_backup.the_geom),
    proposed_projects_from_backup.substation_connection_geom,
    proposed_projects_from_backup.the_geom
FROM switch.generation_plant, switch.ampl__proposed_projects_v3, public.proposed_projects_from_backup
WHERE ampl__proposed_projects_v3.project_id = generation_plant.generation_plant_id
    AND proposed_projects_from_backup.project_id = ampl__proposed_projects_v3.gen_info_project_id
    AND generation_plant.geom is null
;

-- Copy data into the generation_plant table. 
-- Only write if the geom column is empty to avoid any overwrites..
UPDATE switch.generation_plant
SET geom = ST_Centroid(proposed_projects_from_backup.the_geom),
    substation_connection_geom = proposed_projects_from_backup.substation_connection_geom,
    geom_area = proposed_projects_from_backup.the_geom
FROM switch.ampl__proposed_projects_v3, public.proposed_projects_from_backup
WHERE ampl__proposed_projects_v3.project_id = generation_plant.generation_plant_id
    AND proposed_projects_from_backup.project_id = ampl__proposed_projects_v3.gen_info_project_id
    AND generation_plant.geom is null
;

