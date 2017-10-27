-- Create new wind projects per renewable inclusion zone.


INSERT INTO generation_plant_scenario 
    (generation_plant_scenario_id, name)
VALUES 
    (7, 'Renewable inclusion zones category 2 Wind only'),
    (8, 'Renewable inclusion zones category 3 Wind only');



-- Pull the set of geo-located wind generation plants within 0.25 degrees 
-- (roughly 25 km) of a wind inclusion zone. 
-- This used some pointers from a PostGIS Nearest Neighbors guide
-- http://www.bostongis.com/PrinterFriendly.aspx?content_name=postgis_nearest_neighbor
CREATE TABLE tmp.gen_plant_near_inclusion_cat2 AS
SELECT DISTINCT ON(generation_plant_id) generation_plant_id, 
    ST_DistanceSphere(COALESCE(generation_plant.geom_area, generation_plant.geom),
                renewable_energy_inclusion_zones_category_2.geom) / 1000 as dist_km
FROM renewable_energy_inclusion_zones_category_2, generation_plant
    JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
	JOIN switch.load_zone USING (load_zone_id)
WHERE generation_plant_scenario_id = 6
    AND generation_plant.gen_tech = 'Wind'
    AND (generation_plant.geom_area IS NOT NULL OR generation_plant.geom IS NOT NULL)
    AND renewable_energy_inclusion_zones_category_2.wind = 1
    AND load_zone.name like 'CA_%'
    AND ST_DWithin(COALESCE(generation_plant.geom_area, generation_plant.geom),
                   renewable_energy_inclusion_zones_category_2.geom, 0.25)
;
ALTER TABLE tmp.gen_plant_near_inclusion_cat2 ADD PRIMARY KEY (generation_plant_id);

-- Make a new project for each GIS plot from exclusion category 2.

-- Use inverse-distance weighted averages from nearest neighbors to interpolate 
-- costs, capacity factor profiles, etc.

-- Land use efficiency of 6.1 MW / km^2 is from table 2 of the report that
-- accompanied this gis dataset. N.B. The total wind capacity comes out
-- slightly high compared to the report. 21.0 GW derived from GIS data vs 
-- 18.7 GW in the report for category 2 and 12.0 GW vs 9.5 GW for category 3.
-- http://scienceforconservation.org/dl/TNC_ORB_Report_Final_2015.pdf

-- Assign each inclusion plot a load zone.
CREATE TABLE tmp.rz_cat2_to_lz AS
SELECT DISTINCT ON (rz_cat2.gid) rz_cat2.gid, load_zone.load_zone_id
FROM renewable_energy_inclusion_zones_category_2 rz_cat2
    , load_zone
WHERE rz_cat2.wind = 1
    AND ST_Intersects(rz_cat2.geom, load_zone.boundary)
ORDER BY rz_cat2.gid, ST_Area(ST_Intersection(rz_cat2.geom, load_zone.boundary)) DESC
;
ALTER TABLE tmp.rz_cat2_to_lz ADD PRIMARY KEY(gid);

CREATE TABLE tmp.new_wind_plants (generation_plant_id INT PRIMARY KEY);

WITH inserted AS (
INSERT INTO generation_plant (
    name, gen_tech, load_zone_id, connect_cost_per_mw, capacity_limit_mw,
    variable_o_m, forced_outage_rate, scheduled_outage_rate,
    max_age, min_build_capacity,
    is_variable, is_baseload, is_cogen, energy_source, 
    storage_efficiency, store_to_release_ratio, min_load_fraction,
    startup_fuel, startup_om, geom, geom_area
) 
    SELECT 
        rz_cat2.name || ': ' || rz_cat2.gid as name,
        'Wind' as gen_tech, 
        -- Only one load zone will appear from rz_cat2_to_lz for each rz_cat2
        -- row, but postgresql is worried about the theoretical possibility of
        -- duplicates, so use min(load_zone_id) to make postgresql happy.
        min(rz_cat2_to_lz.load_zone_id), 
        round(sum(connect_cost_per_mw / (nn_subset.dist_km + 0.01)) / sum(1/(nn_subset.dist_km + 0.01))) as connect_cost_per_mw, 
        round(rz_cat2.genarea_wi * 6.1) AS capacity_limit_mw,
        0 as variable_o_m, 
        0.05 as forced_outage_rate, 
        0.006 as scheduled_outage_rate, 
        30 as max_age, 
        0 as min_build_capacity, 
        TRUE as is_variable,
        FALSE as is_baseload,
        FALSE as is_cogen,
        'Wind' as energy_source,
        0 as storage_efficiency,
        0 as store_to_release_ratio,
        0 as min_load_fraction, 
        0 as startup_fuel,
        0 as startup_om,
        st_centroid(rz_cat2.geom) as geom, 
        rz_cat2.geom as geom_area
    FROM renewable_energy_inclusion_zones_category_2 rz_cat2
        JOIN tmp.rz_cat2_to_lz ON(rz_cat2.gid = rz_cat2_to_lz.gid)
        , generation_plant
        JOIN tmp.gen_plant_near_inclusion_cat2 nn_subset USING(generation_plant_id)
    WHERE rz_cat2.wind = 1
        AND ST_DWithin(COALESCE(generation_plant.geom_area, generation_plant.geom),
                       rz_cat2.geom, 0.25)
    GROUP BY rz_cat2.gid, rz_cat2.name, rz_cat2.geom
RETURNING generation_plant_id
)
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id)
    SELECT 7 as generation_plant_scenario_id, generation_plant_id
    FROM inserted
