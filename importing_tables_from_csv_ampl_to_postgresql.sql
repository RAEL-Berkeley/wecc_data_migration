SET search_path TO switch_wecc_pyomo;

-- Note: all files where located in switch-db2.erg.berkeley.edu
-- psql commands where done from command line
-- \connect switch_wecc2;
-- set search_path  to switch_wecc_pyomo;
-- switch-workstna:switch_wecc_migration_to_python_2017 pehidalg$ rsync -avzr tables_from_mysql switch-db2.erg.berkeley.edu:/var/tmp/home_pehidalg/

---------------------------------------------------------------------------
-- Load zones and balancing areas
---------------------------------------------------------------------------
create table if not exists ampl_load_area_info_v3 (
area_id INT, 
load_area VARCHAR, 
primary_nerc_subregion VARCHAR, -- this is the balancing_area (AMPL name), or reserves_area (python name)
primary_state VARCHAR, 
economic_multiplier_archive DOUBLE PRECISION, 
total_yearly_load_mwh DOUBLE PRECISION, 
local_td_new_annual_payment_per_mw DOUBLE PRECISION,
local_td_sunk_annual_payment DOUBLE PRECISION, 
transmission_sunk_annual_payment DOUBLE PRECISION, 
max_coincident_load_for_local_td DOUBLE PRECISION, 
ccs_distance_km DOUBLE PRECISION, 
rps_compliance_entity VARCHAR,
bio_gas_capacity_limit_mmbtu_per_hour DOUBLE PRECISION, 
nems_fuel_region VARCHAR, 
economic_multiplier DOUBLE PRECISION, 
eia_fuel_region VARCHAR
);

SELECT * FROM ampl_load_area_info_v3;

COPY ampl_load_area_info_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_load_area_info_v3.csv'  
DELIMITER ',' CSV HEADER;

-- [Note from Josiah] data needed: existing_local_td -- ans: ok for now. Revisit sunk costs after first batch of runs
-- [Note] data needs revision: local_td_annual_cost_per_mw, reserves_area. ans: this is ok!
insert into load_zone
select area_id as load_zone_id, load_area as name, 'place holder' as description, ccs_distance_km as ccs_distance_km,
0 as existing_local_td, local_td_new_annual_payment_per_mw as local_td_annual_cost_per_mw, primary_nerc_subregion as reserves_area
from ampl_load_area_info_v3;



create table if not exists ampl_balancing_areas_tab( 
balancing_area VARCHAR, 
load_only_spinning_reserve_requirement DOUBLE PRECISION, 
wind_spinning_reserve_requirement DOUBLE PRECISION,  
solar_spinning_reserve_requirement DOUBLE PRECISION,
quickstart_requirement_relative_to_spinning_reserve_requirement DOUBLE PRECISION
);

-- I imported all gen_costs_scenario_ids (not only id 10 for the basecase) from gen_costs_yearly_v3 
-- so we can generate other overnight costs scenarios
COPY ampl_balancing_areas_tab 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_balancing_areas_tab.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;


create table if not exists balancing_areas( 
balancing_area VARCHAR, 
quickstart_res_load_frac DOUBLE PRECISION, 
quickstart_res_wind_frac DOUBLE PRECISION,  
quickstart_res_solar_frac DOUBLE PRECISION,
spinning_res_load_frac DOUBLE PRECISION,
spinning_res_wind_frac DOUBLE PRECISION,
spinning_res_solar_frac DOUBLE PRECISION
);

-- [Ask Josiah] missing data for quickstart
insert into balancing_areas
select balancing_area, load_only_spinning_reserve_requirement as spinning_res_load_frac, wind_spinning_reserve_requirement as spinning_res_wind_frac, spinning_res_solar_frac as spinning_res_solar_frac
from ampl_balancing_areas_tab;


---------------------------------------------------------------------------
-- Timepoints
---------------------------------------------------------------------------
create table if not exists ampl_study_timepoints (
timepoint_id INT, 
datetime_utc TIMESTAMP, 
month_of_year INT,
day_of_month INT,
hour_of_day INT,
timepoint_year INT,
prior_timepoint_id INT,
next_timepoint_id INT,
PRIMARY KEY (timepoint_id)
);


