-- Core schema for SWITCH-PYOMO, meant for PostgreSQL with PostGIS
-- extensions.
-- Copyright 2015 The Switch Authors. All rights reserved.
-- Licensed under the Apache License, Version 2, which is in the LICENSE file.


-- SWITCH schema

-- drop SCHEMA switch_wecc_pyomo cascade;


CREATE SCHEMA switch_wecc_pyomo;
COMMENT ON SCHEMA switch_wecc_pyomo
  IS 'This schema contains core tables for use with SWITCH-pyomo. All major "data blocks", such as projects, load zones, 
  fuel prices, etc, are indexed by scenario ids. 
  These are used in the scenarios_switch table to set up different SWITCH scenarios that you can run.
   A script called get_switch_input_tables.py reads those keys and constructs input tables according to the specified 
   scenarios ids.';
set search_path = switch_wecc_pyomo;


set search_path = switch_wecc_pyomo;
-----------------------------
-- Timescales
-----------------------------

CREATE TABLE raw_timeseries
(
  raw_timeseries_id smallint PRIMARY KEY,
  hours_per_tp double precision NOT NULL,
  num_timepoints INT NOT NULL,
  first_timepoint_utc timestamp without time zone,
  last_timepoint_utc timestamp without time zone,
  start_year smallint,
  end_year smallint,
  description text
);
COMMENT ON TABLE raw_timeseries
  IS 'A sequence of future timepoints for which you have projections of operational data: loads, renewable output, 
  hydro availability, ... each of those timeseries will be defined over this sequence of timepoints. 
  These datasets can be reused across different studies that may have different specifications of study 
  periods (ex. 1-year periods for short-term studies, 5-year periods for long-term studies). 
  Each raw_timeseries will typically be one year long, but they can technically be of any length.';

CREATE TABLE raw_timepoint
(
  raw_timepoint_id int PRIMARY KEY,
  raw_timeseries_id smallint REFERENCES raw_timeseries,
  timestamp_utc timestamp without time zone,
  UNIQUE (raw_timeseries_id, timestamp_utc),
  UNIQUE (raw_timepoint_id, timestamp_utc)
);

CREATE TABLE study_timeframe
(
  study_timeframe_id smallint PRIMARY KEY,
  name character varying(30) NOT NULL,
  description text
);
COMMENT ON TABLE study_timeframe
  IS 'Defines a time frame for one or more studies which includes a set of periods and timeseries within each period. 
  If you wish to change the length or number of investment periods, you will need to define a new row in this table.';

CREATE TABLE period
(
  study_timeframe_id smallint REFERENCES study_timeframe,
  period_id smallint PRIMARY KEY,
  start_year smallint NOT NULL,
  label smallint NOT NULL,
  length_yrs smallint,
  UNIQUE (study_timeframe_id, period_id)
);
COMMENT ON TABLE period
  IS 'Defines investment periods within a given study timeframe. These are block of time in which investment can 
  occur and are typically between 1 and 10 years long. Each period is linked to one or more raw timeseries.';

CREATE TABLE period_all_timeseries
(
  study_timeframe_id smallint REFERENCES study_timeframe,
  period_id smallint REFERENCES period,
  raw_timeseries_id smallint REFERENCES raw_timeseries,
  PRIMARY KEY (study_timeframe_id, period_id, raw_timeseries_id),
  UNIQUE (period_id, raw_timeseries_id),
  FOREIGN KEY (study_timeframe_id, period_id) 
    REFERENCES period (study_timeframe_id, period_id)
);
COMMENT ON TABLE period_all_timeseries
  IS 'The raw timeseries that describe operational conditions in this period. For statistical purposes, this is the 
  population of time-based data to sample from. Raw timeseries may be shared across different study timeframes. 
  If all of the raw timeseries are bootstrapped from a single year of historical data, then you would only include 
  one year in a given period (even if the period is several years long) because including more years won''t provide 
  more diversity of renewable outputs.';


CREATE TABLE time_sample
(
  time_sample_id smallint PRIMARY KEY,
  study_timeframe_id smallint REFERENCES study_timeframe,
  name character varying(30) NOT NULL,
  method text,
  description text,
  UNIQUE (study_timeframe_id, time_sample_id)
);
COMMENT ON TABLE time_sample
  IS 'A representative sample drawn from all available timeseries in this study timeframe. A single study timeframe 
  may have multiple sample drawn from it.';

