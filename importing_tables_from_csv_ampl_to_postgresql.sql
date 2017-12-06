﻿SET search_path TO switch;

-- Note: all files where located in switch-db2.erg.berkeley.edu
-- psql commands where done from command line
-- \connect switch_wecc;
-- set search_path  to switch;
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
select area_id as load_zone_id, load_area as name, NULL as description, ccs_distance_km as ccs_distance_km,
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
select balancing_area, load_only_spinning_reserve_requirement as spinning_res_load_frac, wind_spinning_reserve_requirement as spinning_res_wind_frac, solar_spinning_reserve_requirement as spinning_res_solar_frac
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
where timepoint_year >= 2011
group by timepoint_year
order by timepoint_year;

insert into raw_timepoint
select timepoint_id as raw_timepoint_id, 
	timepoint_year - 2010 as raw_timeseries_id, 
	datetime_utc as timestamp_utc
from ampl_study_timepoints
where timepoint_year >= 2011
order by raw_timepoint_id;

-- Add 2006 historical timeseries.
INSERT INTO raw_timeseries 
SELECT 2006 as raw_timeseries_id,
	1 as hours_per_tp,
	8760 as num_timepoints,
	'2006-01-01 00:00'::timestamp as first_timepoint_utc,
	'2006-12-31 23:00'::timestamp as last_timepoint_utc,
	2006 as start_year,
	2006 as end_year,
	NULL as description
;

insert into raw_timepoint (raw_timeseries_id, timestamp_utc)
select raw_timeseries_id, generate_series as timestamp_utc
from raw_timeseries,
    generate_series('2006-01-01 00:00'::timestamp, 
                    '2006-12-31 23:00', '1 hours')
where raw_timeseries.raw_timeseries_id = 2006;

INSERT INTO projection_to_future_timepoint 
    (historical_timepoint_id, future_timepoint_id)
    SELECT past.raw_timepoint_id as historical_timepoint_id,
        future.raw_timepoint_id as future_timepoint_id
--        , past.timestamp_utc, future.timestamp_utc
    FROM raw_timepoint future, raw_timepoint past
    WHERE future.timestamp_utc >= '2007-01-01 00:00'::timestamp
	and extract( 'year' from past.timestamp_utc) = 2006
        and past.timestamp_utc = future.timestamp_utc - interval '1 year' * (
            extract( 'year' from future.timestamp_utc)-2006);

alter table sampled_timepoint drop CONSTRAINT sampled_timepoint_pkey;
alter table sampled_timepoint add primary key (raw_timepoint_id, study_timeframe_id);


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
UPDATE ampl_gen_info_scenario_v3 
SET max_age_years=200
WHERE fuel='Water'
;

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

CREATE TABLE generation_plant_vintage_cost ( like ampl_existing_plants_v3 );

insert into generation_plant_vintage_cost
select * from ampl_existing_plants_v3;

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

\COPY ampl_proposed_projects_tab FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_proposed_projects_tab.csv' DELIMITER ',' NULL AS 'NULL' CSV HEADER;

-- Populating generation_plant table:

-- Is it ok if I leave technology with _EP for the exiting ones? I decided to delete _EP so it's easier to put data etc.
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
from ampl_existing_plants_v3 as t 
join load_zone as t1 on(name = load_area) 
join ampl_gen_info_scenario_v3 as t2 using(technology);

-- Editing so _EP is deleted from gen_tech names.
update generation_plant set gen_tech = trim(trailing '_EP' from gen_tech);
				   
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

update generation_plant 


-- While geothermal plants can technically have a heat rate in reality, they don't have one in
-- our model which treats geothermal plants as baseload with a zero cost for input heat.
UPDATE generation_plant
SET full_load_heat_rate=NULL
WHERE gen_tech='Geothermal';

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




-- this query gives 338701 rows (303892 rows / 9332 projects = 36 years of costs per project.)
-- we might have to check this because the number of years was 36 instead of 41. Some "existing" 
-- projects might have not gotten costs if their technology name (without _EP) did not exist in ampl_generator_costs_yearly_v3
insert into generation_plant_cost (
    generation_plant_cost_scenario_id, generation_plant_id, build_year, 
    fixed_o_m, overnight_cost, storage_energy_capacity_cost_per_mwh)
