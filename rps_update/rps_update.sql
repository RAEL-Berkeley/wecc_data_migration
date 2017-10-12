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
select 1 as rps_scenario_id, rps_compliance_entity as load_zone,
rps_compliance_year as year, rps_compliance_fraction as rps_target
from switch.ampl_rps_compliance_entity_targets_v2
where rps_compliance_type='Primary'
and enable_rps=1
order by 1, 3;




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