CREATE TABLE sampled_timeseries
(
  sampled_timeseries_id smallint PRIMARY KEY,
  study_timeframe_id smallint REFERENCES study_timeframe,
  time_sample_id smallint REFERENCES time_sample,
  period_id smallint REFERENCES period,
  name character varying(30) NOT NULL,
  hours_per_tp double precision NOT NULL,
  num_timepoints INT NOT NULL,
  first_timepoint_utc timestamp without time zone,
  last_timepoint_utc timestamp without time zone,
  scaling_to_period double precision NOT NULL,
  UNIQUE (study_timeframe_id, time_sample_id, sampled_timeseries_id),
  FOREIGN KEY (study_timeframe_id, time_sample_id) 
    REFERENCES time_sample (study_timeframe_id, time_sample_id)
);
COMMENT ON TABLE sampled_timeseries
  IS 'A representative sampling from all available timeseries in this study timeframe. Redundant index columns are 
  intentional to allow faster queries.';
COMMENT ON COLUMN sampled_timeseries.scaling_to_period
  IS 'The number of times conditions like this are expected to occur in the period. 
  The sum of hours_per_tp * num_timepoints * scaling_to_period for all timeseries in a period should equal the 
  number of hours in that period.';

CREATE TABLE sampled_timepoint
(
  raw_timepoint_id smallint PRIMARY KEY REFERENCES raw_timepoint,
  study_timeframe_id smallint REFERENCES study_timeframe,
  time_sample_id smallint REFERENCES time_sample,
  sampled_timeseries_id smallint REFERENCES sampled_timeseries,
  period_id smallint REFERENCES period,
  timestamp_utc timestamp without time zone,
  FOREIGN KEY (study_timeframe_id, time_sample_id, sampled_timeseries_id) 
    REFERENCES sampled_timeseries (study_timeframe_id, time_sample_id, sampled_timeseries_id)
);
COMMENT ON TABLE sampled_timepoint
  IS 'A set of sampled timepoints, organized into timeseries. Redundant index columns are intentional to allow 
  faster queries.';

-----------------------------
-- Load zones
-----------------------------

CREATE TABLE load_zone
(
  load_zone_id smallint PRIMARY KEY,
  name character varying(30) NOT NULL,
  description text,
  ccs_distance_km double precision,
  existing_local_td double precision,
  local_td_annual_cost_per_mw double precision,
  reserves_area character varying(20),
  UNIQUE (load_zone_id, name)
);

-----------------------------
-- Load time series
-----------------------------

CREATE TABLE demand_scenario
(
  demand_scenario_id smallint PRIMARY KEY,
  name character varying(30),
  description text
);

CREATE TABLE demand_timeseries
(
  load_zone_id smallint NOT NULL REFERENCES load_zone,
  demand_scenario_id smallint NOT NULL REFERENCES demand_scenario,
  raw_timepoint_id int NOT NULL REFERENCES raw_timepoint,
  load_zone_name character varying(30),
  timestamp_utc timestamp without time zone,
  demand_mw double precision NOT NULL,
  PRIMARY KEY (load_zone_id, demand_scenario_id, raw_timepoint_id),
  FOREIGN KEY (load_zone_id, load_zone_name )
      REFERENCES load_zone (load_zone_id, name),
  FOREIGN KEY (raw_timepoint_id, timestamp_utc )
      REFERENCES raw_timepoint (raw_timepoint_id, timestamp_utc)
);
COMMENT ON TABLE demand_timeseries
  IS 'Hourly demands in MW per load zone. Contains different demand scenarios. Note, the load_zone_name and 
  timestamp_utc are redundant with data in load_zone and raw_timepoint, and are provided for convenience. 
  The foreign key checks ensure these redundant data values match the data in their primary tables.';

-----------------------------
-- Transmission
-----------------------------

CREATE TABLE transmission_lines
(
  transmission_line_id serial NOT NULL PRIMARY KEY,
  start_load_zone_id smallint NOT NULL REFERENCES load_zone,
  end_load_zone_id smallint NOT NULL REFERENCES load_zone,
  trans_length_km double precision NOT NULL,
  trans_efficiency double precision,
  existing_trans_cap_mw double precision NOT NULL,
  new_build_allowed smallint NOT NULL,
  derating_factor double precision,
  terrain_multiplier double precision
);
COMMENT ON TABLE transmission_lines
  IS 'This table contains all transmission lines defined in the simulation, regardless if the transmission line 
  currently exists or is merely being proposed. Transmission lines must only be defined in one direction. 
  Switch will automatically augment the model to allow for Tx in both directions. ';

