-- Do these on the bash terminal of switch-db2:
-- 
-- shp2pgsql -I -s 4326 /rael_data/switch/Models/wecc_v3_inputs/maps/grace_env_layers/environmental2_allProjectsMerged_superCREZ_relaxed_calculated_wgs84.shp public.renewable_energy_inclusion_zones_category_2 | psql switch_wecc
-- shp2pgsql -I -s 4326 /rael_data/switch/Models/wecc_v3_inputs/maps/grace_env_layers/environmental3_allProjectsMerged_superCREZ_relaxed_calculated_wgs84.shp public.renewable_energy_inclusion_zones_category_3 | psql switch_wecc
-- 
-- Run these in postgres:

CREATE TABLE public.renewable_energy_inclusion_zones (
    category text PRIMARY KEY
);
SELECT AddGeometryColumn ('public', 'renewable_energy_inclusion_zones', 'geom', 
                          4326, 'MULTIPOLYGON', 2);
CREATE INDEX renewable_energy_inclusion_zones_gix 
    ON public.renewable_energy_inclusion_zones USING GIST (geom);


CREATE INDEX renewable_energy_inclusion_zones_category_3_gix 
    ON public.renewable_energy_inclusion_zones_category_3 USING GIST (geom);
CREATE INDEX renewable_energy_inclusion_zones_category_2_gix 
    ON public.renewable_energy_inclusion_zones_category_2 USING GIST (geom);

INSERT INTO public.renewable_energy_inclusion_zones (category, geom)
    SELECT '2', ST_UNION(geom) 
    FROM public.renewable_energy_inclusion_zones_category_2;
INSERT INTO public.renewable_energy_inclusion_zones (category, geom)
    SELECT '3', ST_UNION(geom)
    FROM public.renewable_energy_inclusion_zones_category_3;