COPY ampl_study_timepoints 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_study_timepoints.csv'  
DELIMITER ',' CSV HEADER;

-- Divide the raw timeseries from the legacy database into 1-year blocks for convenient sampling.
insert into raw_timeseries 
SELECT timepoint_year - 2010 as raw_timeseries_id,
	1 as hours_per_tp,
	count(*) as num_timepoints,
	min(datetime_utc) as first_timepoint_utc,
	max(datetime_utc) as last_timepoint_utc,
	timepoint_year as start_year,
	timepoint_year as end_year,
	NULL as description
from ampl_study_timepoints 
where timepoint_year >= 2011 and 
	timepoint_year <= 2051 
group by timepoint_year
order by timepoint_year;

insert into raw_timepoint
select timepoint_id as raw_timepoint_id, 
	timepoint_year - 2010 as raw_timeseries_id, 
	datetime_utc as timestamp_utc
from ampl_study_timepoints
where timepoint_year >= 2011 and timepoint_year <= 2051 
order by raw_timepoint_id;


---------------------------------------------------------------------------
-- Demand
---------------------------------------------------------------------------
-- Note: I only imported load_scenario_id = 21
create table if not exists ampl__load_projections (
load_scenario_id INT, 
area_id INT, 
timepoint_id INT,
future_year INT,
historic_hour INT,
power DOUBLE PRECISION,
PRIMARY KEY (load_scenario_id, area_id, timepoint_id)
);

COPY ampl__load_projections 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl__load_projections.csv'  
DELIMITER ',' CSV HEADER;

insert into demand_scenario values (21, 'ampl basecase','base scenario from ampl runs');

