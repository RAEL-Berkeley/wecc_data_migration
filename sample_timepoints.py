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

start_time = time.time()

def main():
    parser = argparse.ArgumentParser(
        description=('Take a representative sampling of timepoints'),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        '-d', '--demand-scenario', dest='demand_scenario', type=int, 
        required=True, metavar='scenario_id',
        help='Demand scenario ID for sampling.')
    db_utils.add_CLI_args(parser)
    args = parser.parse_args()
    db_connection = db_utils.connect(args)

    demand_scenario = args.demand_scenario
    
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
    """

    sql = ("SELECT * FROM switch.demand_scenario WHERE demand_scenario_id = {}"
          ).format(args.demand_scenario)
    print(sql)
    
    df = pd.read_sql(sql, db_connection)
    print("demand_scenario: ", df)

    end_time = time.time()

    print('\nScript ran in %s seconds.' % (end_time-start_time))

if __name__ == "__main__":
    main()