select 1 as generation_plant_cost_scenario_id, generation_plant_id, year as build_year, 
    fixed_o_m, overnight_cost,
    (CASE when storage_energy_capacity_cost_per_mwh=0 THEN NULL 
    ELSE storage_energy_capacity_cost_per_mwh END) as storage_energy_capacity_cost_per_mwh
from ampl_generator_costs_yearly_v3 
join generation_plant t on (gen_tech=technology)
where gen_costs_scenario_id = 10;

-- Add vintage costs for existing plants too. The only storage included in this
-- set is Hydro_Pumped, so set its storage_energy_capacity_cost_per_mwh to 0 
-- and the rest of the records to NULL
INSERT INTO generation_plant_cost (
    generation_plant_cost_scenario_id, generation_plant_id, build_year, 
    fixed_o_m, overnight_cost, storage_energy_capacity_cost_per_mwh)
SELECT 1 AS generation_plant_cost_scenario_id, 
    project_id AS generation_plant_id, 
    start_year AS build_year, 
    fixed_o_m, overnight_cost,
    (CASE when technology='Hydro_Pumped' THEN 0 
     ELSE NULL END) as storage_energy_capacity_cost_per_mwh 
FROM ampl_existing_plants_v3;

-- Scrub out projected future costs for existing plants.
DELETE FROM generation_plant_cost
WHERE generation_plant_cost_scenario_id = 1
    AND generation_plant_id IN (SELECT project_id FROM ampl_existing_plants_v3)
    AND build_year != (SELECT start_year FROM ampl_existing_plants_v3 WHERE project_id = generation_plant_id);

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
-- Variable capacity factors
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
--create table if not exists ampl_cap_factor( 
--project_id INT, 
--load_area VARCHAR, 
--technology VARCHAR, 
--timepoint_id INT, 
--hour INT, 
--cap_factor DOUBLE PRECISION
--);

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

-- Temporary solution to create capacity factors table -----

-- Copying tables from ampl into temporary tables that we can use in get_switch_input_tables

CREATE TABLE temp_load_scenario_historic_timepoints ( like ampl_load_scenario_historic_timepoints );

insert into temp_load_scenario_historic_timepoints
select * from ampl_load_scenario_historic_timepoints;

CREATE TABLE temp_ampl_study_timepoints ( like ampl_study_timepoints );

insert into temp_ampl_study_timepoints
select * from ampl_study_timepoints;

CREATE TABLE temp_variable_capacity_factors_historical ( like ampl__cap_factor_intermittent_sites_v2 );

insert into temp_variable_capacity_factors_historical
select * from ampl__cap_factor_intermittent_sites_v2;

CREATE TABLE temp_ampl__proposed_projects_v3 ( like ampl__proposed_projects_v3 );

insert into temp_ampl__proposed_projects_v3
select * from ampl__proposed_projects_v3;

CREATE TABLE temp_ampl_load_area_info_v3 ( like ampl_load_area_info_v3 );

insert into temp_ampl_load_area_info_v3
select * from ampl_load_area_info_v3;

CREATE TABLE temp_variable_capacity_factors_historical_csp ( like ampl__cap_factor_csp_6h_storage_adjusted );

insert into temp_variable_capacity_factors_historical_csp
select * from ampl__cap_factor_csp_6h_storage_adjusted;

--- not run and suspended -------------------------------:

-- [Pending][Ask Josiah] choose subset of timepoints to insert in variable_capacity_factors
-- insert into intermediate table for variable_capacity_factors
--select project_id, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, datetime_utc, cap_factor  
 -- FROM ampl_study_timepoints 
  --  JOIN ampl_load_scenario_historic_timepoints USING(timepoint_id)
  --  JOIN ampl__cap_factor_intermittent_sites_v2 ON(historic_hour=hour)
  --  JOIN ampl__proposed_projects_v3 USING(project_id)
  --  JOIN ampl_load_area_info_v3 USING(area_id)
 -- WHERE load_scenario_id=21 
 --   AND (( avg_cap_factor_percentile_by_intermittent_tech >= 0.75 or cumulative_avg_MW_tech_load_area <= 3 * total_yearly_load_mwh / 8766 or rank_by_tech_in_load_area <= 5 or avg_cap_factor_percentile_by_intermittent_tech is null) and technology <> 'Concentrating_PV') 
 --   AND technology_id <> 7 
