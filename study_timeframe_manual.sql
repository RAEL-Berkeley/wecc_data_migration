


-- A one-off study timeframe and time sampling for debugging ------------------------------

-------------------------------------------------------------------------------------------

-- Defines investment periods and all known timeseries/points that fall in each period
INSERT INTO study_timeframe(
            study_timeframe_id, name, description)
    VALUES (1,'Debugging timeframe','Built for debugging');

INSERT INTO period(
            study_timeframe_id, period_id, start_year, label, length_yrs)
    VALUES (1, 1, 2020, 2020, 5),
           (1, 2, 2025, 2025, 5),
    ;
-- Paty's addition for simplicity of other queries
alter table period add column end_year INT;
update period set end_year = 2024 where start_year = 2020;
update period set end_year = 2029 where start_year = 2025;


INSERT INTO period_all_timeseries(
    study_timeframe_id, period_id, raw_timeseries_id)
SELECT study_timeframe_id, period_id, raw_timeseries_id
    FROM study_timeframe
    JOIN period USING(study_timeframe_id)
    JOIN raw_timeseries ON(raw_timeseries.start_year >= period.start_year  and 
                           raw_timeseries.end_year <= period.start_year + period.length_yrs - 1)
;

-- A particular sample from a study timeframe that will be used for investment optimization
INSERT INTO time_sample(
            time_sample_id, study_timeframe_id, name, method, description)
    VALUES (1,1,'Debugging','Hand picked','We picked certain timepoints just for debugging purposes');
-- Timeseries included in this sample: 2 days for the first period, and 1 day for the second.
INSERT INTO sampled_timeseries(
            sampled_timeseries_id, study_timeframe_id, time_sample_id, period_id, 
            name, hours_per_tp, num_timepoints, first_timepoint_utc, last_timepoint_utc, 
            scaling_to_period)
    VALUES (1, 1, 1, 1, 
            'Winter day', 2, 12, '2022-01-01 08:00:00', '2022-01-02 07:00:00', 
            365/2.0 * 5),
           (2, 1, 1, 1, 
            'Summer day', 2, 12, '2022-07-01 08:00:00', '2022-07-02 07:00:00', 
            365/2.0 * 5),
           (3, 1, 1, 2, 
            'Spring day', 2, 12, '2027-04-01 08:00:00', '2027-04-02 07:00:00', 
            365 * 5);
INSERT INTO sampled_timepoint(
            raw_timepoint_id, study_timeframe_id, time_sample_id, sampled_timeseries_id, 
            period_id, timestamp_utc)
SELECT raw_timepoint_id, study_timeframe.study_timeframe_id, 1 AS time_sample_id, sampled_timeseries_id,
    period_all_timeseries.period_id, raw_timepoint.timestamp_utc
FROM raw_timepoint
    JOIN period_all_timeseries USING(raw_timeseries_id)
    JOIN study_timeframe USING(study_timeframe_id),
    sampled_timeseries
WHERE study_timeframe.study_timeframe_id = 1
    AND sampled_timeseries.time_sample_id = 1
    AND raw_timepoint.timestamp_utc >= sampled_timeseries.first_timepoint_utc
    AND raw_timepoint.timestamp_utc <= sampled_timeseries.last_timepoint_utc
    AND extract('hour' from 
            raw_timepoint.timestamp_utc - sampled_timeseries.first_timepoint_utc
           )::int % hours_per_tp::int = 0;



-- Another study timeframe for more debugging. Not for now: 8AM of Jan 1st is a complicated hour (might have bot been sampled)

------------------------------------------------------------------------------------------------------------------------

-- Defines investment periods and all known timeseries/points that fall in each period
INSERT INTO study_timeframe(
            study_timeframe_id, name, description)
    VALUES (2,'Debugging timeframe','Built for debugging without 01-01-8AM');

INSERT INTO period(
            study_timeframe_id, period_id, start_year, label, length_yrs, end_year)
    VALUES (2, 3, 2020, 2020, 5, 2024),
           (2, 4, 2025, 2025, 5, 2029)
    ;


INSERT INTO period_all_timeseries(
    study_timeframe_id, period_id, raw_timeseries_id)
