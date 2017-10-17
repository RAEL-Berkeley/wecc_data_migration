INSERT INTO generation_plant_scenario 
    (generation_plant_scenario_id, name)
VALUES 
    (9, 'AMPL existing plants'),
    (10, 'AMPL proposed plants, non-wind'),
    (11, 'Basecase, env_cat2 wind: AMPL proposed non-wind plants, 2015 Existing Plants Agg update, Env Screen Wind Cat 2'),
    (12, 'Basecase, env_cat3 wind: AMPL proposed non-wind plants, 2015 Existing Plants Agg update, Env Screen Wind Cat 3');

--     (9, 'AMPL existing plants'),
INSERT INTO generation_plant_scenario_member
SELECT 9 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
    JOIN generation_plant USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6 
    AND (generation_plant.name like '%_EP_%' OR generation_plant.gen_tech like 'Hydro_%');

--    (10, 'AMPL proposed plants, non-wind'),
INSERT INTO generation_plant_scenario_member
SELECT 10 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
    JOIN generation_plant USING (generation_plant_id)
WHERE generation_plant_scenario_id = 6 
    AND generation_plant.name not like '%_EP_%'
    AND generation_plant.gen_tech not like 'Hydro_%'
    AND gen_tech != 'Wind';

--    (11, 'Basecase, env_cat2 wind: 2015 Existing Plants Agg update, AMPL proposed non-wind plants, Env Screen Wind Cat 2'),
INSERT INTO generation_plant_scenario_member
SELECT DISTINCT 11 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
WHERE generation_plant_scenario_id IN (3, 10, 7);

--    (12, 'Basecase, env_cat3 wind: 2015 Existing Plants Agg update, AMPL proposed non-wind plants, Env Screen Wind Cat 3');
INSERT INTO generation_plant_scenario_member
SELECT DISTINCT 12 AS generation_plant_scenario_id, generation_plant_id 
FROM generation_plant_scenario_member
WHERE generation_plant_scenario_id IN (3, 10, 8);

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
