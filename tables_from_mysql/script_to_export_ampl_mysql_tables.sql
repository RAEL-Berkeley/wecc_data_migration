

-- saving tables to later import to postgresql

select * from load_area_info_v3;

select * from _load_projections where load_scenario_id = 21 limit 99999999;

select * from study_timepoints limit 99999999999;

select * from fuel_info_v2;

select technology, technology_id, min_online_year, fuel, construction_time_years, year_1_cost_fraction, year_2_cost_fraction, year_3_cost_fraction, year_4_cost_fraction, 
year_5_cost_fraction, year_6_cost_fraction, max_age_years, forced_outage_rate, scheduled_outage_rate, can_build_new, ccs, intermittent, resource_limited, baseload, 
flexible_baseload, dispatchable, cogen, min_build_capacity, competes_for_space, storage, storage_efficiency, max_store_rate, max_spinning_reserve_fraction_of_capacity, 
heat_rate_penalty_spinning_reserve, minimum_loading, deep_cycling_penalty, startup_mmbtu_per_mw, startup_cost_dollars_per_mw 
from generator_info_v3 
where gen_info_scenario_id=13; -- gen_info_scenario_id=13 is base case with no ccs


select project_id, load_area, technology, plant_name, eia_id, capacity_mw, 
       heat_rate, cogen_thermal_demand_mmbtus_per_mwh, 
       if(start_year = 0, 1900, start_year) as start_year, 
       forced_retirement_year, overnight_cost, connect_cost_per_mw, 
       fixed_o_m, variable_o_m 
from existing_plants_v3 
order by 1, 2, 3 LIMIT 999999;




select project_id, proposed_projects_v3.load_area, technology,
       if(location_id=0, NULL, location_id) as location_id,
       ep_project_replacement_id,
       capacity_limit,
       capacity_limit_conversion,
       if(heat_rate=0, NULL, heat_rate) as heat_rate, 
       cogen_thermal_demand, 
       (1.15 * connect_cost_per_mw) as connect_cost_per_mw,
       avg_cap_factor_intermittent as average_capacity_factor_intermittent 
from proposed_projects_v3 join load_area_info_v3 using (area_id) 
where technology_id in (SELECT technology_id FROM generator_info_v3 where gen_info_scenario_id=13) 
      AND ((( avg_cap_factor_percentile_by_intermittent_tech >= 0.75 or cumulative_avg_MW_tech_load_area <= 3 * total_yearly_load_mwh / 8766 or rank_by_tech_in_load_area <= 5 or avg_cap_factor_percentile_by_intermittent_tech is null) and technology <> 'Concentrating_PV'))
      limit 100000;
      
--  ampl_generator_costs_tab.csv      
select technology, year, overnight_cost, storage_energy_capacity_cost_per_mwh, fixed_o_m, var_o_m as variable_o_m_by_year 
from generator_costs_yearly_v3 
join generator_info_v3 g using (technology) 
where gen_costs_scenario_id=10 
and gen_info_scenario_id=13;


-- Original query from get_switch_inout_tables for existing projects capacity factors. Not saved as csv
SELECT project_id, load_area, technology, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor 
FROM _training_set_timepoints 
  JOIN study_timepoints USING(timepoint_id) 
  JOIN load_scenario_historic_timepoints USING(timepoint_id) 
  JOIN existing_intermittent_plant_cap_factor ON(historic_hour=hour) 
WHERE training_set_id=$TRAINING_SET_ID AND load_scenario_id=$LOAD_SCENARIO_ID;


-- Proposed query. Check by counting timepoints by project: All existing projects (apparently 266 are renewable projects) have 350400 timepoints. So we are good! . Not saved as csv
select project_id, count(timepoint_id)  from 
(SELECT project_id, load_area, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor 
FROM study_timepoints 
  JOIN load_scenario_historic_timepoints USING(timepoint_id) 
  JOIN existing_intermittent_plant_cap_factor ON(historic_hour=hour) 
WHERE load_scenario_id=21) as t
group by project_id order by 2;

-- reality check
select load_scenario_id, count(timepoint_id) from load_scenario_historic_timepoints group by load_scenario_id; -- historic_hour, timepoint_id, load_scenario_id . Not saved as csv


-- ampl_existing_intermittent_plant_cap_factor.csv / load_scenario_id=21  is used for the timepoints, no load is used.
SELECT project_id, load_area, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor 
FROM study_timepoints 
  JOIN load_scenario_historic_timepoints USING(timepoint_id) 
  JOIN existing_intermittent_plant_cap_factor ON(historic_hour=hour) 
WHERE load_scenario_id=21 
limit 100000000;


-- -------------------------------------------------------------------------- ------------------------------------------------------------------------
-- scratch queries related to proposed projects cap factors
-- -------------------------------------------------------------------------- ------------------------------------------------------------------------    

-- proposed projects cap factors
-- ampl_cap_factor.csv / load_scenario_id=21  is used for the timepoints, no load is used.
-- It was ran in a bash script on the xserve 
-- afp://xserve-rael.erg.berkeley.edu/switch/Users/pehidalg/SWITCH_WECC/Migration_from_AMPL_to_Python/saving_tables_into_csv_from_server.sh
-- select project_id, load_area, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor  \
 -- FROM study_timepoints \
   -- JOIN load_scenario_historic_timepoints USING(timepoint_id)\
    -- JOIN $cap_factor_table ON(historic_hour=hour)\
   -- JOIN $proposed_projects_table USING(project_id)\
   -- JOIN load_area_info_v3 USING(area_id)\
 -- WHERE load_scenario_id=21 \
  --  AND $INTERMITTENT_PROJECTS_SELECTION \
   -- AND technology_id <> 7 \
