
set search_path to switch;

create table if not exists switch.fuel_supply_curves(
supply_curves_scenario_id int,
regional_fuel_market varchar,
fuel varchar,
year int,
tier int,
unit_cost double precision,
max_avail_at_cost double precision,
primary key (supply_curve_scenario_id, 
			regional_fuel_market,
			fuel,
			year,
			tier)
);

