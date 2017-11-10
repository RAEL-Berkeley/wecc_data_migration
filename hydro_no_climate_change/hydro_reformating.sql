-- Building hydro tables for get_inputs


set search_path to switch;

insert into switch.hydro_simple_scenario
values (11, 'Year 2010 repeated for all years, EIA 2015' ,'Year 2010 repeated for all years for EIA923 datasets aggregated by load zone up until 2015');

-- inserting 2010
insert into hydro_historical_monthly_capacity_factors
select 11 as hydro_simple_scenario_id, generation_plant_id, 2010 as year, month, hydro_min_flow_mw, hydro_avg_flow_mw
from hydro_historical_monthly_capacity_factors
where hydro_simple_scenario_id=3
and year = 2010
;

-- inserting 2011-2070
DO
$do$
BEGIN
FOR i IN 2011..2070 LOOP
insert into hydro_historical_monthly_capacity_factors
	select 11 as hydro_simple_scenario_id, generation_plant_id, i as year, month, hydro_min_flow_mw, hydro_avg_flow_mw
	from hydro_historical_monthly_capacity_factors
	where hydro_simple_scenario_id=3
	and year = 2010;
END LOOP;
END
$do$;