;


-- Calculate nearest neighbors and store for faster lookup.
CREATE TABLE tmp.nn_gen_plant_inclusion_zone AS
SELECT 
    gen_plant.generation_plant_id as generation_plant_id,
    nn_gen_plant.generation_plant_id AS nn_generation_plant_id,
    nn_subset.dist_km AS dist_km
FROM tmp.gen_plant_near_inclusion_cat2 nn_subset
    JOIN generation_plant nn_gen_plant USING(generation_plant_id)
    , generation_plant_scenario_member 
    JOIN generation_plant gen_plant USING(generation_plant_id)
WHERE generation_plant_scenario_id=7
        AND ST_DWithin(COALESCE(nn_gen_plant.geom_area, nn_gen_plant.geom),
                       gen_plant.geom_area, 0.25)
;
ALTER TABLE tmp.nn_gen_plant_inclusion_zone 
    ADD PRIMARY KEY (generation_plant_id, nn_generation_plant_id);
CREATE INDEX ON tmp.nn_gen_plant_inclusion_zone (nn_generation_plant_id);

----------
-- Get typical costs for wind. Manual inspection shows all wind plants have uniform costs
-- of 2117610 and 64170 for overnight and fixed O&M costs for all years in all relevant costs scenarios for proposed generation plants. 
CREATE TABLE tmp.wind_costs AS
SELECT generation_plant_cost_scenario_id, gen_tech, build_year, 
       avg(fixed_o_m) as fixed_o_m, STDDEV(fixed_o_m) as stddev_fixed_o_m,
       avg(overnight_cost) as overnight_cost, STDDEV(fixed_o_m) as stddev_overnight_cost
  FROM switch.generation_plant_cost
  JOIN generation_plant USING(generation_plant_id)
WHERE 
	gen_tech='Wind' and 
	(generation_plant_cost_scenario_id=1 or generation_plant_cost_scenario_id=4)
GROUP BY 1, 2, 3
;
ALTER TABLE tmp.wind_costs ADD PRIMARY KEY (generation_plant_cost_scenario_id, gen_tech, build_year);

-- ------------------------------------
-- Insert cost records for all new wind plants
INSERT INTO generation_plant_cost (
    generation_plant_cost_scenario_id, generation_plant_id, build_year, 
    fixed_o_m, overnight_cost)
SELECT 
    wind_costs.generation_plant_cost_scenario_id,
    nn_dist.generation_plant_id,
    wind_costs.build_year,
    sum(wind_costs.fixed_o_m / (dist_km + 0.01)) / sum(1/(dist_km + 0.01)) as fixed_o_m, 
    sum(wind_costs.overnight_cost / (dist_km + 0.01)) / sum(1/(dist_km + 0.01)) as overnight_cost
FROM tmp.wind_costs , tmp.nn_gen_plant_inclusion_zone nn_dist
GROUP BY 1, 2, 3
;


-- ------------------------------------
-- Insert interpolated cap factors for all new wind plants .. 

CREATE TABLE tmp.interpolated_variable_capacity_factors_historical AS
SELECT 
    nn.generation_plant_id,
    raw_timepoint_id, 
    -- All timestamp_utc will be the same, so just pick one of them
    min(timestamp_utc) AS timestamp_utc, 
    sum(capacity_factor / (dist_km + 0.01)) / sum(1/(dist_km + 0.01)) as capacity_factor
FROM tmp.nn_gen_plant_inclusion_zone nn 
    JOIN variable_capacity_factors_historical v ON (nn.nn_generation_plant_id = v.generation_plant_id)
GROUP BY 1, 2
;
ALTER TABLE tmp.interpolated_variable_capacity_factors_historical 
    ADD PRIMARY KEY (generation_plant_id, raw_timepoint_id)
;
INSERT INTO variable_capacity_factors_historical (
    generation_plant_id, raw_timepoint_id, timestamp_utc, capacity_factor)
SELECT * FROM tmp.interpolated_variable_capacity_factors_historical ;



