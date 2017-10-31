
set search_path to switch;

-- table for all supply curves
-- for CCC3 we will only use a bio_solid supply curve
-- For the future: incorporate natural gas supply curve


-- fuel_supply_curves ------------------------------------------------------------------------------------

drop table if exists switch.fuel_supply_curves;

create table if not exists switch.fuel_supply_curves(
supply_curves_scenario_id int,
regional_fuel_market varchar,
fuel varchar,
year int,
tier int,
unit_cost double precision,
max_avail_at_cost double precision,
notes text,
primary key (supply_curves_scenario_id, 
			regional_fuel_market,
			fuel,
			year,
			tier)
);

-- Bio_Solid
insert into switch.fuel_supply_curves (supply_curves_scenario_id, regional_fuel_market, fuel, year, tier, 
unit_cost, max_avail_at_cost, notes)
select 1 as supply_curves_scenario_id,
concat(load_area, '-Bio_Solid') as regional_fuel_market,
'Bio_Solid' as fuel,
year as year,
breakpoint_id as tier,
price_dollars_per_mmbtu_surplus_adjusted as unit_cost,
breakpoint_mmbtu_per_year as max_avail_at_cost,
notes as notes
from switch.ampl_biomass_solid_supply_curve_v3
order by load_area, fuel, year, breakpoint_mmbtu_per_year;

-- Bio_Gas
insert into switch.fuel_supply_curves (supply_curves_scenario_id, regional_fuel_market, fuel, year, tier, 
unit_cost, max_avail_at_cost, notes)
select 1 as supply_curves_scenario_id,
concat(load_area, '-Bio_Gas') as regional_fuel_market, 'Bio_Gas' as fuel, year, 1 as tier,
0 as unit_cost, 
bio_gas_capacity_limit_mmbtu_per_hour*8760 as max_avail_at_cost,'Data from ampl_load_area_info_v3' as notes  
from switch.ampl_biomass_solid_supply_curve_v3
join switch.ampl_load_area_info_v3 using(load_area)
group by 1, 2, year, bio_gas_capacity_limit_mmbtu_per_hour;


select * from switch.fuel_supply_curves;

-- Note: Last tier has NULL as max_avail_at_cost. Handle this in get_inputs.py (print as inf)



-- regional_fuel_market ----------------------------------------------------------------------------------------------------

drop table if exists switch.regional_fuel_market;

create table switch.regional_fuel_market(
regional_fuel_market_scenario_id int,
regional_fuel_market varchar,
fuel varchar,
primary key (regional_fuel_market_scenario_id, regional_fuel_market, fuel)
);

--Bio_Solid
insert into switch.regional_fuel_market
select 1 as regional_fuel_market_scenario_id,
concat(name, '-Bio_Solid') as regional_fuel_market, 'Bio_Solid' as fuel 
from switch.load_zone
order by 1;

--Bio_Gas
insert into switch.regional_fuel_market
select 1 as regional_fuel_market_scenario_id,
concat(name, '-Bio_Gas') as regional_fuel_market, 'Bio_Gas' as fuel 
from switch.load_zone
order by 1;

-- zone_to_regional_fuel_market ----------------------------------------------------------------------------------------------------

drop table if exists switch.zone_to_regional_fuel_market;

create table switch.zone_to_regional_fuel_market(
zone_to_regional_fuel_market_scenario_id int,
load_zone varchar,
regional_fuel_market varchar
);

--Bio_Solid
INSERT into switch.zone_to_regional_fuel_market
select 1 as zone_to_regional_fuel_market_scenario_id,
name as load_zone,
concat(name, '-Bio_Solid') as regional_fuel_market
from switch.load_zone
order by 2;

--Bio_Gas
INSERT into switch.zone_to_regional_fuel_market
select 1 as zone_to_regional_fuel_market_scenario_id,
name as load_zone,
concat(name, '-Bio_Gas') as regional_fuel_market
from switch.load_zone
order by 2;

-- add new id columns to scenario table ---------------------------------------------------------------

alter table scenario add column supply_curves_scenario_id int;
alter table scenario add column regional_fuel_market_scenario_id int;
alter table scenario add column zone_to_regional_fuel_market_scenario_id int;




