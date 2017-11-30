-- RPS update

-- CA 50% by 2030
set search_path to switch;

drop table if exists rps_target;

create table rps_target(
rps_scenario_id int,
load_zone varchar,
year int,
rps_target double precision,
primary key(rps_scenario_id, load_zone, year)
)
;

insert into rps_target
select 1 as rps_scenario_id, load_area as load_zone, rps_compliance_year as year, 
rps_compliance_fraction as rps_target
from switch.ampl_rps_compliance_entity_targets_v2
join switch.ampl_load_area_info_v3 USING(rps_compliance_entity)
where rps_compliance_type='Primary'
and enable_rps=1
order by 1, 2;

-- update to current RPS:
-- CA and OREGON

-- CALIFORNIA
update rps_target set rps_target = 0.33 
where year = 2020 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.347 
where year = 2021 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.364
where year = 2022 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.381 
where year = 2023 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.398 
where year = 2024 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.415 
where year = 2025 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.432 
where year = 2026 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.449 
where year = 2027 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.466 
where year = 2028 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.483 
where year = 2029 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';

update rps_target set rps_target = 0.5
where year >= 2030 
and load_zone like 'CA_%' 
and load_zone not like 'CAN%';




-- OREGON (OR_E)
update rps_target set rps_target = 0.271873
where year = 2026 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.288168
where year = 2027 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.304462
where year = 2028 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.320757
where year = 2029 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.337052
where year = 2030 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.353347
where year = 2031 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.369642
where year = 2032 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.385936
where year = 2033 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.402231
where year = 2034 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.418526
where year = 2035 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.434821
where year = 2036 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.451116
where year = 2037 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.467410
where year = 2038 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.483705
where year = 2039 
and load_zone = 'OR_E';

update rps_target set rps_target = 0.500000
where year >= 2040 
and load_zone = 'OR_E';


-- (OR_PDX)
update rps_target set rps_target = 0.249856
where year = 2026 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.267724
where year = 2027 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.285591
where year = 2028 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.303459
where year = 2029 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.321326
where year = 2030 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.339193
where year = 2031 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.357061
where year = 2032 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.374928
where year = 2033 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.392796
where year = 2034 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.410663
where year = 2035 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.428530
where year = 2036 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.446398
where year = 2037 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.464265
where year = 2038 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.482133
where year = 2039 
and load_zone = 'OR_PDX';

update rps_target set rps_target = 0.500000
where year >= 2040 
and load_zone = 'OR_PDX';



-- OREGON (OR_E)
update rps_target set rps_target = 0.271873
where year = 2026 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.288168
where year = 2027 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.304462
where year = 2028 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.320757
where year = 2029 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.337052
where year = 2030 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.353347
where year = 2031 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.369642
where year = 2032 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.385936
where year = 2033 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.402231
where year = 2034 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.418526
where year = 2035 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.434821
where year = 2036 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.451116
where year = 2037 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.467410
where year = 2038 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.483705
where year = 2039 
and load_zone = 'OR_W';

update rps_target set rps_target = 0.500000
where year >= 2040 
and load_zone = 'OR_W';



-- ----- scratch

--from switch_us db
--select * from switch.rps_compliance_entity_targets
--where rps_compliance_type='Primary'
--and rps_requirement_optional='Mandatory'
--order by state, rps_compliance_year;

--from switch_wecc db
--select * 
--from switch.ampl_rps_compliance_entity_targets_v2
--where rps_compliance_type='Primary'
--and enable_rps=1
--and rps_compliance_year <=2070
--order by 1, 3;

--select rps_compliance_entity, load_zone_id from (
--select * 
--from switch.ampl_rps_compliance_entity_targets_v2
--JOIN switch.load_zone on(rps_compliance_entity=name)
--where rps_compliance_type='Primary'
--and enable_rps=1
--and rps_compliance_year <=2070
--order by 1, 3
--) as w
--join switch.load_zone on (rps_compliance_entity=name)
--group by 1,2
--order by 2;

--select * from switch.load_zone
--where name like 'CO_%'
--and name not like 'CAN%'
--order by 1


-- New RPS scenario (50% by 2030 to 100% by 2050 for all load zones) -------------------------------


insert into rps_target
select 2 as rps_scenario_id, load_zone, year, rps_target
from rps_target
where rps_scenario_id=1
and year < 2030
union
select 2 as rps_scenario_id, load_zone, year, 0.5 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2030
union
select 2 as rps_scenario_id, load_zone, year, 0.525 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2031
union
select 2 as rps_scenario_id, load_zone, year, 0.55 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2032
union
select 2 as rps_scenario_id, load_zone, year, 0.575 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2033
union
select 2 as rps_scenario_id, load_zone, year, 0.6 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2034
union
select 2 as rps_scenario_id, load_zone, year, 0.625 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2035
union
select 2 as rps_scenario_id, load_zone, year, 0.65 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2036
union
select 2 as rps_scenario_id, load_zone, year, 0.675 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2037
union
select 2 as rps_scenario_id, load_zone, year, 0.7 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2038
union
select 2 as rps_scenario_id, load_zone, year, 0.725 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2039
union
select 2 as rps_scenario_id, load_zone, year, 0.75 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2040
union
select 2 as rps_scenario_id, load_zone, year, 0.775 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2041
 
union
select 2 as rps_scenario_id, load_zone, year, 0.8 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2042
 
union
select 2 as rps_scenario_id, load_zone, year, 0.825 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2043
 
union
select 2 as rps_scenario_id, load_zone, year, 0.85 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2044
 
union
select 2 as rps_scenario_id, load_zone, year, 0.875 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2045
 
union
select 2 as rps_scenario_id, load_zone, year, 0.9 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2046
 
union
select 2 as rps_scenario_id, load_zone, year, 0.925 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2047
 
union
select 2 as rps_scenario_id, load_zone, year, 0.95 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2048
 
union
select 2 as rps_scenario_id, load_zone, year, 0.975 as rps_target
from rps_target
where rps_scenario_id=1
and year = 2049
 
union
select 2 as rps_scenario_id, load_zone, year, 1 as rps_target
from rps_target
where rps_scenario_id=1
and year >= 2050
order by 2, 3 
;