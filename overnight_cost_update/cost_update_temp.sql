



select * from switch.ampl_generator_costs_yearly_v3 where gen_costs_scenario_id = 10 and technology in ('Central_PV', 'Battery_Storage', 'Commercial_PV', 'Compressed_Air_Energy_Storage'
'CSP_Trough_6h_Storage', 'CSP_Trough_No_Storage', 'Geothermal', 'Offshore_Wind', 'Residential_PV', 'Wind') order by technology, year;

-- lower: Central_PV, Commercial_PV, Geothermal, "Offshore_Wind", "Residential_PV"
-- "CSP_Trough_No_Storage" is close enough, Wind OK!



--------------
-- plan: add generation_plant_cost_scenario_id=6 that is the same as generation_plant_cost_scenario_id=5 but with new costs for
-- Central_PV, Commercial_PV, Geothermal, "Offshore_Wind", "Residential_PV" 

-- 763719
select generation_plant_cost_scenario_id, generation_plant_id, gen_tech, build_year
from generation_plant_cost 
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
;

----------------------------------------------------------------------------------------------------

drop table public.overnight_cost_update;

create table public.overnight_cost_update(
scenario_id int,
gen_tech varchar,
year int,
overnight_cost_mw double precision,
primary key (scenario_id, gen_tech, year)
);

COPY public.overnight_cost_update 
FROM '/var/tmp/home_pehidalg/overnight_cost_update/1400kW_1decr.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

COPY public.overnight_cost_update 
FROM '/var/tmp/home_pehidalg/overnight_cost_update/1400kW_4decr_1decr.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

COPY public.overnight_cost_update 
FROM '/var/tmp/home_pehidalg/overnight_cost_update/E3_old_1decr.csv'  
DELIMITER ',' NULL AS 'NULL' CSV HEADER;

-- inserting the data ------------------------------------------------------------------------------

insert into generation_plant_cost_scenario
values (6, 'Basecase unified, updated solar+others', 'Same generators as Basecase unified (id 5). Updated overnight cost for solar (E3), 4% decrease til 2030 and then 1%, geothermal, and offshore_wind');

-- before 2016
-- 115719
insert into generation_plant_cost
select 6 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
and build_year < 2016
;

-- from 2016 and not the techs to be updated
-- 474155
insert into generation_plant_cost
select 6 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
and gen_tech not in ('Central_PV', 'Commercial_PV', 'Geothermal', 'Offshore_Wind', 'Residential_PV')
and build_year>=2016
;

-- from 2016 and techs to be updated
-- 173845
insert into generation_plant_cost
select 6 as generation_plant_cost_scenario_id, generation_plant_id, year as build_year, t1.fixed_o_m, 
overnight_cost_mw as overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost as t1 
join generation_plant as t3 using(generation_plant_id)
join public.overnight_cost_update as t2 on(t2.gen_tech=t3.gen_tech and year=build_year)
where generation_plant_cost_scenario_id=5
and scenario_id=1 -- edit here!!
and t3.gen_tech in ('Central_PV', 'Commercial_PV', 'Geothermal', 'Offshore_Wind', 'Residential_PV')
and build_year>=2016
and year <= 2050
order by 2, 3 
;


-- inserting the data ------------------------------------------------------------------------------

insert into generation_plant_cost_scenario
values (7, 'Basecase unified, updated solar+others less aggressive', 'Same generators as Basecase unified (id 5). Updated overnight cost for solar (E3), 1% decrease til 2050, geothermal, and offshore_wind');

-- before 2016
-- 115719
insert into generation_plant_cost
select 7 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
and build_year < 2016
;

-- from 2016 and not the techs to be updated
-- 474155
insert into generation_plant_cost
select 7 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
and gen_tech not in ('Central_PV', 'Commercial_PV', 'Geothermal', 'Offshore_Wind', 'Residential_PV')
and build_year>=2016
;

-- from 2016 and techs to be updated
-- 173845
insert into generation_plant_cost
select 7 as generation_plant_cost_scenario_id, generation_plant_id, year as build_year, t1.fixed_o_m, 
overnight_cost_mw as overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost as t1 
join generation_plant as t3 using(generation_plant_id)
join public.overnight_cost_update as t2 on(t2.gen_tech=t3.gen_tech and year=build_year)
where generation_plant_cost_scenario_id=5
and scenario_id=2 -- edit here!!
and t3.gen_tech in ('Central_PV', 'Commercial_PV', 'Geothermal', 'Offshore_Wind', 'Residential_PV')
and build_year>=2016
and year <= 2050
order by 2, 3 
;


-- inserting the data ------------------------------------------------------------------------------

insert into generation_plant_cost_scenario
values (8, 'Basecase unified, old updated solar+others', 'Same generators as Basecase unified (id 5). Old (2014-2016) Updated overnight cost for solar (E3), 1% decrease til 2050, geothermal, and offshore_wind');

-- before 2016
-- 115719
insert into generation_plant_cost
select 8 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
and build_year < 2016
;

-- from 2016 and not the techs to be updated
-- 481715
insert into generation_plant_cost
select 8 as generation_plant_cost_scenario_id, generation_plant_id, build_year, fixed_o_m, overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost
join generation_plant using(generation_plant_id)
where generation_plant_cost_scenario_id=5
and gen_tech not in ('Central_PV', 'Commercial_PV', 'Geothermal', 'Offshore_Wind')
and build_year>=2016
;

-- from 2016 and techs to be updated
-- 166285
insert into generation_plant_cost
select 8 as generation_plant_cost_scenario_id, generation_plant_id, year as build_year, t1.fixed_o_m, 
overnight_cost_mw as overnight_cost, 
storage_energy_capacity_cost_per_mwh
from generation_plant_cost as t1 
join generation_plant as t3 using(generation_plant_id)
join public.overnight_cost_update as t2 on(t2.gen_tech=t3.gen_tech and year=build_year)
where generation_plant_cost_scenario_id=5
and scenario_id=3 -- edit here!!
and t3.gen_tech in ('Central_PV', 'Commercial_PV', 'Geothermal', 'Offshore_Wind')
and build_year>=2016
and year <= 2050
order by 2, 3 
;