--UNION 
--select project_id, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, datetime_utc, cap_factor_adjusted as cap_factor  
 -- FROM ampl_study_timepoints 
 --   JOIN ampl_load_scenario_historic_timepoints USING(timepoint_id)
 --   JOIN ampl__cap_factor_csp_6h_storage_adjusted ON(historic_hour=hour)
 --   JOIN ampl__proposed_projects_v3 USING(project_id)
 --   JOIN ampl_load_area_info_v3 USING(area_id)
 -- WHERE load_scenario_id=21 
  --  AND (( avg_cap_factor_percentile_by_intermittent_tech >= 0.75 or cumulative_avg_MW_tech_load_area <= 3 * total_yearly_load_mwh / 8766 or rank_by_tech_in_load_area <= 5 or avg_cap_factor_percentile_by_intermittent_tech is null) and technology <> 'Concentrating_PV') 
   -- AND technology_id = 7;



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

-- not used --------------------------------------------------------------
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

create table if not exists ampl_fuel_prices_v4( 
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
-- end not used --------------------------------------------------------------


-- _v4 includes Gas prices from EIA 2017. This is the table used in this version of switch.
COPY ampl_fuel_prices_v4 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_fuel_prices_v4.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

DROP TABLE fuel_simple_price;

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
from ampl_fuel_prices_v4;

update fuel_simple_price_yearly set fuel = 'Electricity' where fuel = 'Storage';

-- insert a second scenario for fuels where there is no CCS
insert into fuel_simple_price_yearly
select 2 as fuel_simple_scenario_id, area_id as load_zone_id, load_area as load_zone_name, fuel, 
year as projection_year, fuel_price, notes, eai_region
from ampl_fuel_prices_v4
where right(fuel,4) != '_CCS';

delete from fuel_simple_price_yearly where fuel_simple_scenario_id=2 and fuel = 'Geothermal'
delete from fuel_simple_price_yearly where fuel_simple_scenario_id=2 and fuel = 'Solar'
delete from fuel_simple_price_yearly where fuel_simple_scenario_id=2 and fuel = 'Water'
delete from fuel_simple_price_yearly where fuel_simple_scenario_id=2 and fuel = 'Wind'
delete from fuel_simple_price_yearly where fuel_simple_scenario_id=2 and fuel = 'Storage'

-- [For now] Assigned fake cost (different from zero) to biomass so we can run a toy. 
-- We plan to use supply curves for biomass instead.
update fuel_simple_price_yearly set fuel_price = 0.5 
where fuel in ('Bio_Gas', 'Bio_Solid', 'Bio_Liquid') 
and fuel_simple_scenario_id=2;

-- Adding new fuel_simple_scenario_id so it doesn't include Bio_Solid. Bio_Solid is included in 
-- supply curve.
insert into fuel_simple_price_yearly
select 3 as fuel_simple_scenario_id, load_zone_id, load_zone_name, fuel, 
projection_year, fuel_price, notes, eai_region
from fuel_simple_price_yearly
where fuel_simple_scenario_id=2
and fuel <> 'Bio_Solid'
;
delete from fuel_simple_price_yearly where fuel_simple_scenario_id=3 and fuel = 'Bio_Gas'


update fuel_simple_price_yearly set fuel_price = 0.01 
where fuel in ('Bio_Gas', 'Bio_Solid', 'Bio_Liquid') 
and fuel_simple_scenario_id=3;

-- fuel_simple_price table skipped here. This table is created in get_switch_input_tables 
-- by joining fuel_simple_price_yearly with table with period_id




insert into fuel_simple_price_scenario
select 1 as fuel_simple_price_scenario_id, 'Basecase from SWITCH AMPL' as name, 
'Fuel prices from SWITCH AMPL. Not Biomass. EIA energy outlook 2017 for Gas(_CCS), Coal(_CCS), DistillateFuelOil(_CCS), ResidualFuelOil(_CCS), and Uranium. The price for the other fuels are from old data from _fuel_prices table (schema switch_inputs_wecc_v2_2) in mySQL' as description; 


insert into fuel_simple_price_scenario
select 2 as fuel_simple_price_scenario_id, 'Basecase from SWITCH AMPL' as name, 
'Fuel prices from SWITCH AMPL. Not Biomass, no CCS. EIA energy outlook 2017 for Gas, Coal, DistillateFuelOil, ResidualFuelOil, and Uranium. The price for the other fuels are from old data from _fuel_prices table (schema switch_inputs_wecc_v2_2) in mySQL' as description; 

insert into fuel_simple_price_scenario
select 3 as fuel_simple_price_scenario_id, 'Basecase from SWITCH AMPL' as name, 
'Fuel prices from SWITCH AMPL. Bio_Solid and Bio_Gas in supply curve, no CCS. EIA energy outlook 2017 for Gas, Coal, DistillateFuelOil, ResidualFuelOil, and Uranium. The price for the other fuels are from old data from _fuel_prices table (schema switch_inputs_wecc_v2_2) in mySQL' as description; 

update switch.fuel_simple_price_scenario set description='Fuel prices from SWITCH AMPL. Bio_Solid and Bio_Gas in supply curve, no CCS. EIA energy outlook 2017 for Gas, Coal, DistillateFuelOil, ResidualFuelOil, and Uranium. The price for the other fuels are from old data from _fuel_prices table (schema switch_inputs_wecc_v2_2) in mySQL' 
where fuel_simple_price_scenario_id=3;


-- Supply curve for biomass:
create table if not exists ampl_biomass_solid_supply_curve_v3( 
breakpoint_id int,
load_area varchar,
year int,
price_dollars_per_mmbtu_surplus_adjusted double PRECISION,
breakpoint_mmbtu_per_year double PRECISION,
notes VARCHAR(300),
primary key( load_area, year, price_dollars_per_mmbtu_surplus_adjusted)
);

COPY ampl_biomass_solid_supply_curve_v3 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_biomass_solid_supply_curve_v3.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;


---------------------------------------------------------------------------
-- Hydropower
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

DROP TABLE hydro_flow_data;

create table hydro_historical_monthly_capacity_factors(
hydro_simple_scenario_id INT,
generation_plant_id INT,
year INT,
month INT,
hydro_min_flow_mw DOUBLE PRECISION,
hydro_avg_flow_mw DOUBLE PRECISION
);

alter table hydro_historical_monthly_capacity_factors add primary key (hydro_simple_scenario_id,
generation_plant_id, year, month);

alter table hydro_historical_monthly_capacity_factors add foreign key (hydro_simple_scenario_id)
REFERENCES hydro_simple_scenario (hydro_simple_scenario_id) MATCH SIMPLE;

alter table hydro_historical_monthly_capacity_factors add foreign key (generation_plant_id)
REFERENCES generation_plant (generation_plant_id) MATCH SIMPLE;

-- 12 months of data for 924 hydropower plants (count matches)
insert into hydro_historical_monthly_capacity_factors
select 1 as hydro_simple_scenario_id, project_id as generation_plant_id, 2006 as year, month,  
0.5*avg_capacity_factor_hydro*capacity as hydro_min_flow_mw,
avg_capacity_factor_hydro*capacity as hydro_avg_flow_mw
from ampl_hydro_monthly_limits_v2 
join generation_plant_existing_and_planned on(generation_plant_id = project_id);



-- Adding new hydro scenario: capacity factors reduced by 30% (i.e. 0.7*avg_capacity_factor_hydro)
insert into hydro_simple_scenario
select 4 as hydro_simple_scenario_id, '70% of water' as name, 
'70% of water from basecase from SWITCH AMPL' as description;

insert into hydro_historical_monthly_capacity_factors
select 4 as hydro_simple_scenario_id, project_id as generation_plant_id, 2006 as year, month,  
0.5*avg_capacity_factor_hydro*capacity as hydro_min_flow_mw,
0.7*avg_capacity_factor_hydro*capacity as hydro_avg_flow_mw
from ampl_hydro_monthly_limits_v2 
join generation_plant_existing_and_planned on(generation_plant_id = project_id);

-- Adding new hydro scenario: capacity factors reduced by 40% (i.e. 0.6*avg_capacity_factor_hydro)
insert into hydro_simple_scenario
select 5 as hydro_simple_scenario_id, '60% of water' as name, 
'60% of water from basecase from SWITCH AMPL' as description;

insert into hydro_historical_monthly_capacity_factors
select 5 as hydro_simple_scenario_id, project_id as generation_plant_id, 2006 as year, month,  
0.5*avg_capacity_factor_hydro*capacity as hydro_min_flow_mw,
0.6*avg_capacity_factor_hydro*capacity as hydro_avg_flow_mw
from ampl_hydro_monthly_limits_v2 
join generation_plant_existing_and_planned on(generation_plant_id = project_id);



---------------------------------------------------------------------------
-- Policies: RPS and Carbon Cap
---------------------------------------------------------------------------

-- RPS:

create table if not exists ampl_rps_compliance_entity_targets_v2(
rps_compliance_entity VARCHAR,
rps_compliance_type VARCHAR,
rps_compliance_year INT,
rps_compliance_fraction DOUBLE PRECISION,
enable_rps int, -- this is really an id
primary key(rps_compliance_entity, rps_compliance_type, rps_compliance_year, enable_rps)
);

COPY ampl_rps_compliance_entity_targets_v2 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_rps_compliance_entity_targets_v2.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

-- RPS done in a separate folder in this same repo.


-- Carbon Cap:

create table if not exists ampl_carbon_cap_targets(
carbon_cap_scenario_id INT,
carbon_cap_scenario_name VARCHAR(300),
year INT,
carbon_emissions_relative_to_base DOUBLE PRECISION,
primary key(carbon_cap_scenario_id, year)
);

COPY ampl_carbon_cap_targets 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_carbon_cap_targets.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;



create table if not exists carbon_cap(
carbon_cap_scenario_id INT,
carbon_cap_scenario_name VARCHAR(300),
year INT,
carbon_cap_tco2_per_yr DOUBLE PRECISION,
carbon_cost_dollar_per_tco2 DOUBLE PRECISION,
primary key(carbon_cap_scenario_id, year)
);

create table if not exists carbon_emissions_historical(
year INT,
emissions_tco2 DOUBLE PRECISION,
primary key (year)
);
-- from switch.mod in AMPL:
--# the base (1990) carbon emissions in tCO2/Yr
--param base_carbon_emissions = 284800000;
insert into carbon_emissions_historical
values (1990, 284800000);

create table if not exists carbon_cost_yearly(
carbon_cost_scenario_id INT,
year INT,
carbon_cost_dollar_per_tco2 DOUBLE PRECISION,
primary key(carbon_cost_scenario_id, year)
);

insert into carbon_cap
select carbon_cap_scenario_id, carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
;

-- another carbon cap scenario
insert into carbon_cap
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and (year <= 2029 or year >= 2050)
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 20*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2030 
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 19*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2031
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 18*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2032
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 17*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2033
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 16*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2034
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 15*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2035
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 14*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2036
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 13*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2037  
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 12*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2038
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 11*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2039
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 10*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2040
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 9*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2041         
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 8*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2042
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 7*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2043
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 6*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2044
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 5*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2045
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 4*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2046
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 3*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2047
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 2*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2048
union
select 87 as carbon_cap_scenario_id, '[CEC] 15% by 2050 minus 20 mton/yr from industry' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) - 1*1000000 as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 35
and year = 2049               
order by year
;


