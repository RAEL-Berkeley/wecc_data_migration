-- Adding wave energy

insert into switch.energy_source
values ('Wave', false, 0, 0);

SELECT * FROM switch.energy_source ;	


insert into generation_plant (generation_plant_id, name, gen_tech, load_zone_id, connect_cost_per_mw, variable_o_m,
	forced_outage_rate, scheduled_outage_rate, max_age, min_build_capacity, is_variable, is_baseload,
	is_cogen, energy_source,  min_load_fraction, startup_fuel, startup_om)
select 
t1."GENERATION_PROJECT" as generation_plant_id, concat(t1."GENERATION_PROJECT", '_Wave') as name, gen_tech, load_zone_id, gen_connect_cost_per_mw as connect_cost_per_mw,
gen_variable_om as variable_o_m, gen_forced_outage_rate as forced_outage_rate, gen_scheduled_outage_rate as scheduled_outage_rate, 
gen_max_age as max_age, gen_min_build_capacity as min_build_capacity, gen_is_variable as is_variable, gen_is_baseload as is_baseload, gen_is_cogen as is_cogen,
gen_energy_source as energy_source, 0 as min_load_fraction, 0 as startup_fuel, 0 as startup_om
from public.generation_projects_info_wave as t1
join load_zone as t2 on(t2.name=gen_load_zone);

insert into generation_plant_cost_scenario
values (9, 'Basecase unified, updated solar+others, wave energy', 'Same generators as Basecase unified (gen plant cost scenario id 6) but including wave energy. Updated overnight cost for solar (E3), 4% decrease til 2030 and then 1%, geothermal, and offshore_wind');


insert into generation_plant_cost
select 9 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost,
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
where generation_plant_cost_scenario_id = 6
union
select 9 as generation_plant_cost_scenario_id, t."GENERATION_PROJECT" as generation_plant_id,
build_year, gen_fixed_om as fixed_o_m, gen_overnight_cost as  overnight_cost, 
NULL as storage_energy_capacity_cost_per_mwh
from public.gen_build_costs_wave as t;