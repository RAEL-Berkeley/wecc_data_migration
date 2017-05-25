SET search_path TO switch_wecc_pyomo;

-- select * from ampl__load_projections order by timepoint_id  limit 10; -- [2011, 2051]


-- select * from ampl_study_timepoints order by 1 desc limit 10; -- [2010, 2060]

-- select 17519984/50; -- 350399

--

-- select * from ampl_study_timepoints where timepoint_year >= 2011 and timepoint_year <= 2051; -- 359400
-- does not match with timepoints with load per load zone = 17519984/50 = 350399

-- ran, now edited for 2012
-- insert into raw_timepoint
-- select timepoint_id as raw_timepoint_id, 1 as raw_timeseries_id, datetime_utc as timestamp_utc
-- from ampl_study_timepoints
-- where timepoint_year >= 2012 and timepoint_year <= 2051 order by raw_timepoint_id; -- 350400

--  ran 
--insert into demand_timeseries
--select area_id as load_zone_id, load_scenario_id as demand_scenario_id, timepoint_id as raw_timepoint_id,
--name as  load_zone_name, datetime_utc as timestamp_utc, power as demand_mw
--from ampl__load_projections join load_zone on (load_zone_id=area_id) join ampl_study_timepoints using (timepoint_id);

-- select area_id, count(timepoint_id) from ampl__load_projections group by area_id order by 2,1;

--select * from ampl__load_projections where area_id = 9 order by timepoint_id; -- start timepoint_id = 8769, end 359407
-- select * from ampl__load_projections where area_id = 1 order by timepoint_id; -- start 8768, end 359407


--select * from ampl_fuel_info_v2;

--select fuel as name, rps_fuel_category as is_fuel, 
--CASE
--when rps_fuel_category = cast ('fossilish' as VARCHAR) then 1
--else 0
--end
--as test,
--carbon_content as co2_intensity
--from ampl_fuel_info_v2 as t1;


-- [Ask Josiah] Is it ok if I leave technology with _EP for the exiting ones?
-- [Ask Josiah] capacity_limit column in generation_plant table, for now it's blank for exiting plants
-- [Ask Josiah] t.heat_rate as full_load_heat_rate
-- [Ask Josiah] hydro_efficiency is blank for now
-- [Ask Josiah] unit_size interpreted as capacity_mw
-- [Ask Josiah] store_to_release_ratio is blank for now, but could it be max_store_rate? What are these?
-- [Ask Josiah] minimum_loading as min_load_fraction END
-- [Ask Josiah] startup_fuel as startup_mmbtu_per_mw
-- [Ask Josiah] startup_om as startup_cost_dollars_per_mw
-- Note: ccs_capture_efficiency and ccs_energy_load are left blank for now
-- There are 1920 existing plants





-- shows std of variable_o_m
--select t.project_id as generation_plant_id, t.technology as gen_tech, stddev(t3.variable_o_m_by_year) as variable_o_m 
--from ampl_proposed_projects_tab as t join load_zone as t1 on(name = load_area) 
--				   join ampl_gen_info_scenario_v3 as t2 using(technology)
--				   join ampl_generator_costs_tab as t3 using(technology)
--group by project_id, t.technology
--order by 3;	 






















