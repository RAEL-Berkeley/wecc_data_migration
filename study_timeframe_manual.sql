-- A one-off study timeframe and time sampling for debugging

-- Defines investment periods and all known timeseries/points that fall in each period
INSERT INTO study_timeframe(
            study_timeframe_id, name, description)
    VALUES (1,'Debugging timeframe','Built for debugging');

INSERT INTO period(
            study_timeframe_id, period_id, start_year, label, length_yrs)
    VALUES (1, 1, 2020, 2020, 5),
           (1, 2, 2025, 2025, 5),
    ;

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
