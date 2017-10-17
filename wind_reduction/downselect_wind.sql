-- Try to update the catalog of wind plants based on geographic overlap with
-- Grace's environmental exclusion datasets (which are specified as areas where
-- renewables are allowed). This approach proved to be ineffective due to the
-- mostly non-overlapping shapes of our wind farms and Grace's. I ended up
-- pursuing a different approach of creating new potential wind projects for each
-- of Grace's areas; see create_gen_plants.sql

-------------------------------
-- Q1. Which technologies are being used by each scenario; how many are geo-located?
-- Base case from AMPL currently has most wind plants geo-located. All
-- non-geolocated wind plants in that scenario are existing.
SELECT generation_plant_scenario_id, generation_plant_scenario.name, gen_tech,
	(generation_plant.geom_area IS NOT NULL OR generation_plant.geom IS NOT NULL) as is_geolocated,
	count(*)
  FROM switch.generation_plant  
    JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
    JOIN switch.generation_plant_scenario USING (generation_plant_scenario_id)
GROUP BY 1, 2, 3, 4
ORDER BY 1,2;

-------------------------------
-- Q2. How much generation capacity in CA is available with each exclusion level?
select switch.generation_plant.gen_tech, 'N/A' as category, 
    round(sum(capacity_limit_mw)) AS cap_limit_mw_in_CA,
	count(*) AS num_plants
from switch.generation_plant
	JOIN switch.load_zone USING (load_zone_id)
WHERE load_zone.name like 'CA_%'
group by 1, 2
UNION
select switch.generation_plant.gen_tech, category, 
    round(sum(capacity_limit_mw)), count(*)
from public.renewable_energy_inclusion_zones,
	switch.generation_plant
	JOIN switch.load_zone USING (load_zone_id)
where ST_Intersects(generation_plant.geom_area, renewable_energy_inclusion_zones.geom)
    AND category = '2'
	AND load_zone.name like 'CA_%'
group by 1, 2
UNION
select switch.generation_plant.gen_tech, category, 
    round(sum(capacity_limit_mw)), count(*)
from public.renewable_energy_inclusion_zones,
	switch.generation_plant
	JOIN switch.load_zone USING (load_zone_id)
where ST_Intersects(generation_plant.geom_area, renewable_energy_inclusion_zones.geom)
    AND category = '3'
	AND load_zone.name like 'CA_%'
group by 1, 2
UNION SELECT 'Wind', '2 report', 18740, NULL
UNION SELECT 'Wind', '3 report', 9531, NULL
UNION SELECT 'Central_PV', '2 report', 1028582, NULL
UNION SELECT 'Central_PV', '3 report', 357474, NULL
ORDER BY 1,2
;


-- -------------------------------------------
-- Create new sets of generation plants based on overlap with Grace's maps
-- that show allowed build areas based on layers of legal, environmental and
-- other various exclusions.

INSERT INTO generation_plant_scenario 
    (generation_plant_scenario_id, name)
VALUES 
    (4, 'Basecase v2 with exclusion zone 2 (geo-intersection)'),
    (5, 'Basecase v2 with exclusion zone 3 (geo-intersection)');

-- Ensure we have a clean slate for these two scenarios.
DELETE FROM generation_plant_scenario_member WHERE generation_plant_scenario_id=4 or generation_plant_scenario_id=5;


-- Exclusion zone 2 - For CA load zones, take all overlapping areas. 
-- For non-CA states, take full capacity.
INSERT INTO generation_plant_scenario_member 
    (generation_plant_scenario_id, generation_plant_id)
SELECT 4, generation_plant_id
FROM switch.generation_plant 
	JOIN public.renewable_energy_inclusion_zones ON (ST_Intersects(COALESCE(generation_plant.geom_area,generation_plant.geom), renewable_energy_inclusion_zones.geom))
	JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6
    AND category = '2'
UNION
SELECT 4, generation_plant_id
FROM switch.generation_plant 
	JOIN switch.load_zone USING (load_zone_id)
	JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
where generation_plant_scenario_id = 6
	AND load_zone.name not like 'CA_%';


-- Exclusion zone 3
INSERT INTO generation_plant_scenario_member 
    (generation_plant_scenario_id, generation_plant_id)
SELECT 5, generation_plant_id
FROM switch.generation_plant 
	JOIN public.renewable_energy_inclusion_zones ON (ST_Intersects(COALESCE(generation_plant.geom_area,generation_plant.geom), renewable_energy_inclusion_zones.geom))
	JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6
    AND category = '3'
UNION
SELECT 5, generation_plant_id
FROM switch.generation_plant 
	JOIN switch.load_zone USING (load_zone_id)
	JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
where generation_plant_scenario_id = 6
	AND load_zone.name not like 'CA_%';


-- Execute Q2 above to look at the data.. Not so great. Wind has too much capacity and solar has too little.

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


-- Reality check
select generation_plant_scenario_id, count(*) 
from generation_plant_scenario_member 
group by 1 
order by 1;

SELECT generation_plant.* 
FROM switch.generation_plant 
    JOIN switch.generation_plant_scenario_member USING(generation_plant_id)
WHERE generation_plant_scenario_id = 5;


SELECT 4, generation_plant_id
FROM switch.generation_plant 
	JOIN public.renewable_energy_inclusion_zones ON (ST_Intersects(COALESCE(generation_plant.geom_area,generation_plant.geom), renewable_energy_inclusion_zones.geom))
	JOIN switch.generation_plant_scenario_member USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6
    AND category = '2'


DROP TABLE tmp.gen_plant_scenario_5;
CREATE TABLE tmp.gen_plant_scenario_5 AS 
SELECT generation_plant.* 
    FROM generation_plant 
        JOIN generation_plant_scenario_member USING(generation_plant_id)
    WHERE generation_plant_scenario_id=5;