-- another carbon cap scenario
insert into carbon_cap
select 88 as carbon_cap_scenario_id, '[CEC] 0% by 2040' carbon_cap_scenario_name, year, 
carbon_emissions_relative_to_base*( select emissions_tCO2 from carbon_emissions_historical where year=1990) as carbon_cap_tco2_per_yr
from ampl_carbon_cap_targets
where carbon_cap_scenario_id = 2
order by year;

---------------------------------------------------------------------------
-- EV and DR 
---------------------------------------------------------------------------
alter table scenario add column enable_dr int;
alter table scenario add column enable_ev int;

select * from scenario;


---------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------

insert into scenario
values (2, 'AMPL basecase', 'load_id=21, 2017 fuel costs from EIA, 2016 dollars', 2,2,21,2,1,1,1,1);

alter table scenario add column carbon_cap_scenario_id INT;

update scenario set carbon_cap_scenario_id = 35;

insert into scenario
values (3, 
		'AMPL basecase', 
		'timepoints from AMPL 1112, load_id=21, 2017 fuel costs from EIA, 2016 dollars',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		2, -- fuel_simple_price_scenario
		1, -- generation_plant_scenario_id
		1, -- generation_plant_cost_scenario_id
		1, -- generation_plant_existing_and_planned_scenario_id
		1, -- hydro_simple_scenario_id
		35 -- carbon_cap_scenario_id
		); 
		
		
