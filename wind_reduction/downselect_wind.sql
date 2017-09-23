-- How much generation capacity is being excluded?
select switch.generation_plant.gen_tech, 'N/A' as category, sum(capacity_limit_mw)
from switch.generation_plant
group by 1, 2
UNION
select switch.generation_plant.gen_tech, category, sum(capacity_limit_mw)
from public.renewable_energy_exclusion_zones,
	switch.generation_plant
where not ST_Intersects(generation_plant.geom_area, renewable_energy_exclusion_zones.geom)
    AND category = '2'
group by 1, 2
UNION
select switch.generation_plant.gen_tech, category, sum(capacity_limit_mw)
from public.renewable_energy_exclusion_zones,
	switch.generation_plant
where not ST_Intersects(generation_plant.geom_area, renewable_energy_exclusion_zones.geom)
    AND category = '2+3'
group by 1, 2
ORDER BY 1,2
;

INSERT INTO generation_plant_scenario 
    (generation_plant_scenario_id, name)
VALUES 
    (4, 'Basecase with exclusion zone 2'), 
    (5, 'Basecase with exclusion zone "2+3"');

-- Simple approach: Copy all of the reference plants, then delete ones that
-- are excluded by the given exclusion zone.

-- Exclusion zone 2
INSERT INTO generation_plant_scenario_member 
    (generation_plant_scenario_id, generation_plant_id)
SELECT 4, generation_plant_id
    FROM switch.generation_plant_scenario_member
    WHERE generation_plant_scenario_id = 1;

DELETE FROM switch.generation_plant_scenario_member
WHERE generation_plant_scenario_id=4
    AND generation_plant_id IN (
        SELECT generation_plant_id
        FROM public.renewable_energy_exclusion_zones,
            switch.generation_plant
        WHERE ST_Intersects(generation_plant.geom_area, renewable_energy_exclusion_zones.geom)
            AND category = '2'
    );


-- Exclusion zone 2+3
DELETE FROM switch.generation_plant_scenario_member
    WHERE generation_plant_scenario_id=5;

INSERT INTO generation_plant_scenario_member 
    (generation_plant_scenario_id, generation_plant_id)
SELECT 5, generation_plant_id
    FROM switch.generation_plant_scenario_member
    WHERE generation_plant_scenario_id = 1;

DELETE FROM switch.generation_plant_scenario_member
WHERE generation_plant_scenario_id=5
    AND generation_plant_id IN (
        SELECT generation_plant_id
        FROM public.renewable_energy_exclusion_zones,
            switch.generation_plant
        WHERE ST_Intersects(generation_plant.geom_area, renewable_energy_exclusion_zones.geom)
            AND category = '2+3'
    );

-- Reality check
select generation_plant_scenario_id, count(*) 
from generation_plant_scenario_member 
group by 1 
order by 1;