SELECT study_timeframe_id, period_id, raw_timeseries_id
    FROM study_timeframe
    JOIN period USING(study_timeframe_id)
    JOIN raw_timeseries ON(raw_timeseries.start_year >= period.start_year  and 
                           raw_timeseries.end_year <= period.start_year + period.length_yrs - 1)
    where study_timeframe_id=2
;

-- A particular sample from a study timeframe that will be used for investment optimization
INSERT INTO time_sample(
            time_sample_id, study_timeframe_id, name, method, description)
    VALUES (2,2,'Debugging2','Hand picked','We picked certain timepoints just for debugging purposes without 01-01-8AM');
-- Timeseries included in this sample: 2 days for the first period, and 1 day for the second.
INSERT INTO sampled_timeseries(
            sampled_timeseries_id, study_timeframe_id, time_sample_id, period_id, 
            name, hours_per_tp, num_timepoints, first_timepoint_utc, last_timepoint_utc, 
            scaling_to_period)
    VALUES (4, 2, 2, 3, 
            'Winter day', 2, 12, '2022-02-01 08:00:00', '2022-02-02 07:00:00', 
            365/2.0 * 5),
           (5, 2, 2, 3, 
            'Summer day', 2, 12, '2022-07-01 08:00:00', '2022-07-02 07:00:00', 
            365/2.0 * 5),
           (6, 2, 2, 4, 
            'Spring day', 2, 12, '2027-04-01 08:00:00', '2027-04-02 07:00:00', 
            365 * 5);
INSERT INTO sampled_timepoint(
            raw_timepoint_id, study_timeframe_id, time_sample_id, sampled_timeseries_id, 
            period_id, timestamp_utc)
SELECT raw_timepoint_id, study_timeframe.study_timeframe_id, 2 AS time_sample_id, sampled_timeseries_id,
    period_all_timeseries.period_id, raw_timepoint.timestamp_utc
FROM raw_timepoint
    JOIN period_all_timeseries USING(raw_timeseries_id)
    JOIN study_timeframe USING(study_timeframe_id),
    sampled_timeseries
WHERE study_timeframe.study_timeframe_id = 2
    AND sampled_timeseries.time_sample_id = 2
    AND raw_timepoint.timestamp_utc >= sampled_timeseries.first_timepoint_utc
    AND raw_timepoint.timestamp_utc <= sampled_timeseries.last_timepoint_utc
    AND extract('hour' from 
            raw_timepoint.timestamp_utc - sampled_timeseries.first_timepoint_utc
           )::int % hours_per_tp::int = 0;
           
           
           
           
           
-- Old AMPL study timeframe -------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------

-- Defines investment periods and all known timeseries/points that fall in each period
INSERT INTO study_timeframe(
            study_timeframe_id, name, description)
    VALUES (3,'Old AMPL timeframe','training_set_id=1112 from AMPL runs');

INSERT INTO period(
            study_timeframe_id, period_id, start_year, label, length_yrs, end_year)
    VALUES (3, 5, 2016, 2020, 10, 2025),
           (3, 6, 2026, 2030, 10, 2035),
           (3, 7, 2036, 2040, 10, 2045),
           (3, 8, 2046, 2050, 10, 2055),
    ;
    
    
INSERT INTO period_all_timeseries(
    study_timeframe_id, period_id, raw_timeseries_id)
SELECT study_timeframe_id, period_id, raw_timeseries_id
    FROM study_timeframe
    JOIN period USING(study_timeframe_id)
    JOIN raw_timeseries ON(raw_timeseries.start_year >= period.start_year  and 
                           raw_timeseries.end_year <= period.start_year + period.length_yrs - 1)
    where study_timeframe_id=3
;


create table if not exists ampl_timepoints_1112 (
timepoint_id INT, 
hour INT,
period INT,
date INT,
hours_in_sample DOUBLE PRECISION,
month_of_year INT,
hour_of_day INT,
PRIMARY KEY (timepoint_id)
);


COPY ampl_timepoints_1112 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_timepoints_1112.csv'  
DELIMITER ',' CSV HEADER;