-- new synthetic hydro scenario		
insert into scenario
values (4, 
		'70% of hydro, toy', 
		'Reduced hydro to 70% from basecase, toy_2 timepoints, load_id=21, 2017 fuel costs from EIA, 2016 dollars',
		2, -- study_timeframe_id
		2, -- time_sample_id
		21, -- demand_scenario_id
		2, -- fuel_simple_price_scenario
		1, -- generation_plant_scenario_id
		1, -- generation_plant_cost_scenario_id
		1, -- generation_plant_existing_and_planned_scenario_id
		4, -- hydro_simple_scenario_id
		35 -- carbon_cap_scenario_id
		); 

-- new synthetic hydro scenario		
insert into scenario
values (5, 
		'60% of hydro, toy', 
		'Reduced hydro to 60% from basecase, toy_2 timepoints, load_id=21, 2017 fuel costs from EIA, 2016 dollars',
		2, -- study_timeframe_id
		2, -- time_sample_id
		21, -- demand_scenario_id
		2, -- fuel_simple_price_scenario
		1, -- generation_plant_scenario_id
		1, -- generation_plant_cost_scenario_id
		1, -- generation_plant_existing_and_planned_scenario_id
		5, -- hydro_simple_scenario_id
		35 -- carbon_cap_scenario_id
		); 


