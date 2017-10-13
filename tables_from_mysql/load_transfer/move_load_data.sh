# N.B. The descriptions in the mysql database are basically worthless, so
# you'll need to edit the descriptions of the load scenarios manually.
# You might also want to execute this script step-by-step if you want to 
# inspect the intermediate files or keep them around before deleting them.
mysql_db="loads_wecc_ccc3_revised"
load_scenario_ids="111,112,113,114,115,116,117"
load_scenario_sql="
select 
	load_scenario_id as demand_scenario_id, 
	'' as name,
	scenario_name as description
from CCC3_load_scenario_table
 	join ccc3_load_scenario_mapping USING (CCC3_load_scenario)
where CCC3_load_scenario in ($load_scenario_ids);
"
mysql -p $mysql_db -e "$load_scenario_sql" > load_scenarios.txt

load_data_sql="
select 
	area_id as load_zone_id, 
	load_scenario_id as demand_scenario_id, 
	timepoint_id as raw_timepoint_id, 
	load_area as load_zone_name,
	datetime_utc as timestamp_utc,
	load_MWh as demand_mw
from CCC3_WECC_loads_aggregated_V3
 	join ccc3_load_scenario_mapping USING (CCC3_load_scenario)
	join switch_inputs_wecc_v2_2.load_area_info_v3 USING (area_id)
	join switch_inputs_wecc_v2_2.study_timepoints using(timepoint_id)
where CCC3_load_scenario in ($load_scenario_ids);
"
# We are only drawing from one historic year for now, so skip the historic timepoint export
# future_2006_datetime_map.datetime_utc_2006 as historic_timestamp_utc, 


mysql -p $mysql_db -e "$load_data_sql" > load_data.txt


psql -c "\copy switch.demand_scenario from 'load_scenarios.txt' with csv header delimiter '	';" switch_wecc
psql -c "\copy switch.demand_timeseries from 'load_data.txt' with csv header delimiter '	';" switch_wecc

rm load_scenarios.txt load_data.txt