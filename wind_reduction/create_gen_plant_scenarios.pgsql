INSERT INTO generation_plant_scenario 
    (generation_plant_scenario_id, name)
VALUES 
    (9, 'AMPL existing plants'),
    (10, 'AMPL proposed plants, non-wind'),
    (11, 'Basecase, env_cat2 wind: AMPL proposed non-wind plants, 2015 Existing Plants Agg update, Env Screen Wind Cat 2'),
    (12, 'Basecase, env_cat3 wind: AMPL proposed non-wind plants, 2015 Existing Plants Agg update, Env Screen Wind Cat 3'),
    (13, 'Basecase v0.2.2, env_cat2 wind: AMPL proposed non-wind plants (only the best of solar), 2015 Existing Plants Agg update, Env Screen Wind Cat 2'),
    (14, 'Basecase v0.2.3, env_cat3 wind: AMPL proposed non-wind plants (only the best of solar), 2015 Existing Plants Agg update, Env Screen Wind Cat 3');


--     (9, 'AMPL existing plants'),
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id )
SELECT 9, generation_plant_id
FROM generation_plant_scenario_member
    JOIN generation_plant USING (generation_plant_id)
    JOIN generation_plant_existing_and_planned USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6 
	AND generation_plant_existing_and_planned_scenario_id=1

--    (10, 'AMPL proposed plants, non-wind'),
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id )
SELECT 10 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
    JOIN generation_plant USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6 
    AND generation_plant_id NOT IN (
        SELECT generation_plant_id 
        FROM generation_plant_existing_and_planned 
        WHERE generation_plant_existing_and_planned_scenario_id=1
    )
    AND gen_tech != 'Wind';

--    (11, 'Basecase, env_cat2 wind: 2015 Existing Plants Agg update, AMPL proposed non-wind plants, Env Screen Wind Cat 2'),
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id )
SELECT DISTINCT 11 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
WHERE generation_plant_scenario_id IN (3, 10, 7);

--    (12, 'Basecase, env_cat3 wind: 2015 Existing Plants Agg update, AMPL proposed non-wind plants, Env Screen Wind Cat 3');
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id )
SELECT DISTINCT 12 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
WHERE generation_plant_scenario_id IN (3, 10, 8);

CREATE TEMPORARY TABLE lower_quality_solar_plants AS
    SELECT distinct generation_plant_id
    FROM generation_plant_scenario_member
        JOIN generation_plant USING (generation_plant_id)
    WHERE generation_plant_scenario_id = 6 and 
        generation_plant_id NOT IN (
            SELECT generation_plant_id
            FROM generation_plant_scenario_member
            WHERE generation_plant_scenario_id = 1
        )
        AND energy_source = 'Solar'
    ;
ALTER TABLE lower_quality_solar_plants ADD PRIMARY KEY (generation_plant_id);

--    (13, 'Basecase v0.2.2, env_cat2 wind: AMPL proposed non-wind plants (only the best of solar), 2015 Existing Plants Agg update, Env Screen Wind Cat 2'),
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id )
SELECT DISTINCT 13 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
WHERE generation_plant_scenario_id = 11
    AND generation_plant_id NOT IN (SELECT generation_plant_id FROM lower_quality_solar_plants);

--    (14, 'Basecase v0.2.3, env_cat3 wind: AMPL proposed non-wind plants (only the best of solar), 2015 Existing Plants Agg update, Env Screen Wind Cat 3');
INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id )
SELECT DISTINCT 14 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
WHERE generation_plant_scenario_id = 12
    AND generation_plant_id NOT IN (SELECT generation_plant_id FROM lower_quality_solar_plants);

-- Unify generation plant cost data so each of the above gen plant scenarios can
-- use the same cost scenario.
INSERT INTO generation_plant_cost_scenario
    (generation_plant_cost_scenario_id, name, description)
VALUES (5, 'Basecase unified', 'Merges basecase cost data for plants covered in gen plant cost scenarios 2-4 which each cover different sets of generators. Scenario 1 is a subset of scenario 4, so those generators are also accounted for.');

INSERT INTO generation_plant_cost
    (generation_plant_cost_scenario_id, generation_plant_id, build_year, 
     fixed_o_m, overnight_cost)
SELECT 5 AS generation_plant_cost_scenario_id, 
    generation_plant_id, build_year, fixed_o_m, overnight_cost
  FROM switch.generation_plant_cost
WHERE generation_plant_cost_scenario_id >= 2 AND generation_plant_cost_scenario_id <= 4;

-- --------------------------------------------------------
-- Add best-of-class out-of-California possible wind projects to scenarios 11-14
select switch.generation_plant.gen_tech, generation_plant_scenario.name, 
    (load_zone.name like 'CA\_%') AS ca_load_zone,
    round(sum(capacity_limit_mw)) AS cap_limit_mw_in_CA,
	count(*) AS num_plants
from switch.generation_plant
	JOIN switch.load_zone USING (load_zone_id)
	JOIN generation_plant_scenario_member USING (generation_plant_id)
	JOIN generation_plant_scenario USING (generation_plant_scenario_id)
WHERE  generation_plant_scenario_id IN (1, 6, 11, 12, 13, 14) AND (energy_source='Wind' OR energy_source='Solar')
group by 1, 2, 3
UNION SELECT 'Wind', '2 report', TRUE, 18740, NULL
UNION SELECT 'Wind', '3 report', TRUE, 9531, NULL
UNION SELECT 'Central_PV', '2 report', TRUE, 1028582, NULL
UNION SELECT 'Central_PV', '3 report', TRUE, 357474, NULL
ORDER BY 1, 3, 2
;

CREATE TABLE tmp.non_ca_wind_scenario_entries AS
SELECT generation_plant_scenario.generation_plant_scenario_id, generation_plant_id
FROM switch.generation_plant
	JOIN switch.load_zone USING (load_zone_id)
	JOIN generation_plant_scenario_member USING (generation_plant_id)
	JOIN generation_plant_scenario ON (generation_plant_scenario.generation_plant_scenario_id IN (11, 12, 13, 14))
WHERE generation_plant_scenario_member.generation_plant_scenario_id = 1 
    AND load_zone.name NOT LIKE 'CA\_%'
    AND energy_source = 'Wind'
    AND generation_plant.name NOT LIKE '%\_EP\_%'
;

DELETE FROM tmp.non_ca_wind_scenario_entries e
USING generation_plant_scenario_member s
WHERE e.generation_plant_scenario_id = s.generation_plant_scenario_id
    AND e.generation_plant_id = s.generation_plant_id;

INSERT INTO generation_plant_scenario_member (generation_plant_scenario_id, generation_plant_id)
SELECT generation_plant_scenario_id, generation_plant_id FROM tmp.non_ca_wind_scenario_entries;