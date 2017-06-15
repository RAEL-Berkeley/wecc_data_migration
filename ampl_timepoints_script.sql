

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