-----------------------------
-- Energy Sources
-----------------------------

CREATE TABLE energy_source
(
  name character varying(30) PRIMARY KEY,
  is_fuel boolean NOT NULL,
  co2_intensity double precision,
  upstream_co2_intensity double precision
);
COMMENT ON TABLE energy_source
  IS 'Contains fuels and non-fuel energy sources such as Solar or Wind. Fuels should specify their CO2 intensities, 
  and non-fuel energy sources should leave those columns empty.';

CREATE TABLE fuel_simple_price_scenario
(
  fuel_simple_price_scenario_id SMALLINT PRIMARY KEY,
  name text,
  description text
);

CREATE TABLE fuel_simple_price
(
  fuel character varying(30) NOT NULL REFERENCES energy_source (name),
  fuel_simple_price_scenario_id SMALLINT REFERENCES fuel_simple_price_scenario,
  load_zone_id smallint NOT NULL REFERENCES load_zone,
  load_zone_name character varying(30),
  projection_year smallint NOT NULL,
  fuel_price double precision NOT NULL,
  FOREIGN KEY (load_zone_id, load_zone_name )
      REFERENCES load_zone (load_zone_id, name)
);
COMMENT ON TABLE fuel_simple_price
    IS 'Yearly averaged prices for fuels without the complexity of a supply curve.';

-----------------------------
-- Generation projects (AKA Power Plants)
-----------------------------

CREATE TABLE generation_plant
(
  generation_plant_id INT PRIMARY KEY,
  name varchar(40) NOT NULL,
  gen_tech varchar(60) NOT NULL,
  load_zone_id INT NOT NULL REFERENCES load_zone,
  connect_cost_per_mw double precision NOT NULL,
  capacity_limit_mw double precision,
  variable_o_m double precision,
  forced_outage_rate double precision,
  scheduled_outage_rate double precision,
  full_load_heat_rate double precision,
  hydro_efficiency double precision,
  max_age INT NOT NULL,
  min_build_capacity double precision,
  is_variable boolean NOT NULL,
  is_baseload boolean NOT NULL,
  is_cogen boolean default FALSE,
  energy_source character varying(30) NOT NULL REFERENCES energy_source (name),
  unit_size double precision,
  storage_efficiency double precision,
  store_to_release_ratio double precision,
  min_load_fraction double precision,
  startup_fuel double precision,
  startup_om double precision,
  ccs_capture_efficiency double precision,
  ccs_energy_load double precision
);
COMMENT ON TABLE generation_plant
  IS 'Defines generation and/or storage projects. These may denote individual generating units, a power plant 
  that includes several generating units, or an aggregation of several different plants that can be dispatched 
  together without regard for unit commitment considerations. The columns without NOT NULL constraints are optional, 
  and should only be populated if that field is relevant for a particular generation project.';

CREATE TABLE generation_plant_scenario
(
  generation_plant_scenario_id SMALLINT PRIMARY KEY,
  name text,
  description text
);
COMMENT ON TABLE generation_plant_scenario
  IS 'Defines which set of generation projects to include in a particular SWITCH optimization. Use this to 
  enable/disable projects, aggregate projects for faster planning simulations without unit commitment, etc.';

CREATE TABLE generation_plant_scenario_member
(
  generation_plant_scenario_id SMALLINT NOT NULL REFERENCES generation_plant_scenario,
  generation_plant_id INT NOT NULL REFERENCES generation_plant,
  PRIMARY KEY(generation_plant_scenario_id, generation_plant_id)
);

CREATE TABLE generation_plant_cost_scenario
(
  generation_plant_cost_scenario_id SMALLINT PRIMARY KEY,
  name text,
  description text
);

CREATE TABLE generation_plant_cost
(
  generation_plant_cost_scenario_id SMALLINT REFERENCES generation_plant_cost_scenario,
  generation_plant_id INT NOT NULL REFERENCES generation_plant,
  build_year INT NOT NULL,
  fixed_o_m double precision,
  overnight_cost double precision,
  PRIMARY KEY (generation_plant_cost_scenario_id, generation_plant_id, build_year)
);


