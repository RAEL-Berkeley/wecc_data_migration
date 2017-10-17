"""
Utilities for establishing a database connection.

SYNOPSIS
    import argparse
    import db_utils
    import pandas
    parser = argparse.ArgumentParser(description="This script does X...")
    db_utils.add_CLI_args(parser)
    # Add script-specific arguments to parser...
    args = parser.parse_args()
    db_connection = db_utils.connect(args)

    sql = "SELECT 1 AS a, 2 AS b;"
    db_connection.execute(sql)
    pandas_dataframe = pandas.read_sql(sql, db_connection)

"""
# Built-in libraries
from __future__ import print_function

import atexit
import getpass
import os
import random
import signal
import sys
try:
    import SocketServer
except ImportError:
    import socketserver as SocketServer
import subprocess
import tempfile

# 3rd party libraries
import pgpasslib
import psycopg2


# Global variables (in this module) that store database connection info.
# These need to be cleaned up when the program exists.
engine = None 
db_connection = None
ssh_conf = {}

def shutdown():
    global db_connection
    global ssh_conf
    if db_connection:
        db_connection.close()
        db_connection = None
    if ssh_conf:
        subprocess.check_call(['ssh', '-S', ssh_conf['socket'], '-O', 'exit', ssh_conf['host']])
        ssh_conf = {}
atexit.register(shutdown)

def add_CLI_args(parser):
    """
    Command-line arguments for setting up a database connection.
    """
    parser.add_argument(
        '-H', '--hostname', dest="db_hostname", type=str, 
        default='switch-db2.erg.berkeley.edu', metavar='hostname', 
        help='Database address (IP or complete domain name)')
    parser.add_argument(
        '-P', '--port', dest="db_port", type=int, default=5432, metavar='port',
        help='Database host port')
    parser.add_argument(
        '--skip-ssh-tunnel', dest="skip_ssh_tunnel", 
        default=False, action='store_true',
        help='Do not initiate an ssh tunnel for the database connection.')
    parser.add_argument(
        '-U', '--user', dest='db_user', type=str, default=getpass.getuser(), metavar='username',
        help='Database username.')
    parser.add_argument(
        '--ssh-user', dest='ssh_user', type=str, default=None,
        help='System username (for ssh tunnelling); defaults to database username.')
    parser.add_argument(
        '-D', '--database', dest='database', type=str, default='switch_wecc', metavar='dbname',
        help='Database name')


def connect(args):
    """ 
    Connect to the database and save the connection as the global variable
    'connection'. 
    """
    global engine
    global db_connection
    global ssh_conf

    # Try getting a password from ~/.pgpass before asking the user to type it.
    passw = pgpasslib.getpass(
        args.db_hostname, args.db_port, args.database, args.db_user)
    if not passw:
        passw = getpass.getpass(
            'Enter database password for user {}'.format(args.db_user))

    if args.skip_ssh_tunnel:
        host = args.db_hostname
        port = args.db_port
    else:
        ssh_conf['socket'] = tempfile.NamedTemporaryFile().name
        ssh_conf['host'] = args.db_hostname
        local_port = random.randint(10000,60000)
        if args.ssh_user is None:
            args.ssh_user = args.db_user
        exit_status = subprocess.call(['ssh', '-MfN',
            '-S', ssh_conf['socket'],
            '-L', '{}:{}:{}'.format(local_port, '127.0.0.1', args.db_port),
            '-o', 'ExitOnForwardFailure=yes',
            args.ssh_user + '@' + args.db_hostname
        ])
        if exit_status != 0:
            raise Exception('SSH tunnel failed with status: {}'.format(exit_status))
        host='127.0.0.1'
        port=local_port
    db_connection = psycopg2.connect(
        dbname=args.database,
        user=args.db_user,
        password=passw,
        host=host,
        port=port
    )
    return db_connection
