-- Do these on the bash terminal of switch-db2:
-- 
-- shp2pgsql -I -s 4326 /rael_data/switch/Models/wecc_v3_inputs/maps/grace_env_layers/environmental2_allProjectsMerged_superCREZ_relaxed_calculated_wgs84.shp public.renewable_energy_exclusion_zones_category_2 | psql switch_wecc
-- shp2pgsql -I -s 4326 /rael_data/switch/Models/wecc_v3_inputs/maps/grace_env_layers/environmental3_allProjectsMerged_superCREZ_relaxed_calculated_wgs84.shp public.renewable_energy_exclusion_zones_category_3 | psql switch_wecc
-- 
-- Run these in postgres:

CREATE TABLE public.renewable_energy_exclusion_zones (
    category text PRIMARY KEY
);
SELECT AddGeometryColumn ('public', 'renewable_energy_exclusion_zones', 'geom', 
                          4326, 'MULTIPOLYGON', 2);
CREATE INDEX renewable_energy_exclusion_zones_gix 
    ON public.renewable_energy_exclusion_zones USING GIST (geom);


CREATE INDEX renewable_energy_exclusion_zones_category_3_gix 
    ON public.renewable_energy_exclusion_zones_category_3 USING GIST (geom);
CREATE INDEX renewable_energy_exclusion_zones_category_2_gix 
    ON public.renewable_energy_exclusion_zones_category_2 USING GIST (geom);

INSERT INTO public.renewable_energy_exclusion_zones (category, geom)
    SELECT '2', ST_UNION(geom) 
    FROM public.renewable_energy_exclusion_zones_category_2;
-- Exclusion zone 3 is supposed to include zone 2 restrictions, but the underlying
-- data files were showing the marginal contributions of zone 3. 
-- So, do a union of zones 2 & 3
INSERT INTO public.renewable_energy_exclusion_zones (category, geom)
    SELECT '3', ST_UNION(geom)
    FROM public.renewable_energy_exclusion_zones_category_3;
INSERT INTO public.renewable_energy_exclusion_zones (category, geom)
    SELECT '2+3', ST_UNION(geom)
    FROM public.renewable_energy_exclusion_zones
    WHERE category = '2' OR category = '3';