-- Repeat all of that for category group 3..
-- Pull the set of geo-located wind generation plants within 0.25 degrees 
-- (roughly 25 km) of a wind inclusion zone. 
-- This used some pointers from a PostGIS Nearest Neighbors guide
-- http://www.bostongis.com/PrinterFriendly.aspx?content_name=postgis_nearest_neighbor
CREATE TABLE tmp.gen_plant_near_inclusion_cat3 AS
SELECT DISTINCT ON(generation_plant_id) generation_plant_id, 
    ST_DistanceSphere(COALESCE(generation_plant.geom_area, generation_plant.geom),
                renewable_energy_inclusion_zones_category_3.geom) / 1000 as dist_km
FROM renewable_energy_inclusion_zones_category_3, generation_plant
    JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
	JOIN switch.load_zone USING (load_zone_id)
WHERE generation_plant_scenario_id = 6
    AND generation_plant.gen_tech = 'Wind'
    AND (generation_plant.geom_area IS NOT NULL OR generation_plant.geom IS NOT NULL)
    AND renewable_energy_inclusion_zones_category_3.wind = 1
    AND load_zone.name like 'CA_%'
    AND ST_DWithin(COALESCE(generation_plant.geom_area, generation_plant.geom),
                   renewable_energy_inclusion_zones_category_3.geom, 0.25)
;
ALTER TABLE tmp.gen_plant_near_inclusion_cat3 ADD PRIMARY KEY (generation_plant_id);

-- Make a new project for each GIS plot from exclusion category 3.

-- Use inverse-distance weighted averages from nearest neighbors to interpolate 
-- costs, capacity factor profiles, etc.

-- Land use efficiency of 6.1 MW / km^2 is from table 2 of the report that
-- accompanied this gis dataset. N.B. The total wind capacity comes out
-- slightly high compared to the report. 21.0 GW derived from GIS data vs 
-- 18.7 GW in the report for category 2 and 12.0 GW vs 9.5 GW for category 3.
-- http://scienceforconservation.org/dl/TNC_ORB_Report_Final_2015.pdf

-- Assign each inclusion plot a load zone.
CREATE TABLE tmp.rz_cat3_to_lz AS
SELECT DISTINCT ON (rz_cat3.gid) rz_cat3.gid, load_zone.load_zone_id
FROM renewable_energy_inclusion_zones_category_3 rz_cat3
    , load_zone
WHERE rz_cat3.wind = 1
    AND ST_Intersects(rz_cat3.geom, load_zone.boundary)
ORDER BY rz_cat3.gid, ST_Area(ST_Intersection(rz_cat3.geom, load_zone.boundary)) DESC
;
ALTER TABLE tmp.rz_cat3_to_lz ADD PRIMARY KEY(gid);

DROP TABLE IF EXISTS tmp.new_wind_plants;
CREATE TABLE tmp.new_wind_plants (generation_plant_id INT PRIMARY KEY);

WITH inserted AS (
INSERT INTO generation_plant (
    name, gen_tech, load_zone_id, connect_cost_per_mw, capacity_limit_mw,
    variable_o_m, forced_outage_rate, scheduled_outage_rate,
    max_age, min_build_capacity,
    is_variable, is_baseload, is_cogen, energy_source, 
    storage_efficiency, store_to_release_ratio, min_load_fraction,
    startup_fuel, startup_om, geom, geom_area
) 
    SELECT 
        rz_cat3.name || ': ' || rz_cat3.gid as name,
        'Wind' as gen_tech, 
        -- Only one load zone will appear from rz_cat3_to_lz for each rz_cat3
        -- row, but postgresql is worried about the theoretical possibility of
        -- duplicates, so use min(load_zone_id) to make postgresql happy.
        min(rz_cat3_to_lz.load_zone_id), 
        round(sum(connect_cost_per_mw / (nn_subset.dist_km + 0.01)) / sum(1/(nn_subset.dist_km + 0.01))) as connect_cost_per_mw, 
        round(rz_cat3.genarea_wi * 6.1) AS capacity_limit_mw,
        0 as variable_o_m, 
        0.05 as forced_outage_rate, 
        0.006 as scheduled_outage_rate, 
        30 as max_age, 
        0 as min_build_capacity, 
        TRUE as is_variable,
        FALSE as is_baseload,
        FALSE as is_cogen,
        'Wind' as energy_source,
        0 as storage_efficiency,
        0 as store_to_release_ratio,
        0 as min_load_fraction, 
        0 as startup_fuel,
        0 as startup_om,
        st_centroid(rz_cat3.geom) as geom, 
        rz_cat3.geom as geom_area
    FROM renewable_energy_inclusion_zones_category_3 rz_cat3
        JOIN tmp.rz_cat3_to_lz ON(rz_cat3.gid = rz_cat3_to_lz.gid)
        , generation_plant
        JOIN tmp.gen_plant_near_inclusion_cat2 nn_subset USING(generation_plant_id)
    WHERE rz_cat3.wind = 1
        AND ST_DWithin(COALESCE(generation_plant.geom_area, generation_plant.geom),
                       rz_cat3.geom, 0.25)
    GROUP BY rz_cat3.gid, rz_cat3.name, rz_cat3.geom
RETURNING generation_plant_id
)
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id)
    SELECT 8 as generation_plant_scenario_id, generation_plant_id
    FROM inserted
