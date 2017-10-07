
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




-- experiemntal:
-- source: https://stackoverflow.com/questions/6821871/postgresql-sequence-based-on-another-column

drop table if exists public.years_in_supply_curve;

create table public.years_in_supply_curve(
year int,
primary key(year)
);


CREATE FUNCTION make_thing_seq5() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  execute format('create sequence thing_seq5_%s', NEW.year);
  return NEW;
end
$$;

CREATE TRIGGER make_thing_seq5 AFTER INSERT ON public.years_in_supply_curve 
FOR EACH ROW EXECUTE PROCEDURE make_thing_seq5();

insert into public.years_in_supply_curve
select year from switch.ampl_biomass_solid_supply_curve_v3
group by year
order by year;



-- 
CREATE FUNCTION fill_in_stuff_seq5() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  NEW.tier := nextval('thing_seq5_' || NEW.year);
  RETURN NEW;
end
$$;

CREATE TRIGGER fill_in_stuff_seq5 BEFORE INSERT ON switch.fuel_supply_curves 
FOR EACH ROW EXECUTE PROCEDURE fill_in_stuff_seq5();

-- end of esoteric functions

insert into switch.fuel_supply_curves (supply_curves_scenario_id, regional_fuel_market, fuel, year, 
unit_cost, max_avail_at_cost, notes)
select 1 as supply_curves_scenario_id,
load_area as regional_fuel_market,
'Bio_Solid' as fuel,
year as year,
price_dollars_per_mmbtu_surplus_adjusted as unit_cost,
breakpoint_mmbtu_per_year as max_avail_at_cost,
notes as notes
from switch.ampl_biomass_solid_supply_curve_v3
order by load_area, fuel, year, breakpoint_mmbtu_per_year;

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

insert into switch.regional_fuel_market
select 1 as regional_fuel_market_scenario_id,
name as regional_fuel_market, 'Bio_Solid' as fuel 
from switch.load_zone
order by 1;

-- zone_to_regional_fuel_market ----------------------------------------------------------------------------------------------------

drop table if exists switch.zone_to_regional_fuel_market;

create table switch.zone_to_regional_fuel_market(
zone_to_regional_fuel_market_scenario_id int,
load_zone varchar,
regional_fuel_market varchar,
primary key (zone_to_regional_fuel_market_scenario_id, load_zone)
);

INSERT into switch.zone_to_regional_fuel_market
select 1 as zone_to_regional_fuel_market_scenario_id,
name as load_zone,
name as regional_fuel_market
from switch.load_zone
order by 2;








