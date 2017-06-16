

select * from training_sets where training_set_id = 1112;


select * from training_set_periods where training_set_id=1112;


SELECT 
  timepoint_id,
  DATE_FORMAT(datetime_utc,'%Y%m%d%H') AS hour, period, 
  DATE_FORMAT(datetime_utc,'%Y%m%d') AS date, hours_in_sample, 
  MONTH(datetime_utc) AS month_of_year, HOUR(datetime_utc) as hour_of_day 
FROM _training_set_timepoints JOIN study_timepoints  USING (timepoint_id) 
WHERE training_set_id=1112
order by 1;


SELECT 
  timepoint_id,
  datetime_utc, period, 
  DATE_FORMAT(datetime_utc,'%Y%m%d') AS date, hours_in_sample, 
  MONTH(datetime_utc) AS month_of_year, HOUR(datetime_utc) as hour_of_day 
FROM _training_set_timepoints JOIN study_timepoints  USING (timepoint_id) 
WHERE training_set_id=1112
order by 1;



select 	3 as study_timeframe_id,
        3 as time_sample_id,
        (case when w.period = 2016 then 5
            when w.period = 2026 then 6
            when w.period = 2036 then 7
            when w.period = 2046 then 8
            else -1 end) as period_id, 
		date as name,
		4 as hours_per_tp,
		6 as num_timepoints,
		min(w.datetime_utc) as first_timepoint_utc,
		max(w.datetime_utc) as last_timepoint_utc,
        if(w.hours_in_sample < 1000, 365*10*2/(12.0*30), 365*10*28/(12.0*30)) as scaling_to_period,
        hours_in_sample
from  (SELECT 
  timepoint_id,
  datetime_utc, period, 
  DATE_FORMAT(datetime_utc,'%Y%m%d') AS date, hours_in_sample, 
  MONTH(datetime_utc) AS month_of_year, HOUR(datetime_utc) as hour_of_day 
FROM _training_set_timepoints JOIN study_timepoints  USING (timepoint_id) 
WHERE training_set_id=1112
order by 1) as w
group by w.period, w.month_of_year, w.date, w.hours_in_sample;

-- -- example:
-- SELECT
--    (@cnt := @cnt + 1) AS rowNumber,
--    t.rowID
-- FROM myTable AS t
--  CROSS JOIN (SELECT @cnt := 0) AS dummy
-- WHERE t.CategoryID = 1
-- ORDER BY t.rowID ;

-- ampl_sampled_timeseries_from_AMPL.csv sent to db2
select 	(@cnt := @cnt + 1)  as sampled_timeseries_id,
		3 as study_timeframe_id,
        3 as time_sample_id,
        (case when w.period = 2016 then 5
            when w.period = 2026 then 6
            when w.period = 2036 then 7
            when w.period = 2046 then 8
            else -1 end) as period_id, 
		concat(substring(date,1,4),'-', substring(date,5,2), '-', substring(date,7,2))as name,
		4 as hours_per_tp,
		6 as num_timepoints,
		min(w.datetime_utc) as first_timepoint_utc,
		max(w.datetime_utc) as last_timepoint_utc,
        if(w.hours_in_sample < 1000, 365*10*2/(12.0*30), 365*10*28/(12.0*30)) as scaling_to_period,
        hours_in_sample
from  (SELECT 
  timepoint_id,
  datetime_utc, period, 
  DATE_FORMAT(datetime_utc,'%Y%m%d') AS date, hours_in_sample, 
  MONTH(datetime_utc) AS month_of_year, HOUR(datetime_utc) as hour_of_day 
FROM _training_set_timepoints JOIN study_timepoints  USING (timepoint_id) 
WHERE training_set_id=1112
order by 1) as w
CROSS JOIN (SELECT @cnt := 6) AS dummy
group by w.period, w.month_of_year, w.date, w.hours_in_sample;


-- mapping table
SELECT 
  timepoint_id,
  datetime_utc
FROM _training_set_timepoints JOIN study_timepoints  USING (timepoint_id) 
WHERE training_set_id=1112
order by 1;

