-- RPS update

-- CA 50% by 2030

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
and rps_compliance_year <=2070
order by 1, 2;

-- update to current RPS:
-- OK: AZ, CO
-- CA


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









-- ----- scratch

--from switch_us db
select * from switch.rps_compliance_entity_targets
where rps_compliance_type='Primary'
and rps_requirement_optional='Mandatory'
order by state, rps_compliance_year;

--from switch_wecc db
select * 
from switch.ampl_rps_compliance_entity_targets_v2
where rps_compliance_type='Primary'
and enable_rps=1
and rps_compliance_year <=2070
order by 1, 3;

select rps_compliance_entity, load_zone_id from (
select * 
from switch.ampl_rps_compliance_entity_targets_v2
--JOIN switch.load_zone on(rps_compliance_entity=name)
where rps_compliance_type='Primary'
and enable_rps=1
and rps_compliance_year <=2070
order by 1, 3
) as w
join switch.load_zone on (rps_compliance_entity=name)
group by 1,2
order by 2;

select * from switch.load_zone
--where name like 'CO_%'
--and name not like 'CAN%'
order by 1
