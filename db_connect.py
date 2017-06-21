"""

"""
# Built-in libraries
from __future__ import print_function

import argparse
import atexit
import getpass
import os

# 3rd party libraries
import pgpasslib
# import psycopg2 
import sshtunnel

# Do we want to use psycopg2 directly or sqlalchemy with pandas integration?
from sqlalchemy import create_engine

# Global variables (in this module) that store database connection info.
# These need to be cleaned up when the program exists.
# db_connection = None
# db_cursor = None
tunnel = None
# sqlalchemy
engine = None 
connection = None

def shutdown():
#     global db_cursor
#     global db_connection
    global tunnel
    global connection
#     if db_cursor:
#         db_cursor.close()
#         db_cursor = None
#     if db_connection:
#         db_connection.close()
#         db_connection = None
    if connection:
        connection.close()
        connection = None
    if tunnel:
        tunnel.stop()
        tunnel = None
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
    """ Connect to the database with psycopg2 and set global variables """
#     global db_cursor
#     global db_connection
    global tunnel
    global engine
    global connection

    # Try getting a password from ~/.pgpass before asking the user to type it.
    passw = pgpasslib.getpass(
        args.db_hostname, args.db_port, args.database, args.db_user)
    if not passw:
        passw = getpass.getpass(
            'Enter database password for user {}'.format(args.db_user))

    if args.skip_ssh_tunnel:
#         db_connection = psycopg2.connect(
#             host=args.db_hostname, port=args.db_port,
#             database=args.database, user=args.db_user, password=passw)
        engine = create_engine(
            'postgresql://{user}:{passw}@{host}:{port}/{db_name}'.format(
                user=args.db_user,
                passw=passw,
                host=args.db_hostname,
                port=args.db_port,
                db_name=args.database ))
    else:
        if args.ssh_user is None:
            args.ssh_user = args.db_user
        ssh_pkey_path = os.path.join(os.path.expanduser('~'), ".ssh", "id_rsa")
        tunnel = sshtunnel.SSHTunnelForwarder(
            ssh_address=args.db_hostname,
            ssh_username=args.ssh_user,
            ssh_pkey=ssh_pkey_path,
            remote_bind_address=('127.0.0.1', args.db_port)
        )
        tunnel.start()
        # If the db connection fails and raises an exception, I have to stop the ssh
        # tunnel before proceeding or else it will hang indefinitely. The ssh tunnel
        # library is not well-behaved!
        try:
#             db_connection = psycopg2.connect(
#                 host='127.0.0.1', port=tunnel.local_bind_port,
#                 database=args.database, user=args.db_user, password=passw)
            engine = create_engine(
                'postgresql://{user}:{passw}@{host}:{port}/{db_name}'.format(
                    user=args.db_user,
                    passw=passw,
                    host='127.0.0.1',
                    port=tunnel.local_bind_port,
                    db_name=args.database ))
        except:
            tunnel.stop()
            raise
#     db_cursor = db_connection.cursor()
    connection = engine.connect()
