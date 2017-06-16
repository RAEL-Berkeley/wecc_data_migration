# -*- coding: utf-8 -*-
# Copyright 2017 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.
# Renewable and Appropriate Energy Laboratory, UC Berkeley.
# Operations, Control and Markets laboratory at Pontificia Universidad
# Católica de Chile.
"""
Sample timepoints based on loads.
"""
from __future__ import print_function

import argparse
import atexit
import getpass
import os
import sys
import time

import pandas as pd
import pgpasslib
import psycopg2
import sshtunnel


start_time = time.time()

# Variables that will need to be cleaned up when the program exists.
db_connection = None
db_cursor = None
tunnel = None

def shutdown():
    global db_cursor
    global db_connection
    global tunnel
    if db_cursor:
        db_cursor.close()
        db_cursor = None
    if db_connection:
        db_connection.close()
        db_connection = None
    if tunnel:
        tunnel.stop()
        tunnel = None
atexit.register(shutdown)


def main():
    global db_cursor
    global tunnel
    global db_connection
    parser = argparse.ArgumentParser(
        description=(''),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        '-H', '--hostname', dest="db_hostname", type=str, 
        default='switch-db2.erg.berkeley.edu', metavar='hostname', 
        help='Database address (IP or complete domain name)')
    parser.add_argument(
        '-P', '--port', dest="port", type=int, default=5432, metavar='port',
        help='Database host port')
    parser.add_argument(
        '-U', '--user', dest='user', type=str, default=getpass.getuser(), metavar='username',
        help='Database username (Needs to be the same as the system username for ssh tunnelling).')
    parser.add_argument(
        '-D', '--database', dest='database', type=str, default='switch_wecc', metavar='dbname',
        help='Database name')
    parser.add_argument(
        '-d', '--demand-scenario', dest='demand_scenario', type=int, 
        required=True, metavar='scenario_id',
        help='Demand scenario ID for sampling.')
    parser.add_argument(
        '--pgpass', dest='pgpass', action='store_true', default=False,
        help='Demand scenario ID for sampling.')

    args = parser.parse_args()

    if args.pgpass:
        passw = pgpasslib.getpass(args.db_hostname, args.port, args.database, args.user)
    else:
        passw = getpass.getpass(
            ('Enter database password for user {}, or press enter to read '
             'from ~/.pgpass: ').format(args.user))
        if not passw:
            passw = pgpasslib.getpass(args.db_hostname, args.port, args.database, args.user)


    # Start an ssh tunnel because the database only permits local connections
    tunnel = sshtunnel.SSHTunnelForwarder(
        ssh_address=args.db_hostname,
        ssh_username=args.user,
        ssh_pkey= os.path.expanduser('~') + "/.ssh/id_rsa",
        remote_bind_address=('127.0.0.1', args.port)
    )
    tunnel.start()
    # If the db connection fails and raises an exception, I have to stop the ssh
    # tunnel before proceeding or else it will hang indefinitely. The ssh tunnel
    # library is not well-behaved!
    try:
        db_connection = psycopg2.connect(database=args.database, user=args.user,
                                         host='127.0.0.1', port=tunnel.local_bind_port,
                                         password=passw)
    except:
        tunnel.stop()
        raise
    db_cursor = db_connection.cursor()
    db = db_cursor

    ##############################################################################
    # These next variables determine which input data is used, though some are
    # only for documentation and result exports.

    sql = ("SELECT * FROM switch.demand_scenario WHERE demand_scenario_id = {}"
          ).format(args.demand_scenario)
    print(sql)
    db.execute(sql)
    print("demand_scenario", db.fetchone())
    shutdown()
    exit()

    print('  periods.tab...')
    db.execute(("""select label, start_year as period_start, end_year as period_end
                    from period where study_timeframe_id={id}
                    oder by 1;
                    """).format(id=study_timeframe_id))         
    # write_tab('periods', ['INVESTMENT_PERIOD', 'period_start', 'period_end'], db)

    # Clean-up
    # shutdown()

    end_time = time.time()

    print('\nScript took %s seconds building input tables.' % (end_time-start_time))

if __name__ == "__main__":
    main()