;


-- Calculate nearest neighbors and store for faster lookup.
DROP TABLE IF EXISTS tmp.nn_gen_plant_inclusion_zone;
CREATE TABLE tmp.nn_gen_plant_inclusion_zone AS
SELECT 
    gen_plant.generation_plant_id as generation_plant_id,
    nn_gen_plant.generation_plant_id AS nn_generation_plant_id,
    nn_subset.dist_km AS dist_km
FROM tmp.gen_plant_near_inclusion_cat3 nn_subset
    JOIN generation_plant nn_gen_plant USING(generation_plant_id)
    , generation_plant_scenario_member 
    JOIN generation_plant gen_plant USING(generation_plant_id)
WHERE generation_plant_scenario_id=8
        AND ST_DWithin(COALESCE(nn_gen_plant.geom_area, nn_gen_plant.geom),
                       gen_plant.geom_area, 0.25)
;
ALTER TABLE tmp.nn_gen_plant_inclusion_zone 
    ADD PRIMARY KEY (generation_plant_id, nn_generation_plant_id);
CREATE INDEX ON tmp.nn_gen_plant_inclusion_zone (nn_generation_plant_id);

----------
-- Get typical costs for wind. Manual inspection shows all wind plants have uniform costs
-- of 2117610 and 64170 for overnight and fixed O&M costs for all years in all relevant costs scenarios for proposed generation plants. 
DROP TABLE IF EXISTS tmp.wind_costs;
CREATE TABLE tmp.wind_costs AS
SELECT generation_plant_cost_scenario_id, gen_tech, build_year, 
       avg(fixed_o_m) as fixed_o_m, STDDEV(fixed_o_m) as stddev_fixed_o_m,
       avg(overnight_cost) as overnight_cost, STDDEV(fixed_o_m) as stddev_overnight_cost
  FROM switch.generation_plant_cost
  JOIN generation_plant USING(generation_plant_id)
WHERE 
	gen_tech='Wind' and 
	(generation_plant_cost_scenario_id=1 or generation_plant_cost_scenario_id=4)
GROUP BY 1, 2, 3
;
ALTER TABLE tmp.wind_costs ADD PRIMARY KEY (generation_plant_cost_scenario_id, gen_tech, build_year);

-- ------------------------------------
-- Insert cost records for all new wind plants
INSERT INTO generation_plant_cost (
    generation_plant_cost_scenario_id, generation_plant_id, build_year, 
    fixed_o_m, overnight_cost)
SELECT 
    wind_costs.generation_plant_cost_scenario_id,
    nn_dist.generation_plant_id,
    wind_costs.build_year,
    sum(wind_costs.fixed_o_m / (dist_km + 0.01)) / sum(1/(dist_km + 0.01)) as fixed_o_m, 
    sum(wind_costs.overnight_cost / (dist_km + 0.01)) / sum(1/(dist_km + 0.01)) as overnight_cost
FROM tmp.wind_costs , tmp.nn_gen_plant_inclusion_zone nn_dist
GROUP BY 1, 2, 3
;


-- ------------------------------------
-- Insert interpolated cap factors for all new wind plants .. 
DROP TABLE IF EXISTS tmp.interpolated_variable_capacity_factors_historical;
CREATE TABLE tmp.interpolated_variable_capacity_factors_historical AS
SELECT 
    nn.generation_plant_id,
    raw_timepoint_id, 
    -- All timestamp_utc will be the same, so just pick one of them
    min(timestamp_utc) AS timestamp_utc, 
    sum(capacity_factor / (dist_km + 0.01)) / sum(1/(dist_km + 0.01)) as capacity_factor
FROM tmp.nn_gen_plant_inclusion_zone nn 
    JOIN variable_capacity_factors_historical v ON (nn.nn_generation_plant_id = v.generation_plant_id)
GROUP BY 1, 2
;
ALTER TABLE tmp.interpolated_variable_capacity_factors_historical 
    ADD PRIMARY KEY (generation_plant_id, raw_timepoint_id)
;
INSERT INTO variable_capacity_factors_historical (
    generation_plant_id, raw_timepoint_id, timestamp_utc, capacity_factor)
SELECT * FROM tmp.interpolated_variable_capacity_factors_historical ;

