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
import db_connect

start_time = time.time()

def main():
    global db_cursor
    global tunnel
    global db_connection
    parser = argparse.ArgumentParser(
        description=('Take a representative sampling of timepoints'),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        '-d', '--demand-scenario', dest='demand_scenario', type=int, 
        required=True, metavar='scenario_id',
        help='Demand scenario ID for sampling.')
    db_connect.add_CLI_args(parser)
    args = parser.parse_args()
    db_connect.connect(args)
#     db = db_connect.db_cursor

    ##############################################################################
    # These next variables determine which input data is used, though some are
    # only for documentation and result exports.
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
#     db.execute(sql)
#     print("demand_scenario: ", db.fetchone())

    result = db_connect.connection.execute(sql)
    print("demand_scenario: ", [r for r in result])
    
    df = pd.read_sql(sql, db_connect.connection)
    print("demand_scenario: ", df)

    db_connect.shutdown()
    exit()

    print('  periods.tab...')
    db.execute(("""select label, start_year as period_start, end_year as period_end
                    from period where study_timeframe_id={id}
                    oder by 1;
                    """).format(id=study_timeframe_id))         
    # write_tab('periods', ['INVESTMENT_PERIOD', 'period_start', 'period_end'], db)

    # Clean-up
    # db_connect.shutdown()

    end_time = time.time()

    print('\nScript took %s seconds building input tables.' % (end_time-start_time))

if __name__ == "__main__":
    main()