-- A particular sample from a study timeframe that will be used for investment optimization
INSERT INTO time_sample(
            time_sample_id, study_timeframe_id, name, method, description)
    VALUES (3,3,'AMPL timepoints','AMPL method','training_set_id=1112 from AMPL. 576 timepoints');


--ampl_sampled_timeseries_from_AMPL.csv
create table if not exists ampl_sampled_timeseries_from_AMPL (
sampled_timeseries_id INT, 
study_timeframe_id INT,
time_sample_id INT,
period_id INT,
name VARCHAR,
hours_per_tp INT,
num_timepoints INT,
first_timepoint_utc timestamp,
last_timepoint_utc timestamp,
scaling_to_period DOUBLE PRECISION,
hours_in_sample DOUBLE PRECISION
);


COPY ampl_sampled_timeseries_from_AMPL 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_sampled_timeseries_from_AMPL.csv'  
DELIMITER ',' CSV HEADER;


-- scaling_to_period notes: (4*6* 365*10*2/(12.0*30)) peak day   +   4*6*365*10*28/(12.0*30)) median day  ) * 12 months = 87000 hours in 10 years
-- The sum of hours_per_tp * num_timepoints * scaling_to_period for all timeseries in a period should equal the 
-- number of hours in that period.';
INSERT INTO sampled_timeseries(
            sampled_timeseries_id, study_timeframe_id, time_sample_id, period_id, 
            name, hours_per_tp, num_timepoints, first_timepoint_utc, last_timepoint_utc, 
            scaling_to_period)
SELECT sampled_timeseries_id, study_timeframe_id, time_sample_id, period_id, name, hours_per_tp, num_timepoints, 
		first_timepoint_utc, last_timepoint_utc, scaling_to_period
FROM ampl_sampled_timeseries_from_AMPL;
        
        
create table if not exists ampl_mapping_table_timeframe_AMPL (
timepoint_id INT,
datetime_utc timestamp
);

COPY ampl_mapping_table_timeframe_AMPL 
FROM '/var/tmp/home_pehidalg/tables_from_mysql/ampl_mapping_table_timeframe_AMPL.csv'  
DELIMITER ',' CSV HEADER;

        
-- JOIN did not work, so I'm adding columns to join to avoid suing functions in the join clause
alter table ampl_timepoints_1112 add column timestamp_utc timestamp;


-- update later: sampled_timeseries_id
INSERT INTO sampled_timepoint(
            raw_timepoint_id, study_timeframe_id, time_sample_id,
            period_id, timestamp_utc)
SELECT  timepoint_id as raw_timepoint_id, 
		3 as study_timeframe_id, 
		3 as time_sample_id, 
		(case when period = 2016 then 5
            when period = 2026 then 6
            when period = 2036 then 7
            when period = 2046 then 8
            else -1 end) as period_id, 
       	datetime_utc as timestamp_utc
FROM ampl_timepoints_1112
JOIN ampl_mapping_table_timeframe_AMPL USING(timepoint_id)
ORDER BY timepoint_id;


update sampled_timepoint set sampled_timeseries_id= (select sampled_timeseries_id 
														from sampled_timeseries 
														where sampled_timepoint.timestamp_utc >= first_timepoint_utc 
														and sampled_timepoint.timestamp_utc <= last_timepoint_utc 
														group by sampled_timeseries_id) where raw_timepoint_id=88010 and study_timeframe_id=3 and time_sample_id=3;

 
do $$
  declare
    arow record;
    foo int;
  begin
    for arow in
      (select raw_timepoint_id 
	from sampled_timepoint 
	where study_timeframe_id=3 and  time_sample_id=3 order by raw_timepoint_id) 
    loop
      update sampled_timepoint set sampled_timeseries_id= (select sampled_timeseries_id 
														from sampled_timeseries 
														where sampled_timepoint.timestamp_utc >= first_timepoint_utc 
														and sampled_timepoint.timestamp_utc <= last_timepoint_utc 
														group by sampled_timeseries_id) where raw_timepoint_id=arow.raw_timepoint_id and study_timeframe_id=3 and time_sample_id=3;

    end loop;
  end;
$$;


 















