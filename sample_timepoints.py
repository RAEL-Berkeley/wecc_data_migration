#!/usr/bin/env python 
# -*- coding: utf-8 -*-
# Copyright 2017 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.
# Renewable and Appropriate Energy Laboratory, UC Berkeley.
# Operations, Control and Markets laboratory at Pontificia Universidad
# Católica de Chile.
"""
Sample timepoints based on loads.
"""
# Built-in libraries
from __future__ import print_function

import argparse
import os
import sys
import time

# 3rd party libraries
import pandas as pd

# our code
import db_utils


def main():
    start_time = time.time()
    parser = get_parser()
    args = parser.parse_args()
    db_connection = db_utils.connect(args)

    if args.command == 'define_study_timeframe':
        study_timeframe_id = define_study_timeframe(db_connection,
            args.study_timeframe_name, args.study_timeframe_description,
            args.study_start_year, args.years_per_period, args.n_periods)
        if study_timeframe_id:
            print("Created study timeframe. id=", study_timeframe_id)
        return
    elif args.command == 'sample_timeseries':
        print('got sample_timeseries')
        return

    demand_scenario          = args.demand_scenario
    month_sampling_frequency = args.month_sampling_frequency
    start_month              = args.start_month
    hour_sampling_frequency  = args.hour_sampling_frequency
    start_hour               = args.start_hour
    
    
    """
    demand_scenario
        demand_timeseries (ref raw_timepoint)
    study_timeframe
      period
      period_all_timeseries
        raw_timeseries
            raw_timepoint
    SELECT *
    FROM switch.period
        JOIN switch.period_all_timeseries USING (period_id)
        JOIN switch.raw_timepoint USING (raw_timeseries_id)
        JOIN switch.demand_timeseries USING (raw_timepoint_id)
    WHERE demand_scenario_id = 31
        and period.study_timeframe_id = 1
    limit 10;
    
    INSERT INTO time_sample(
            time_sample_id, study_timeframe_id, name, method, description)
    VALUES (?, ?, ?, ?, ?);

    """

    sql = ("SELECT * FROM switch.demand_scenario WHERE demand_scenario_id = {}"
          ).format(args.demand_scenario)
    print(sql)
    
    df = pd.read_sql(sql, db_connection)
    print("demand_scenario: ", df)

    end_time = time.time()

    print('\nScript ran in %s seconds.' % (end_time-start_time))


def define_study_timeframe(db_connection, name, description, study_start_year, years_per_period, n_periods):
    cursor = db_connection.cursor()
    existing_study_timeframe = lookup_study_timeframe(
        db_connection, study_start_year, years_per_period, n_periods
    )
    if len(existing_study_timeframe) > 0:
        print('Found existing study timeframe with the requested period definitions:')
        print(existing_study_timeframe)
        return
    sql = """
        INSERT INTO study_timeframe(name, description)
        VALUES (%s, %s)
        RETURNING study_timeframe_id;
    """
    cursor.execute(sql, (name, description))
    study_timeframe_id = cursor.fetchone()[0]
    sql = """
        INSERT INTO period(study_timeframe_id, start_year, label, length_yrs, end_year)
        SELECT %(study_timeframe_id)s, 
            period_start_year,
            period_start_year as label,
            %(years_per_period)s as length_yrs,
            period_start_year + %(years_per_period)s - 1 as end_year
        FROM generate_series(
            %(study_start_year)s,
            %(study_start_year)s + %(years_per_period)s*(%(n_periods)s - 1),
            %(years_per_period)s
        ) as period_start_year;
    """
    cursor.execute(sql, {
        'study_timeframe_id': study_timeframe_id,
        'study_start_year': study_start_year,
        'years_per_period': years_per_period, 
        'n_periods': n_periods
    })
    sql = """
        INSERT INTO period_all_timeseries(study_timeframe_id, period_id, raw_timeseries_id)
        SELECT %(study_timeframe_id)s, period_id, raw_timeseries_id
        FROM period, raw_timeseries
        WHERE raw_timeseries.start_year >= period.start_year AND
            raw_timeseries.end_year <= period.end_year AND
            period.study_timeframe_id = %(study_timeframe_id)s;
    """
    cursor.execute(sql, {'study_timeframe_id': study_timeframe_id })


    db_connection.commit()
    cursor.close()
    
    return study_timeframe_id


def lookup_study_timeframe(db_connection, study_start_year, years_per_period, n_periods):
    sql = """
        select study_timeframe_id, study_timeframe.name, study_timeframe.description
        from period
            JOIN study_timeframe USING (study_timeframe_id)
        group by 1, 2, 3
        having variance(length_yrs) =0 and 
            min(start_year)  = %(study_start_year)s and
            avg(length_yrs) = %(years_per_period)s and
            count(start_year) = %(n_periods)s 
        ;"""
    existing_study_timeframe = pd.read_sql(sql, db_connection,
        params={
            'study_start_year': study_start_year,
            'years_per_period': years_per_period,
            'n_periods': n_periods
        },
        index_col='study_timeframe_id'
    )
    return existing_study_timeframe


def _short_int_arg(parser, name, default, help=' '):
    """
    A wrapper providing concise syntax for adding a short integer command line
    argument to an argparser.
        short_int_arg('n_periods', 4)
    """
    name_as_cli_arg = '--' + name
    parser.add_argument(
        name_as_cli_arg,
        dest=name,
        default=default,
        type=int,
        help=help
    )


def get_parser():
    parser = argparse.ArgumentParser(
        description=('Take a representative sampling of timepoints'),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    
    subparsers = parser.add_subparsers(dest="command")

    define_study_timeframe_parser = subparsers.add_parser('define_study_timeframe',
        help='Define a study timeframe (set of investment periods)',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    db_utils.add_CLI_args(define_study_timeframe_parser)
    _short_int_arg(define_study_timeframe_parser, 'study_start_year', 2020)
    _short_int_arg(define_study_timeframe_parser, 'years_per_period', 10)
    _short_int_arg(define_study_timeframe_parser, 'n_periods', 4)
    define_study_timeframe_parser.add_argument(
        '--name', dest='study_timeframe_name')
    define_study_timeframe_parser.add_argument(
        '--description', dest='study_timeframe_description')


    sample_timeseries_parser = subparsers.add_parser('sample_timeseries',
        help='Perform statistical sampling from an extensive timeseries for a study timeframe',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    db_utils.add_CLI_args(sample_timeseries_parser)
    sample_timeseries_parser.add_argument(
        '--study_timeframe', dest='study_timeframe', type=int, 
        required=True, metavar='id',
        help='Study timeframe ID.')
    sample_timeseries_parser.add_argument(
        '--demand_scenario', dest='demand_scenario', type=int, 
        required=True, metavar='scenario_id',
        help='Demand scenario ID for sampling.')
    _short_int_arg(sample_timeseries_parser, 'month_sampling_frequency', 1,
        help='Whether to sample every month, every 2 months, etc.'
    )
    _short_int_arg(sample_timeseries_parser, 'start_month', 1,
        help=('Month number to start sampling, 1-12 '
              '(should be less than month_sampling_frequency)'))
    _short_int_arg(sample_timeseries_parser, 'hour_sampling_frequency', 4,
        help='Whether to sample every hour of a day, every 2 hours, etc.'
    )
    _short_int_arg(sample_timeseries_parser, 'start_hour', 2,
        help=('Hour number to start sampling at, 0-23 '
              '(should be less than hour_sampling_frequency)'))
    
    return parser


if __name__ == "__main__":
    main()