-- UNION \
-- select project_id, load_area, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor_adjusted as cap_factor  \
 -- FROM study_timepoints \
  --  JOIN load_scenario_historic_timepoints USING(timepoint_id)\
  --  JOIN $cap_factor_csp_6h_storage_table ON(historic_hour=hour)\
  --  JOIN $proposed_projects_table USING(project_id)\
  --  JOIN load_area_info_v3 USING(area_id)\
  -- WHERE load_scenario_id=21 \
  --  AND $INTERMITTENT_PROJECTS_SELECTION \
   -- AND technology_id = 7;" >> ampl_cap_factor.csv;
    
    

SHOW VARIABLES WHERE Variable_Name LIKE "%dir";


-- the query below shows the sixe of a table. In our case it was 11863 MB (=11GB)
SELECT 
    table_name AS `Table`, 
    round(((data_length + index_length) / 1024 / 1024), 2) `Size in MB` 
FROM information_schema.TABLES 
WHERE table_schema = "switch_inputs_wecc_v2_2"
    AND table_name = "_cap_factor_intermittent_sites_v2";
    

select * from _cap_factor_intermittent_sites_v2 limit 10; -- 100000000;

-- I left running  xserve-rael:Migration_from_AMPL_to_Python pehidalg$ ./saving_tables_into_csv_from_server.sh --tunnel
-- That script is still running. Now I am using plan B:

-- -------------------------------------------------------------------------- ------------------------------------------------------------------------
-- Plan B for proposed projects cap factors: copy all the tables were joins were happening and do the joins in psql

-- -------------------------------------------------------------------------- ------------------------------------------------------------------------  




-- ampl__cap_factor_intermittent_sites_v2.csv
select *  
FROM  _cap_factor_intermittent_sites_v2 
  order by project_id, hour limit 1000000000;
  
-- ampl_study_timepoints.csv was already imported for other query

-- ampl_load_scenario_historic_timepoints.csv -- only for load_scenario_id = 21
select * from load_scenario_historic_timepoints where load_scenario_id = 21 limit 400000;

-- ampl__proposed_projects_v3.csv
select * from _proposed_projects_v3 limit 1000000;

-- ampl_load_area_info_v3.csv was already imported for other query

  
-- tables from after "UNION" that haven't been exported yet:

-- ampl__cap_factor_csp_6h_storage_adjusted.csv
select * from _cap_factor_csp_6h_storage_adjusted limit 1000000000;  


-- --------------------------------------------------------------------------------------------
-- generator costs
-- --------------------------------------------------------------------------------------------

select * from generator_costs_yearly_v3 limit 1000000;
select * from generator_costs_yearly_v3 where gen_costs_scenario_id=10  limit 1000000;

select 303892/7412;
  
-- --------------------------------------------------------------------------------------------
-- transmission lines
-- --------------------------------------------------------------------------------------------
select load_area_start, load_area_end, existing_transfer_capacity_mw, transmission_line_id, 
transmission_length_km, transmission_efficiency, new_transmission_builds_allowed, is_dc_line, 
transmission_derating_factor, terrain_multiplier 
from transmission_lines 
order by 1,2;



-- --------------------------------------------------------------------------------------------
-- fuel costs
-- --------------------------------------------------------------------------------------------

select * from fuel_prices_v3 limit 10; -- 1000000000;

select notes from fuel_prices_v3 group by notes;

-- creation of new fuel_prices table to include Gas prices from EIA 2017 instead of old supply curve

CREATE TABLE `fuel_prices_v4` (
  `fuel_scenario_id` int(11) NOT NULL DEFAULT '0',
  `area_id` int(11) DEFAULT NULL,
  `load_area` varchar(50) NOT NULL DEFAULT '',
  `fuel` varchar(50) NOT NULL DEFAULT '',
  `year` int(11) NOT NULL DEFAULT '0',
  `fuel_price` double DEFAULT NULL,
  `notes` varchar(300) DEFAULT NULL,
  `eia_region` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`fuel_scenario_id`,`load_area`,`fuel`,`year`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Fuel_prices table. Built in 2017 using EIA energy outlook 2017 including Gas prices. 2016 $/MMBtu';


insert into fuel_prices_v4
select * from fuel_prices_v3;

select * from fuel_prices_v4;

update fuel_prices_v4 as w
set fuel_price = (select fuel_price 
                    from fuel_prices_regional_v3 as t 
                    where w.eia_region = t.eia_region
                    and w.year = t.year
                    and t.fuel = 'NaturalGas')
                    where fuel = 'Gas'or fuel = 'Gas_CCS';

select * from fuel_prices_v4 where fuel = 'Gas' or fuel = 'Gas_CCS' limit 100;

-- updating notes
update fuel_prices_v4 as t1
set notes = (select notes from fuel_prices_regional_v3 as t2 where t1.eia_region = t2.eia_region and t1.year = t2.year and t2.fuel = 'NaturalGas') 
where t1.fuel = 'Gas' or fuel = 'Gas_CCS';

select * from fuel_prices_v4 limit 9999999999999;


select * from biomass_solid_supply_curve_v3 limit 999999999999999;



-- --------------------------------------------------------------------------------------------
-- Policies: RPS and Carbon Cap
-- --------------------------------------------------------------------------------------------

select * from rps_compliance_entity_targets_v2 limit 9999999999999;

select * from carbon_cap_targets limit 999999999999;










-- --------------------------------------------------------------------------------------------
-- hydro
-- --------------------------------------------------------------------------------------------
select * from hydro_monthly_limits_v2 limit 1000000000000000000;


select balancing_area, load_only_spinning_reserve_requirement, wind_spinning_reserve_requirement, solar_spinning_reserve_requirement, 
quickstart_requirement_relative_to_spinning_reserve_requirement 
from balancing_areas;

