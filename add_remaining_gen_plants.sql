-- Copy over remaining plants
-- * Select all plants that need copying into semi-temporary table
-- * Insert into generation_plants
-- * Create new gen plant scenario
-- * Insert costs
-- * Insert renewable capacity factors hourly timeseries # Ask Paty for help?
-- * Insert geolocations # To Do..
-- Other script: Create new gen plant scenario based on Grace's allowed land maps

-- * Select all plants that need copying into semi-temporary table
create table insert_projects from
select project_id from ampl__proposed_projects_v3
    where project_id not in (select project_id from ampl_proposed_projects_tab);
ALTER TABLE insert_projects ADD CONSTRAINT insert_projects_primary_key 
    PRIMARY KEY (project_id);

-- * Insert into generation_plants
insert into generation_plant (
    generation_plant_id, name, gen_tech, load_zone_id,connect_cost_per_mw,
    capacity_limit_mw, variable_o_m, forced_outage_rate,
    scheduled_outage_rate, full_load_heat_rate, max_age, min_build_capacity,
    is_variable, is_baseload, is_cogen, energy_source, store_to_release_ratio,
    storage_efficiency, min_load_fraction, startup_fuel, startup_om)
select 
    t.project_id as generation_plant_id, 
    'Proposed' as name, 
    t.technology as gen_tech, 
    t1.load_zone_id as load_zone_id, 
    t.connect_cost_per_mw as connect_cost_per_mw,
    t.capacity_limit as capacity_limit_mw,
    t3.variable_o_m_by_year as variable_o_m, 
    t2.forced_outage_rate as forced_outage_rate, 
    t2.scheduled_outage_rate as scheduled_outage_rate, 
    t.heat_rate as full_load_heat_rate, 
    t2.max_age_years as max_age,
    t2.min_build_capacity as min_build_capacity, 
    cast(t2.intermittent as boolean) as is_variable, 
    cast(t2.baseload as boolean) as is_baseload, 
    cast(t2.cogen as boolean) as is_cogen, 
    (CASE WHEN t2.fuel= 'Storage' THEN 'Electricity' ELSE t2.fuel END) as energy_source, 
    t2.max_store_rate as store_to_release_ratio,
    t2.storage_efficiency as storage_efficiency, 
    t2.minimum_loading as min_load_fraction,
    t2.startup_mmbtu_per_mw as startup_fuel, 
    t2.startup_cost_dollars_per_mw as startup_om
from ampl__proposed_projects_v3 as t 
    join insert_projects USING (project_id)
    join load_zone as t1 on(area_id=load_zone_id) 
    join ampl_gen_info_scenario_v3 as t2 using(technology)
    join ampl_generator_costs_tab as t3 using(technology)
where year = 2010 
    and project_id not in (select generation_plant_id from generation_plant)
;

-- * Create new gen plant scenario
insert into generation_plant_scenario
select 6, 'Basecase v2 from SWITCH AMPL', 'Basecase of all power plants used in SWITCH AMPL. 1920 existing generators and 7412 proposed generators';

-- inserting all 19085 (= 9332 + 9753) generators in scenario 6; All of scenario 1 plus the lower-resource-quality sites.
insert into generation_plant_scenario_member
select 6 as generation_plant_scenario_id, generation_plant_id 
    from generation_plant_scenario_member
    WHERE generation_plant_scenario_id = 1
UNION
select 6 as generation_plant_scenario_id, project_id as generation_plant_id 
    from insert_projects JOIN generation_plant ON(generation_plant_id=project_id)
;

-- * Insert into costs
insert into generation_plant_cost_scenario
select 4 as generation_plant_cost_scenario_id, 
    'Basecase all from SWITCH AMPL' as name, 
    'gen_costs_scenario_id = 10 in mySQL table generator_costs_yearly_v3' as description;

insert into generation_plant_cost
select 4 as generation_plant_cost_scenario_id, generation_plant_id, year as build_year, fixed_o_m, overnight_cost
from ampl_generator_costs_yearly_v3 
    join generation_plant t on (gen_tech=technology)
	JOIN generation_plant_scenario_member USING(generation_plant_id)
where gen_costs_scenario_id = 10
    AND generation_plant_scenario_id = 6;


-- * Insert renewable capacity factors hourly timeseries
-- Uh, the importin'g_tables_from_cvs_ampl... was messy on the variable cap factor part. Maybe ask Paty to do that? Or... pull the raw table from ampl and fill in the blanks.

-- * Insert geolocations # To Do..
-- Other script: Create new gen plant scenario based on Grace's allowed land maps
