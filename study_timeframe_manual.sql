


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
    VALUES (3, 1, 2016, 2020, 10, 2025),
           (3, 2, 2026, 2030, 10, 2035),
           (3, 3, 2036, 2040, 10, 2045),
           (3, 4, 2046, 2050, 10, 2055),
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



    
    
    
    
    
    
    
    
    
    
    
    