CREATE TABLE generation_plant_existing_and_planned_scenario
(
  generation_plant_existing_and_planned_scenario_id SMALLINT PRIMARY KEY,
  name text,
  description text
);

CREATE TABLE generation_plant_existing_and_planned
(
  generation_plant_existing_and_planned_scenario_id SMALLINT REFERENCES generation_plant_existing_and_planned_scenario,
  generation_plant_id INT NOT NULL REFERENCES generation_plant,
  build_year INT NOT NULL,
  capacity double precision,
  PRIMARY KEY (generation_plant_id, build_year)
);
COMMENT ON TABLE generation_plant_existing_and_planned
  IS 'Describes existing and planned projects according to the year they came online (build_year), and the capacity 
  that was brought online in that year.';
COMMENT ON COLUMN generation_plant_existing_and_planned.capacity
  IS 'Nameplate capacity in MW.';



CREATE TABLE variable_capacity_factors
(
  generation_plant_id INT NOT NULL REFERENCES generation_plant,
  raw_timepoint_id int NOT NULL REFERENCES raw_timepoint,
  timestamp_utc timestamp without time zone NOT NULL,
  capacity_factor double precision,
  PRIMARY KEY (generation_plant_id, raw_timepoint_id),
  FOREIGN KEY (raw_timepoint_id, timestamp_utc )
      REFERENCES raw_timepoint (raw_timepoint_id, timestamp_utc)
);
COMMENT ON TABLE variable_capacity_factors
  IS 'This contains historical time series of hourly capacity factors for variable renewable generators (wind, solar, etc).
   Multiplying these hourly capacity factors by the installed capacity will produce the hourly power output. This table 
   should store the historical data for one or more reference years. These values will be projected to future years when 
   a scenario is exported to SWITCH-pyomo input files.';
COMMENT ON COLUMN variable_capacity_factors.timestamp_utc IS 'This timestamp should be recorded in UTC. For regions that 
only span one time zone, this is less important. This should never contain daylight savings time because a time series 
specified in daylight savings time will drop one hour per year.';


CREATE TABLE hydro_simple_scenario
(
  hydro_simple_scenario_id SMALLINT PRIMARY KEY,
  name text,
  description text
);

CREATE TABLE hydro_flow_data
(
  hydro_simple_scenario_id SMALLINT REFERENCES hydro_simple_scenario,
  generation_plant_id INT NOT NULL REFERENCES generation_plant,
  sampled_timeseries_id int NOT NULL REFERENCES sampled_timeseries,
  hydro_min_flow_mw double precision,
  hydro_avg_flow_mw double precision
);


-----------------------------
-- Policies ... coming in the next round...
-----------------------------


-----------------------------
-- Concrete scenarios
-----------------------------

CREATE TABLE scenario
(
    scenario_id smallint PRIMARY KEY,
    name character varying(50),
    description text,
    study_timeframe_id SMALLINT NOT NULL REFERENCES study_timeframe,
    time_sample_id SMALLINT NOT NULL REFERENCES time_sample,
    demand_scenario_id SMALLINT NOT NULL REFERENCES demand_scenario,
    fuel_simple_price_scenario_id SMALLINT NOT NULL REFERENCES fuel_simple_price_scenario,
    generation_plant_scenario_id SMALLINT NOT NULL REFERENCES generation_plant_scenario,
    generation_plant_cost_scenario_id SMALLINT NOT NULL REFERENCES generation_plant_cost_scenario,
    generation_plant_existing_and_planned_scenario_id SMALLINT REFERENCES generation_plant_existing_and_planned_scenario,
    hydro_simple_scenario_id SMALLINT REFERENCES hydro_simple_scenario
);
COMMENT ON TABLE scenario
    IS 'This table defines the simulation parameters for a Switch Pyomo run. The get_switch_input_tables.sh 
    script pulls the chosen data into the tab and dat files the model requires. It parses command line arguments 
    and looks for the "s" option, which specifies the simulations scenario. That id is used as a key to read this 
    table and extract all other ids. All of the id columns reference the tables where the parameters are described. 
    They will update if you update those values and will raise an error when you try to delete an id that is still 
    being used in some scenario in this table.';