-- new synthetic hydro scenario	 full timeframe	
insert into scenario
values (6, 
		'70% of hydro, full timepoints', 
		'Reduced hydro to 70% from basecase, timepoints from AMPL 1112, load_id=21, 2017 fuel costs from EIA, 2016 dollars',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		2, -- fuel_simple_price_scenario
		1, -- generation_plant_scenario_id
		1, -- generation_plant_cost_scenario_id
		1, -- generation_plant_existing_and_planned_scenario_id
		4, -- hydro_simple_scenario_id
		35 -- carbon_cap_scenario_id
		); 


-- new synthetic hydro scenario	 full timeframe	
insert into scenario
values (7, 
		'60% of hydro, full timepoints', 
		'Reduced hydro to 60% from basecase, timepoints from AMPL 1112, load_id=21, 2017 fuel costs from EIA, 2016 dollars',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		2, -- fuel_simple_price_scenario
		1, -- generation_plant_scenario_id
		1, -- generation_plant_cost_scenario_id
		1, -- generation_plant_existing_and_planned_scenario_id
		5, -- hydro_simple_scenario_id
		35 -- carbon_cap_scenario_id
		); 

-- [CCC3] FOR CEC study
insert into scenario
values (12, 
		'[CCC3] Determin. CanESM2 RPC8.5, agg eff w elec', 
		'Aggressive with electrif, CanESM2, RCP8.5, updated gen listings (env cat 2), timepoints from AMPL 1112, load_id=119, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		119, -- demand_scenario_id
		3, -- fuel_simple_price_scenario
		11, -- generation_plant_scenario_id
		5, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		6, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		); 
		
-- [CCC3] FOR CEC study
insert into scenario
values (13, 
		'[CCC3] Determin. HadGEM2ES RPC8.5, agg eff w elec', 
		'Aggressive with electrif, HadGEM2ES, RCP8.5, updated gen listings (env cat 2), timepoints from AMPL 1112, load_id=121, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		121, -- demand_scenario_id
		3, -- fuel_simple_price_scenario
		11, -- generation_plant_scenario_id
		5, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		7, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		); 		
		
-- [CCC3] FOR CEC study
insert into scenario
values (14, 
		'[CCC3] Determin. MIROC5 RPC8.5, agg eff w elec', 
		'Aggressive with electrif, MIROC5, RCP8.5, updated gen listings (env cat 2), timepoints from AMPL 1112, load_id=121, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		123, -- demand_scenario_id
		3, -- fuel_simple_price_scenario
		11, -- generation_plant_scenario_id
		5, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		8, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);		

update switch.scenario set supply_curves_scenario_id = 1 where scenario_id = 17;
update switch.scenario set regional_fuel_market_scenario_id = 1 where scenario_id = 17;
update switch.scenario set zone_to_regional_fuel_market_scenario_id = 1 where scenario_id = 17;
update switch.scenario set rps_scenario_id = 1 where scenario_id = 17;

