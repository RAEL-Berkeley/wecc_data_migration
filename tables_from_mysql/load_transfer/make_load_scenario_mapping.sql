-- Run in mysql. 
-- This defines new id's for Cui load scenarios because the ids
-- he chose had already been used by prior work.
use loads_wecc_ccc3;
CREATE TABLE ccc3_load_scenario_mapping (
    CCC3_load_scenario int,
    load_scenario_id int,
    PRIMARY KEY (CCC3_load_scenario, load_scenario_id));
INSERT INTO ccc3_load_scenario_mapping (CCC3_load_scenario, load_scenario_id)
    SELECT CCC3_load_scenario, CCC3_load_scenario+20 FROM CCC3_load_scenario_table;

select * from ccc3_load_scenario_mapping;
