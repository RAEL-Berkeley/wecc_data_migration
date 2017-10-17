

INSERT INTO switch.scenario(
            scenario_id, name, description, study_timeframe_id, time_sample_id, 
            demand_scenario_id, fuel_simple_price_scenario_id, generation_plant_scenario_id, 
            generation_plant_cost_scenario_id, generation_plant_existing_and_planned_scenario_id, 
            hydro_simple_scenario_id, carbon_cap_scenario_id, supply_curves_scenario_id, 
            regional_fuel_market_scenario_id, zone_to_regional_fuel_market_scenario_id)
SELECT 
    10 AS scenario_id, 
    'Base toy v0.2.1 env3' AS name, 
    'Base toy scenario, updated gen listings (env cat 3), otherwise like scenario 2' AS description,
    study_timeframe_id, time_sample_id, demand_scenario_id, fuel_simple_price_scenario_id, 
    12 AS generation_plant_scenario_id,
    5 AS generation_plant_cost_scenario_id,
    3 AS generation_plant_existing_and_planned_scenario_id, 
    hydro_simple_scenario_id, carbon_cap_scenario_id, supply_curves_scenario_id, 
    regional_fuel_market_scenario_id, zone_to_regional_fuel_market_scenario_id
  FROM switch.scenario
  WHERE scenario_id=2
UNION
SELECT 
    11 AS scenario_id, 
    'Base toy v0.2.2 env2' AS name, 
    'Base toy scenario, updated gen listings (env cat 2), otherwise like scenario 2' AS description,
    study_timeframe_id, time_sample_id, demand_scenario_id, fuel_simple_price_scenario_id, 
    11 AS generation_plant_scenario_id,
    5 AS generation_plant_cost_scenario_id,
    3 AS generation_plant_existing_and_planned_scenario_id, 
    hydro_simple_scenario_id, carbon_cap_scenario_id, supply_curves_scenario_id, 
    regional_fuel_market_scenario_id, zone_to_regional_fuel_market_scenario_id
  FROM switch.scenario
  WHERE scenario_id=2
UNION
SELECT 
    15 AS scenario_id, 
    'Base AMPL updated v0.2.2 env3' AS name, 
    'Base AMPL scenario, updated gen listings (env cat 3), otherwise like scenario 3' AS description,
    study_timeframe_id, time_sample_id, demand_scenario_id, fuel_simple_price_scenario_id, 
    12 AS generation_plant_scenario_id,
    5 AS generation_plant_cost_scenario_id,
    3 AS generation_plant_existing_and_planned_scenario_id, 
    hydro_simple_scenario_id, carbon_cap_scenario_id, supply_curves_scenario_id, 
    regional_fuel_market_scenario_id, zone_to_regional_fuel_market_scenario_id
  FROM switch.scenario
  WHERE scenario_id=3
UNION
SELECT 
    16 AS scenario_id, 
    'Base AMPL updated v0.2.2 env2' AS name, 
    'Base AMPL scenario, updated gen listings (env cat 2), otherwise like scenario 3' AS description,
    study_timeframe_id, time_sample_id, demand_scenario_id, fuel_simple_price_scenario_id, 
    11 AS generation_plant_scenario_id,
    5 AS generation_plant_cost_scenario_id,
    3 AS generation_plant_existing_and_planned_scenario_id, 
    hydro_simple_scenario_id, carbon_cap_scenario_id, supply_curves_scenario_id, 
    regional_fuel_market_scenario_id, zone_to_regional_fuel_market_scenario_id
  FROM switch.scenario
  WHERE scenario_id=3
;