-- Toy to test RPS, carbon cap, storage, Bio_Solid supply curve.
insert into scenario
values (19, 
		'Base AMPL toy env2: RPS, Bio_Solid supply, storage ', 
		'updated gen listings (env cat 2), load_id=21, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		2, -- study_timeframe_id
		2, -- time_sample_id
		21, -- demand_scenario_id
		3, -- fuel_simple_price_scenario
		13, -- generation_plant_scenario_id
		5, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		1, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);	
		
-- Toy to test RPS, carbon cap, storage, Bio_Solid supply curve.
insert into scenario
values (20, 
		'Base AMPL full env2: RPS, Bio_Solid supply, storage ', 
		'updated gen listings (env cat 2), load_id=21, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		5, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		1, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);
		
		
		
insert into scenario
values (21, 
		'Base AMPL full env2: overnight_cost (E3 4% decr)', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 2), load_id=21, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);
		
insert into scenario
values (22, 
		'Base AMPL full env2: overnight_cost (E3 1% decr)', 
		'Updated overnight_cost (E3 1% decr), updated gen listings (env cat 2), load_id=21, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		7, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (23, 
		'Base AMPL full env2: overnight_cost (E3 2014-16)', 
		'Updated overnight_cost (E3 2014-2016), updated gen listings (env cat 2), load_id=21, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		21, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		8, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (24, 
		'toy env2: overnight_cost (E3 2014-16)', 
		'Updated overnight_cost (E3 2014-2016), updated gen listings (env cat 2), load_id=21, 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		2, -- study_timeframe_id
		2, -- time_sample_id
		21, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		8, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);
		
insert into scenario
values (25, 
		'[CCC3] Frozen', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 2), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		111, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (26, 
		'[CCC3] Interm eff no elect', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 2), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		112, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (27, 
		'[CCC3] Interm eff + elect', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 2), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		113, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (28, 
		'[CCC3] Agg eff no elect', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 2), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		114, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (29, 
		'[CCC3] Agg eff + elect', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 2), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		115, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		13, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

-- Second try: env screen 3 (less wind in CA, most restrictive scenario)