-- The query below gave all 17519984 timpoints with demand (same as timepoints in 
-- ampl__load_projections, so it's correct)
insert into demand_timeseries
select area_id as load_zone_id, load_scenario_id as demand_scenario_id, timepoint_id as raw_timepoint_id,
name as  load_zone_name, datetime_utc as timestamp_utc, power as demand_mw
from ampl__load_projections join load_zone on (load_zone_id=area_id) join ampl_study_timepoints using (timepoint_id);

-- Notes about demand_timeseries and raw_timepoint: some load_zones have one timepoint less than others in demand_timeseries


---------------------------------------------------------------------------
-- Energy sources
---------------------------------------------------------------------------

create table if not exists ampl_fuel_info_v2 (
fuel VARCHAR, 
rps_fuel_category VARCHAR, 
biofuel INT,
carbon_content DOUBLE PRECISION,
carbon_content_without_carbon_accounting DOUBLE PRECISION,
carbon_sequestered DOUBLE PRECISION
);

COPY ampl_fuel_info_v2 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_fuel_info_v2.csv'  
DELIMITER ',' CSV HEADER;

create table if not exists ampl_fuel_info_v2_adapted (
fuel VARCHAR, 
carbon_content DOUBLE PRECISION,
is_fuel INT
);

COPY ampl_fuel_info_v2_adapted 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_fuel_info_v2_adapted.csv'  
DELIMITER ',' CSV HEADER;


-- Note about energy_source: I did not include CCS for simplicity for now.
-- [Ask Josiah] about co2_intensity of biomass. CO2 is sequestered when bio is growing, but then emitted when bio is burnt.
-- Does it even out? ans: all good
INSERT INTO energy_source
select fuel as name, cast (is_fuel as boolean) as is_fuel, carbon_content as co2_intensity, 0 as upstream_co2_intensity
from ampl_fuel_info_v2_adapted;

-- edit to be coherent with Josiah's example:
delete from energy_source where name = 'Storage';
insert into energy_source values ('Electricity', FALSE, 0, 0);


---------------------------------------------------------------------------
-- Generation plants
---------------------------------------------------------------------------

create table if not exists ampl_gen_info_scenario_v3(
technology VARCHAR, 
technology_id INT, 
min_online_year INT, 
fuel VARCHAR, 
construction_time_years INT, 
year_1_cost_fraction DOUBLE PRECISION, 
year_2_cost_fraction DOUBLE PRECISION, 
year_3_cost_fraction DOUBLE PRECISION, 
year_4_cost_fraction DOUBLE PRECISION, 
year_5_cost_fraction DOUBLE PRECISION, 
year_6_cost_fraction DOUBLE PRECISION, 
max_age_years INT, 
forced_outage_rate DOUBLE PRECISION, 
scheduled_outage_rate DOUBLE PRECISION, 
can_build_new INT, 
ccs INT, 
intermittent INT, 
resource_limited INT, 
baseload INT, 
flexible_baseload INT, 
dispatchable INT, 
cogen INT, 
min_build_capacity DOUBLE PRECISION, 
competes_for_space INT, 
storage INT, 
storage_efficiency DOUBLE PRECISION, 
max_store_rate DOUBLE PRECISION, 
max_spinning_reserve_fraction_of_capacity DOUBLE PRECISION, 
heat_rate_penalty_spinning_reserve DOUBLE PRECISION, 
minimum_loading DOUBLE PRECISION, 
deep_cycling_penalty DOUBLE PRECISION, 
startup_mmbtu_per_mw DOUBLE PRECISION, 
startup_cost_dollars_per_mw  DOUBLE PRECISION
);


-- I only copied gen_info_scenario_id=13 is AMPL base case with no ccs
COPY ampl_gen_info_scenario_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_gen_info_scenario_v3.csv'  
DELIMITER ',' CSV HEADER;


-- Note: all in US$2016 (as the rest of the tables from AMPL)
create table if not exists ampl_generator_costs_tab( 
technology VARCHAR, 
year INT,
overnight_cost DOUBLE PRECISION,
storage_energy_capacity_cpst_per_mw  DOUBLE PRECISION,
fixed_o_m DOUBLE PRECISION,
variable_o_m_by_year DOUBLE PRECISION 
);

-- I only copied gen_info_scenario_id=13 is AMPL base case with no ccs and gen_costs_scenario_id=10 
COPY ampl_generator_costs_tab 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_generator_costs_tab.csv'  
DELIMITER ',' CSV HEADER;


create table if not exists ampl_existing_plants_v3(
project_id INT,
load_area VARCHAR, 
technology VARCHAR, 
plant_name VARCHAR, 
eia_id INT, 
capacity_mw DOUBLE PRECISION, 
heat_rate DOUBLE PRECISION, 
cogen_thermal_demand_mmbtus_per_mwh DOUBLE PRECISION, 
start_year INT, 
forced_retirement_year INT, 
overnight_cost DOUBLE PRECISION, 
connect_cost_per_mw DOUBLE PRECISION, 
fixed_o_m DOUBLE PRECISION, 
variable_o_m  DOUBLE PRECISION
);

COPY ampl_existing_plants_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_existing_plants_v3.csv'  
DELIMITER ',' CSV HEADER;

-- Note: all in US$2016 (as the rest of the tables from AMPL)
create table if not exists ampl_proposed_projects_tab( 
project_id INT, 
load_area VARCHAR, 
technology VARCHAR,
location_id INT,
ep_project_replacement_id INT,
capacity_limit DOUBLE PRECISION,
capacity_limit_conversion DOUBLE PRECISION,
heat_rate DOUBLE PRECISION, 
cogen_thermal_demand DOUBLE PRECISION,
connect_cost_per_mw DOUBLE PRECISION,
average_capacity_factor_intermittent  DOUBLE PRECISION 
);

COPY ampl_proposed_projects_tab 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_proposed_projects_tab.csv'  
DELIMITER ',' CSV HEADER;

-- Populating generation_plant table:

-- Is it ok if I leave technology with _EP for the exiting ones? ok
-- capacity_limit column in generation_plant table, for now it's blank for exiting plants. ok
-- t.heat_rate as full_load_heat_rate. ok
-- hydro_efficiency is blank for now. This is used for benjamin's extension/hydro module 
--  unit_size is blank
--  store_to_release_ratio = max_store_rate 
-- minimum_loading as min_load_fraction ANS: only for thermal plants!! OR FINE TO LEAVE BLANK
-- startup_fuel as startup_mmbtu_per_mw ANS OK
-- startup_om as startup_cost_dollars_per_mw ANS OK
-- Note: ccs_capture_efficiency and ccs_energy_load (ratio gross energy that goes to CCS equipment) are left blank for now
-- There are 1920 existing plants, and 7412 proposed plants
-- Changed 'Storage' for 'Electricity' to be consistent with Josiah's switch_pyomo convention

-- Inserting existing generators
insert into generation_plant (generation_plant_id, name, gen_tech, load_zone_id, connect_cost_per_mw, variable_o_m,
forced_outage_rate, scheduled_outage_rate, full_load_heat_rate, max_age, min_build_capacity, is_variable, is_baseload,
is_cogen, energy_source, store_to_release_ratio, storage_efficiency, min_load_fraction, startup_fuel, startup_om)
select t.project_id as generation_plant_id, t.plant_name as name, t.technology as gen_tech, 
t1.load_zone_id as load_zone_id, t.connect_cost_per_mw as connect_cost_per_mw, -- as capacity_limit,
t.variable_o_m as variable_o_m, t2.forced_outage_rate as forced_outage_rate, 
t2.scheduled_outage_rate as scheduled_outage_rate, t.heat_rate as full_load_heat_rate, t2.max_age_years as max_age,
t2.min_build_capacity as min_build_capacity, cast(t2.intermittent as boolean) as is_variable, 
cast(t2.baseload as boolean) as is_baseload, cast(t2.cogen as boolean) as is_cogen, 
(CASE WHEN t2.fuel= 'Storage' THEN 'Electricity' ELSE t2.fuel END) as energy_source, 
t2.max_store_rate as store_to_release_ratio,
t2.storage_efficiency as storage_efficiency, t2.minimum_loading as min_load_fraction,
t2.startup_mmbtu_per_mw as startup_fuel, t2.startup_cost_dollars_per_mw as startup_om
from ampl_existing_plants_v3 as t join load_zone as t1 on(name = load_area) 
				   join ampl_gen_info_scenario_v3 as t2 using(technology);
				   
				   
-- Inserting proposed generators
-- I filtered by year 2010 so each project wouldn't be repeated 41 times because the table ampl_generator_costs_tab
-- for each project it has the overnight_cost for each year, so it was gereating duplication of rows.
-- [Ask Josiah] For which year should variable_o_m be used here? "base year"?
insert into generation_plant (generation_plant_id, name, gen_tech, load_zone_id, connect_cost_per_mw, capacity_limit_mw, 
variable_o_m,
forced_outage_rate, scheduled_outage_rate, full_load_heat_rate, max_age, min_build_capacity, is_variable, is_baseload,
is_cogen, energy_source, store_to_release_ratio, storage_efficiency, min_load_fraction, startup_fuel, startup_om)
select t.project_id as generation_plant_id, 'Proposed' as name, t.technology as gen_tech, 
t1.load_zone_id as load_zone_id, t.connect_cost_per_mw as connect_cost_per_mw, t.capacity_limit as capacity_limit_mw,
t3.variable_o_m_by_year as variable_o_m, t2.forced_outage_rate as forced_outage_rate, 
t2.scheduled_outage_rate as scheduled_outage_rate, t.heat_rate as full_load_heat_rate, t2.max_age_years as max_age,
t2.min_build_capacity as min_build_capacity, cast(t2.intermittent as boolean) as is_variable, 
cast(t2.baseload as boolean) as is_baseload, cast(t2.cogen as boolean) as is_cogen, 
(CASE WHEN t2.fuel= 'Storage' THEN 'Electricity' ELSE t2.fuel END) as energy_source, 
t2.max_store_rate as store_to_release_ratio,
t2.storage_efficiency as storage_efficiency, t2.minimum_loading as min_load_fraction,
t2.startup_mmbtu_per_mw as startup_fuel, t2.startup_cost_dollars_per_mw as startup_om
from ampl_proposed_projects_tab as t join load_zone as t1 on(name = load_area) 
				   join ampl_gen_info_scenario_v3 as t2 using(technology)
				   join ampl_generator_costs_tab as t3 using(technology)
				   where year = 2010;	

insert into generation_plant_scenario
select 1, 'Basecase from SWITCH AMPL', 'Basecase of power plants used in SWITCH AMPL. 1920 existing generators and 7412 proposed generators';

-- inserting all 9332 (= 1920 + 7412) generators in scenario 1
insert into generation_plant_scenario_member
select 1 as generation_plant_scenario_id, generation_plant_id from generation_plant; -- 9332


---------------------------------------------------------------------------
-- [Pending] Generation plant costs (overnight, fuel, o_m)
---------------------------------------------------------------------------

insert into generation_plant_cost_scenario
select 1 as generation_plant_cost_scenario_id, 'Basecase from SWITCH AMPL' as name, 
'gen_costs_scenario_id = 10 in mySQL table generator_costs_yearly_v3' as description;


create table if not exists ampl_generator_costs_yearly_v3( 
gen_costs_scenario_id INT, 
technology VARCHAR, 
year INT,  
overnight_cost DOUBLE PRECISION,
fixed_o_m float,
var_o_m float,
storage_energy_capacity_cost_per_mwh float,
notes VARCHAR(300),
primary key(gen_costs_scenario_id, technology, year)
);

-- I imported all gen_costs_scenario_ids (not only id 10 for the basecase) from gen_costs_yearly_v3 
-- so we can generate other overnight costs scenarios
COPY ampl_generator_costs_yearly_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_generator_costs_yearly_v3.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;




-- this query gives 303892 rows (303892 rows / 7412 proposed projects = 41 years of costs per project.)
-- [Pending][Ask Josiah][run query below] Should I just edit the name of the existing technologies, so they appear easily in this table?
-- ans: edit _EP
-- insert into generation_plant_cost
-- select 1 as generation_plant_cost_scenario_id, generation_plant_id, year as build_year, fixed_o_m, overnight_cost
-- from ampl_generator_costs_yearly_v3 
-- join generation_plant t on (gen_tech=technology)
-- where gen_costs_scenario_id = 10;


---------------------------------------------------------------------------
-- Generation plant existing and planned
---------------------------------------------------------------------------

insert into generation_plant_existing_and_planned_scenario
select 1 as generation_plant_existing_and_planned_scenario_id, 'Basecase from SWITCH AMPL' as name,
 'Existing generators from SWITCH AMPL basecase. (No update from Josiahs and Benjamins work)' as description;


insert into generation_plant_existing_and_planned
select 1 as generation_plant_existing_and_planned_scenario_id,
project_id as generation_plant_id, 
(case when start_year = 0 then 1900 else start_year end) as build_year, 
 capacity_mw as capacity
from ampl_existing_plants_v3 
order by 1, 2, 3;






---------------------------------------------------------------------------
-- [Pending] Variable capacity factors
---------------------------------------------------------------------------



create table if not exists ampl_existing_intermittent_plant_cap_factor( 
project_id INT, 
load_area VARCHAR, 
technology VARCHAR, 
timepoint_id INT, 
hour INT, 
cap_factor DOUBLE PRECISION
);

COPY ampl_existing_intermittent_plant_cap_factor 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_existing_intermittent_plant_cap_factor.csv'  
DELIMITER ',' CSV HEADER;

alter table ampl_existing_intermittent_plant_cap_factor add primary key (project_id, timepoint_id);


-- Plan A:
---------------------------------------------------------------------------
-- Probably delete this section and table ampl_cap_factor

-- [Delete] If I don't proceed with Plan A, delete this table:
create table if not exists ampl_cap_factor( 
project_id INT, 
load_area VARCHAR, 
technology VARCHAR, 
timepoint_id INT, 
hour INT, 
cap_factor DOUBLE PRECISION
);

-- Plan A. Its is running anyway, but I proceeded with plan B
-- [Pending] waiting for the query to finish exporting the .csv on 
-- afp://xserve-rael.erg.berkeley.edu/switch/Users/pehidalg/SWITCH_WECC/Migration_from_AMPL_to_Python/

-- continue executing here:

--COPY ampl_cap_factor 
--FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_cap_factor.csv'  
--DELIMITER ',' CSV HEADER;

--alter table ampl_existing_intermittent_plant_cap_factor add primary key (project_id, timepoint_id);

---------------------------------------------------------------------------


-- Plan B:

create table if not exists ampl__cap_factor_intermittent_sites_v2( 
project_id INT, 
hour INT, 
cap_factor DOUBLE PRECISION,
PRIMARY KEY (project_id, hour)
);

COPY ampl__cap_factor_intermittent_sites_v2 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl__cap_factor_intermittent_sites_v2.csv'  
DELIMITER ',' CSV HEADER;


create table if not exists ampl_load_scenario_historic_timepoints( 
load_scenario_id INT, 
timepoint_id INT, 
historic_hour SMALLINT,
PRIMARY KEY (load_scenario_id, timepoint_id)
);

COPY ampl_load_scenario_historic_timepoints 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_load_scenario_historic_timepoints.csv'  
DELIMITER ',' CSV HEADER;


create table if not exists ampl__proposed_projects_v3( 
project_id int,
gen_info_project_id int,
technology_id smallint,
area_id smallint,
location_id INT,
ep_project_replacement_id INT,
technology varchar(64),
original_dataset_id int,
capacity_limit FLOAT,
capacity_limit_conversion FLOAT,
connect_cost_per_mw float,
heat_rate float, 
cogen_thermal_demand float,
avg_cap_factor_intermittent FLOAT,
stddev_cap_factor_intermittent float,
avg_cap_factor_percentile_by_intermittent_tech float,
cumulative_avg_MW_tech_load_area float,
rank_by_tech_in_load_area int,
primary key(gen_info_project_id)
);

COPY ampl__proposed_projects_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl__proposed_projects_v3.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;


create table if not exists ampl__cap_factor_csp_6h_storage_adjusted( 
project_id int,
hour int,
cap_factor_adjusted float,
primary key(project_id, hour)
);

COPY ampl__cap_factor_csp_6h_storage_adjusted 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl__cap_factor_csp_6h_storage_adjusted.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;


-- [Pending][Ask Josiah] choose subset of timepoints to insert in variable_capacity_factors
-- insert into intermediate table for variable_capacity_factors
select project_id, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, datetime_utc, cap_factor  
  FROM ampl_study_timepoints 
    JOIN ampl_load_scenario_historic_timepoints USING(timepoint_id)
    JOIN ampl__cap_factor_intermittent_sites_v2 ON(historic_hour=hour)
    JOIN ampl__proposed_projects_v3 USING(project_id)
    JOIN ampl_load_area_info_v3 USING(area_id)
  WHERE load_scenario_id=21 
    AND (( avg_cap_factor_percentile_by_intermittent_tech >= 0.75 or cumulative_avg_MW_tech_load_area <= 3 * total_yearly_load_mwh / 8766 or rank_by_tech_in_load_area <= 5 or avg_cap_factor_percentile_by_intermittent_tech is null) and technology <> 'Concentrating_PV') 
    AND technology_id <> 7 
UNION 
select project_id, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, datetime_utc, cap_factor_adjusted as cap_factor  
  FROM ampl_study_timepoints 
    JOIN ampl_load_scenario_historic_timepoints USING(timepoint_id)
    JOIN ampl__cap_factor_csp_6h_storage_adjusted ON(historic_hour=hour)
    JOIN ampl__proposed_projects_v3 USING(project_id)
    JOIN ampl_load_area_info_v3 USING(area_id)
  WHERE load_scenario_id=21 
    AND (( avg_cap_factor_percentile_by_intermittent_tech >= 0.75 or cumulative_avg_MW_tech_load_area <= 3 * total_yearly_load_mwh / 8766 or rank_by_tech_in_load_area <= 5 or avg_cap_factor_percentile_by_intermittent_tech is null) and technology <> 'Concentrating_PV') 
    AND technology_id = 7;



---------------------------------------------------------------------------
-- Transmission lines
---------------------------------------------------------------------------

create table if not exists ampl_transmission_lines_tab( 
load_area_start VARCHAR, 
load_area_end VARCHAR, 
existing_transfer_capacity_mw DOUBLE PRECISION, 
transmission_line_id INT, 
transmission_length_km DOUBLE PRECISION, 
transmission_efficiency DOUBLE PRECISION, 
new_transmission_builds_allowed INT, 
is_dc_line INT, 
transmission_derating_factor DOUBLE PRECISION, 
terrain_multiplier DOUBLE PRECISION, 
primary key(transmission_line_id)
);

COPY ampl_transmission_lines_tab 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_transmission_lines_tab.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;


insert into transmission_lines
select transmission_line_id, t.load_zone_id as start_load_zone_id, t2.load_zone_id as end_load_zone_id, 
transmission_length_km as trans_length_km,
transmission_efficiency as trans_efficiency, existing_transfer_capacity_mw as existing_trans_cap_mw,
new_transmission_builds_allowed as new_build_allowed, transmission_derating_factor as derating_factor, 
terrain_multiplier as  terrain_multiplier
from ampl_transmission_lines_tab
left join (select name, load_zone_id from load_zone) as t on t.name = load_area_start
left join (select name, load_zone_id from load_zone) as t2 on t2.name = load_area_end
order by 2,3;

---------------------------------------------------------------------------
-- [Pending] Fuel prices
---------------------------------------------------------------------------

create table if not exists ampl_fuel_prices_v3( 
fuel_scenario_id int,
area_id int,
load_area varchar,
fuel VARCHAR,
year int,
fuel_price double PRECISION,
notes VARCHAR(300),
eai_region VARCHAR,
primary key(fuel_scenario_id, load_area, fuel, year)
);

COPY ampl_fuel_prices_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_fuel_prices_v3.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

-- Table with fuel prices for all years. The idea is to join this table with the table with periods, 
-- to generate the table fuel_simple_price.
create table if not exists fuel_simple_price_yearly(
fuel_simple_scenario_id int,
load_zone_id int,
load_zone_name varchar,
fuel VARCHAR,
projection_year int,
fuel_price double PRECISION,
notes VARCHAR(300),
eai_region VARCHAR,
primary key(fuel_simple_scenario_id, load_zone_id, fuel, projection_year)
);


insert into fuel_simple_price_yearly
select 1 as fuel_simple_scenario_id, area_id as load_zone_id, load_area as load_zone_name, fuel, 
year as projection_year, fuel_price, notes, eai_region
from ampl_fuel_prices_v3;

update fuel_simple_price_yearly set fuel = 'Electricity' where fuel = 'Storage';


-- [Pending][Ask Josiah] insert into fuel_simple_price by joining with table with period_id
-- insert into fuel_simple_price
--

-- [Pending][To-do] Include NaturalGas prices from tables in MySQL (EIA 2017)
-- [Pending][To-do][Ask Josiah] Decide what to do with biomass prices. Maybe use supply MySQL/AMPL curves?
-- ans: use supply curve

insert into fuel_simple_price_scenario
select 1 as fuel_simple_scenario_id, 'Basecase from SWITCH AMPL' as name, 
'Fuel prices from SWITCH AMPL. Note Gas and Biomass. EIA energy outlook 2017 for Coal(_CCS), DistillateFuelOil(_CCS), ResidualFuelOil(_CCS), and Uranium. The price for the other fuels are from old data from _fuel_prices table (schema switch_inputs_wecc_v2_2) in mySQL' as description; 


---------------------------------------------------------------------------
-- [Pending] Hydropower
---------------------------------------------------------------------------

insert into hydro_simple_scenario
select 1 as hydro_simple_scenario_id, 'Basecase from SWITCH AMPL' as name, 'Basecase from SWITCH AMPL' as description;


create table if not exists ampl_hydro_monthly_limits_v2( 
project_id int,
load_zone varchar,
technology VARCHAR,
month int,
avg_capacity_factor_hydro double PRECISION,
primary key(project_id, month)
);

COPY ampl_hydro_monthly_limits_v2 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_hydro_monthly_limits_v2.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

-- [Pending] insert into hydro_flow_data
-- It requires sampled_timeseries_id


---------------------------------------------------------------------------
-- [Pending] Scenarios
---------------------------------------------------------------------------