insert into scenario
values (30, 
		'[CCC3] Frozen, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		111, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (31, 
		'[CCC3] Interm eff no elect, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		112, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (32, 
		'[CCC3] Interm eff + elect, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		113, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (33, 
		'[CCC3] Agg eff no elect, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		114, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (34, 
		'[CCC3] Agg eff + elect, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		115, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

-- EV+DR scenarios
insert into scenario
values (35, 
		'[CCC3] EV+DR Agg eff no elect, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		116, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (36, 
		'[CCC3] EV+DR Agg eff + elect, cat3', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		117, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

-- Scenarios with carbon cap (15% by 2050) minus 20 mton/yr from industry -----------------------------------

insert into scenario
values (43, 
		'[CCC3] Frozen, cat3, new carbon cap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		111, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (44, 
		'[CCC3] Interm eff no elect, cat3, new carbon cap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		112, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (45, 
		'[CCC3] Interm eff + elect, cat3, new carbon cap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		113, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (46, 
		'[CCC3] Agg eff no elect, cat3, new carbon cap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		114, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (47, 
		'[CCC3] Agg eff + elect, cat3, new carbon cap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		115, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

-- EV+DR scenarios
insert into scenario
values (48, 
		'[CCC3] EV+DR Agg eff no elect, cat3,newcarboncap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		116, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (49, 
		'[CCC3] EV+DR Agg eff + elect, cat3,newcarboncap', 
		'Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		117, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);
		
		
-- WITH CLIMATE CHANGE CanESM2. Scenarios with carbon cap (15% by 2050) minus 20 mton/yr from industry -----------------------------------
-- Load and hydro under climate change.

insert into scenario
values (50, 
		'[CCC3] CanESM2 RCP8.5, cat3, agg eff w elec', 
		'Loads and hydro under CC. Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		119, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		12, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (51, 
		'[CCC3] HadGEM2ES RCP8.5, cat3, agg eff w elec', 
		'Loads and hydro under CC. Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		121, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		13, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (52, 
		'[CCC3] MIROC5 RCP8.5, cat3, agg eff w elec', 
		'Loads and hydro under CC. Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		123, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		14, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);




-- Wave energy

insert into scenario
values (37, 
		'[Wave] Frozen, cat3', 
		'Wave energy, updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		111, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		15, -- generation_plant_scenario_id
		9, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (38, 
		'[Wave] Interm eff no elect, cat3', 
		'Wave energy, updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		112, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		15, -- generation_plant_scenario_id
		9, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (39, 
		'[Wave] Interm eff + elect, cat3', 
		'Wave energy, updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		113, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		15, -- generation_plant_scenario_id
		9, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (40, 
		'[Wave] Agg eff no elect, cat3', 
		'Wave energy, updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		114, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		15, -- generation_plant_scenario_id
		9, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (41, 
		'[Wave] Agg eff + elect, cat3', 
		'Wave energy, updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		3, -- study_timeframe_id
		3, -- time_sample_id
		115, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		15, -- generation_plant_scenario_id
		9, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);



insert into scenario
values (42, 
		'toy wave, Agg eff + elect, cat3', 
		'Wave energy, updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and carbon cap',
		2, -- study_timeframe_id
		2, -- time_sample_id
		115, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		15, -- generation_plant_scenario_id
		9, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		11, -- hydro_simple_scenario_id
		35, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);


-- 100% RPS scenarios ------------------------------------------------------------------------------

insert into scenario
values (53, 
		'[CCC3] 100% RPS, CanESM2, agg eff w elec', 
		'50% RPS by 2030 and 100% RPS by 2050. Loads and hydro under CC. Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		119, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		12, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		2 -- rps_scenario_id
		);
		
insert into scenario
values (54, 
		'[CCC3] 100% RPS, HadGEM2ES, agg eff w elec', 
		'50% RPS by 2030 and 100% RPS by 2050. Loads and hydro under CC. Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		121, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		13, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		2 -- rps_scenario_id
		);

insert into scenario
values (55, 
		'[CCC3] 100% RPS, MIROC5, agg eff w elec', 
		'50% RPS by 2030 and 100% RPS by 2050. Loads and hydro under CC. Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		123, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		14, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		2 -- rps_scenario_id
		);		


-- delta_MW from climate change divided by three... how are we going to justify this?...

insert into scenario
values (56, 
		'[CCC3] CanESM2 corr, cat3, agg eff w elec', 
		'Loads and hydro under CC (delta_MW divided by 3). Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		129, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		12, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (57, 
		'[CCC3] HadGEM2ES corr, cat3, agg eff w elec', 
		'Loads and hydro under CC (delta_MW divided by 3). Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		131, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		13, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (58, 
		'[CCC3] MIROC5 corr, cat3, agg eff w elec', 
		'Loads and hydro under CC (delta_MW divided by 3). Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		133, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		14, -- hydro_simple_scenario_id
		87, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

-- 0% carbon cap by 2040 and delta_MW from climate change divided by three... how are we going to justify this?...

insert into scenario
values (59, 
		'[CCC3] zero carbon, CanESM2 corr, agg eff w elec', 
		'zero carbon by 2040. Loads and hydro under CC (delta_MW divided by 3). Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		129, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		12, -- hydro_simple_scenario_id
		88, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (60, 
		'[CCC3] zero carbon, HadGEM2ES corr, agg eff w elec', 
		'zero carbon by 2040. Loads and hydro under CC (delta_MW divided by 3). Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		131, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		13, -- hydro_simple_scenario_id
		88, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);

insert into scenario
values (61, 
		'[CCC3] zero carbon, MIROC5 corr, agg eff w elec', 
		'zero carbon by 2040. Loads and hydro under CC (delta_MW divided by 3). Updated overnight_cost (E3 4% decr), updated gen listings (env cat 3), 2017 fuel costs from EIA, 2016 dollars, supply curve for Bio_Solid, current RPS and stronger carbon cap to account for industrys emissions',
		3, -- study_timeframe_id
		3, -- time_sample_id
		133, -- demand_scenario_id
		3, -- fuel_simple_price_scenario, without Bio_Solid costs, because they are provided by supply curve
		14, -- generation_plant_scenario_id
		6, -- generation_plant_cost_scenario_id
		3, -- generation_plant_existing_and_planned_scenario_id
		14, -- hydro_simple_scenario_id
		88, -- carbon_cap_scenario_id
		1, -- supply_curve_scenario_id
		1, -- regional_fuel_market_scenario_id
		1, -- zone_to_regional_fuel_market_scenario_id
		1 -- rps_scenario_id
		);


		
select * from scenario;