# -*- coding: utf-8 -*-
# Copyright 2017 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.
# Renewable and Appropriate Energy Laboratory, UC Berkeley.
# Operations, Control and Markets laboratory at Pontificia Universidad
# Católica de Chile.
"""

Retrieves data inputs for the Switch WECC model from the database. Data
is formatted into corresponding .tab or .dat files.

"""

import argparse
import getpass
import os
import sys
import time

import psycopg2
from sshtunnel import SSHTunnelForwarder


# Set python to stream output unbuffered.
#sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)

start_time = time.time()

def write_tab(fname, headers, cursor):
    with open(fname + '.tab', 'w') as f: # Paty: open() opens file named fname and only allows us to (re)write on it ('w'). "with" keyword ensures the file is closed at the end of the function. 
        f.write('\t'.join(headers) + os.linesep) # Paty: str.join(headers) joins the strings in the sequence "headers" and separates them with string "str"
        for row in cursor:
            # Replace None values with dots for Pyomo. Also turn all datatypes into strings
            row_as_clean_strings = ['.' if element is None else str(element) for element in row]
            f.write('\t'.join(row_as_clean_strings) + os.linesep) # concatenates "line" separated by tabs, and appends \n 


def shutdown():
    if cur:
        cur.close()
    if con:
        print '\nClosing DB connection.'
        con.close()
        
    os.chdir('..')
    server.stop()


parser = argparse.ArgumentParser(
    usage='get_switch_pyomo_input_tables.py [--help] [options]',
    description='Write SWITCH input files from database tables. Default \
    options asume an SSH tunnel has been opened between the local port 5432\
    and the Postgres port at the remote host where the database is stored.',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument(
    '-H', '--hostname', dest="host", type=str, 
    default='switch-db2.erg.berkeley.edu', metavar='hostname', 
    help='Database host address')
parser.add_argument(
    '-P', '--port', dest="port", type=int, default=5432, metavar='port',
    help='Database host port')
parser.add_argument(
    '-U', '--user', dest='user', type=str, default=getpass.getuser(), metavar='username',
    help='Database username')
parser.add_argument(
    '-D', '--database', dest='database', type=str, default='switch_wecc2', metavar='dbname',
    help='Database name')
parser.add_argument(
    '-s', type=int, required=True, metavar='scenario_id',
    help='Scenario ID for the simulation')
parser.add_argument(
    '-i', type=str, default='inputs', metavar='inputsdir',
    help='Directory where the inputs will be built')
args = parser.parse_args()

passw = getpass.getpass('Enter database password for user %s:' % args.user)

try:
    # Connection settings are determined by parsed command line inputs
    # Start an ssh tunnel because the database only permits local connections
    server = SSHTunnelForwarder(
        args.host,
        ssh_pkey= os.path.expanduser('~') + "/.ssh/id_rsa",
        remote_bind_address=('127.0.0.1', args.port)
    )
    server.start()
# with SSHTunnelForwarder(
#     args.host,
#     ssh_pkey= os.path.expanduser('~') + "/.ssh/id_rsa",
#     remote_bind_address=('127.0.0.1', args.port)
# ) as server:
    con = psycopg2.connect(database=args.database, user=args.user, host='127.0.0.1',
#                           port=server.local_bind_port, password='foobar')
                           port=server.local_bind_port, password=passw)
    print "Connection to database established..."
except:
    sys.exit("Error connecting to database %s at host %s." % (args.database, args.host))

if not os.path.exists(args.i):
    os.makedirs(args.i)
    print 'Inputs directory created...'
else:
    print 'Inputs directory exists, so contents will be overwritten...'

cur = con.cursor()

# Test db connection for debugging...
# cur.execute("select 1 + 1 as x;")
# print cur.fetchone()
# shutdown()
# sys.exit("Finished our test")

############################################################################################################
# These next variables determine which input data is used, though some are only for documentation and result exports.

cur.execute("SELECT * FROM switch_wecc_pyomo.scenario WHERE scenario_id = %s" % args.s)
s_details = cur.fetchone()
#name, description, sample_ts_scenario_id, hydro_scenario_meta_id, fuel_id, gen_costs_id, new_projects_id, carbon_tax_id, carbon_cap_id, rps_id, lz_hourly_demand_id, gen_info_id, load_zones_scenario_id, existing_projects_id, demand_growth_id = s_details[1], s_details[2], s_details[3], s_details[4], s_details[5], s_details[6], s_details[7], s_details[8], s_details[9], s_details[10], s_details[11], s_details[12], s_details[13], s_details[14], s_details[15]
name, description, study_timeframe_id, time_sample_id, demand_scenario_id, fuel_simple_price_scenario_id, generation_plant_scenario_id, generation_plant_cost_scenario_id, generation_plant_existing_and_planned_scenario_id, hydro_simple_scenario_id

os.chdir(args.i)

# The format for tab files is:
# col1_name col2_name ...
# [rows of data]

# The format for dat files is the same as in AMPL dat files.

print '\nStarting data copying from the database to input files for scenario: "%s"' % name

# Write general scenario parameters into a documentation file
print 'Writing scenario documentation into scenario_params.txt.'
with open('scenario_params.txt', 'w') as f:
    f.write('Scenario id: %s' % args.s)
    f.write('\nScenario name: %s' % name)
    f.write('\nScenario notes: %s' % description)

########################################################
# Paty: this section still needs to be worked on
# TIMESCALES

print '  periods.tab...'
# cur.execute(('SELECT DISTINCT p.period_name, period_start, period_end '
#              'FROM switch_wecc_pyomo.timescales_sample_timeseries sts '
#              'JOIN switch_wecc_pyomo.timescales_population_timeseries pts ON sts.sampled_from_population_timeseries_id=pts.population_ts_id '
#              'JOIN switch_wecc_pyomo.timescales_periods p USING (period_id) '
#              'WHERE sample_ts_scenario_id={} '
#              'ORDER BY 1;'
#             ).format(sample_ts_scenario_id))
cur.execute("""SELECT DISTINCT p.period_name, period_start, period_end 
               FROM switch_wecc_pyomo.timescales_sample_timeseries sts 
                   JOIN switch_wecc_pyomo.timescales_population_timeseries pts ON sts.sampled_from_population_timeseries_id=pts.population_ts_id 
                   JOIN switch_wecc_pyomo.timescales_periods p USING (period_id) 
               WHERE sample_ts_scenario_id={id} 
               ORDER BY 1;
            """.format(id=sample_ts_scenario_id))

write_tab('periods', ['INVESTMENT_PERIOD', 'period_start', 'period_end'], cur)

print '  timeseries.tab...'
cur.execute("""SELECT sample_ts_id, period_name, hours_per_tp::integer, sts.num_timepoints, sts.scaling_to_period 
				FROM switch_wecc_pyomo.timescales_sample_timeseries sts 
				JOIN switch_wecc_pyomo.timescales_population_timeseries pts 
				ON sts.sampled_from_population_timeseries_id=pts.population_ts_id AND sample_ts_scenario_id=%s 
				ORDER BY 1;
				""" % (sample_ts_scenario_id))
write_tab('timeseries', ['TIMESERIES', 'ts_period', 'ts_duration_of_tp', 'ts_num_tps', 'ts_scale_to_period'], cur)

print '  timepoints.tab...'
cur.execute("""SELECT sample_tp_id,to_char(timestamp, 'YYYYMMDDHH24'),sample_ts_id 
				FROM switch_wecc_pyomo.timescales_sample_timepoints 
				JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) 
				WHERE sample_ts_scenario_id=%s 
				ORDER BY 1;
				""" % (sample_ts_scenario_id))
write_tab('timepoints', ['timepoint_id','timestamp','timeseries'], cur)

########################################################
# LOAD ZONES

#done
print '  load_zones.tab...'
cur.execute("""SELECT name, ccs_distance_km as zone_ccs_distance_km, load_zone_id as zone_dbid 
				FROM switch_wecc_pyomo.load_zone  
				ORDER BY 1;
				""" )
write_tab('load_zones',['LOAD_ZONE','zone_ccs_distance_km','zone_dbid'],cur)

#Paty: work on
print '  loads.tab...'
cur.execute("""SELECT lzd.name, tps.sample_tp_id, CASE WHEN lz_demand_mwh >= 0 THEN lz_demand_mwh*(SELECT mul(1+growth_factor/100) 
				from switch_wecc_pyomo.demand_growth dg 
				where dg.name =lzd.name and TO_CHAR(tps.timestamp,'YYYY')::INT >= year 
				and demand_growth_scenario_id = %s) ELSE 0 END 
    			FROM switch_wecc_pyomo.lz_hourly_demand lzd 
    			JOIN switch_wecc_pyomo.timescales_sample_timepoints tps ON TO_CHAR(tps.timestamp,'MMDDHH24')=TO_CHAR(lzd.timestamp_cst,'MMDDHH24') 
    			JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) 
    			JOIN switch_wecc_pyomo.load_zone USING (name,load_zones_scenario_id) 
    			WHERE sample_ts_scenario_id = %s AND load_zones_scenario_id = %s 
    			AND lz_hourly_demand_id = %s 
    			ORDER BY 1,2;
    			""" % (demand_growth_id,sample_ts_scenario_id,load_zones_scenario_id,lz_hourly_demand_id))
write_tab('loads',['LOAD_ZONE','TIMEPOINT','zone_demand_mw'],cur)

########################################################
# BALANCING AREAS 

print '  balancing_areas.tab...'
cur.execute("""SELECT balancing_area, quickstart_res_load_frac, quickstart_res_wind_frac, quickstart_res_solar_frac,spinning_res_load_frac, 
				spinning_res_wind_frac, spinning_res_solar_frac 
				FROM switch_wecc_pyomo.balancing_areas;
				""")
write_tab('balancing_areas',['BALANCING_AREAS','quickstart_res_load_frac','quickstart_res_wind_frac','quickstart_res_solar_frac','spinning_res_load_frac','spinning_res_wind_frac','spinning_res_solar_frac'],cur)

print '  zone_balancing_areas.tab...'
cur.execute("""SELECT name, reserves_area as balancing_area 
				FROM switch_wecc_pyomo.load_zone;
				""")
write_tab('zone_balancing_areas',['LOAD_ZONE','balancing_area'],cur)

#Paty: in this version of switch this tables is named zone_coincident_peak_demand.tab
#PATY: PENDING TAB!
# # For now, only taking 2014 peak demand and repeating it.
# print '  lz_peak_loads.tab'
# cur.execute("""SELECT lzd.name, p.period_name, max(lz_demand_mwh) 
#				FROM switch_wecc_pyomo.timescales_sample_timepoints tps 
#				JOIN switch_wecc_pyomo.lz_hourly_demand lzd ON TO_CHAR(lzd.timestamp_cst,'MMDDHH24')=TO_CHAR(tps.timestamp,'MMDDHH24') 
#				JOIN switch_wecc_pyomo.timescales_sample_timeseries sts USING (sample_ts_id) 
#				JOIN switch_wecc_pyomo.timescales_population_timeseries pts ON sts.sampled_from_population_timeseries_id = pts.population_ts_id 
#				JOIN switch_wecc_pyomo.timescales_periods p USING (period_id) 
#				WHERE sample_ts_scenario_id = %s 
#				AND lz_hourly_demand_id = %s 
#				AND load_zones_scenario_id = %s 
#				AND TO_CHAR(lzd.timestamp_cst,'YYYY') = '2014' 
#				GROUP BY lzd.name, p.period_name 
#				ORDER BY 1,2;""" % (sample_ts_scenario_id,lz_hourly_demand_id,load_zones_scenario_id))
# write_tab('lz_peak_loads',['LOAD_ZONE','PERIOD','peak_demand_mw'],cur)

########################################################
# TRANSMISSION

print '  transmission_lines.tab...'
cur.execute("""SELECT start_load_zone_id || '-' || end_load_zone_id, start_load_zone_id, end_load_zone_id, 
				trans_length_km, trans_efficiency, existing_trans_cap_mw 
				FROM switch_wecc_pyomo.transmission_lines  
				ORDER BY 2,3;
				""")
write_tab('transmission_lines',['TRANSMISSION_LINE','trans_lz1','trans_lz2','trans_length_km','trans_efficiency','existing_trans_cap'],cur)

print '  trans_optional_params.tab...'
cur.execute("""SELECT start_load_zone_id || '-' || end_load_zone_id, transmission_line_id, derating_factor, terrain_multiplier, 
				new_build_allowed 
				FROM switch_wecc_pyomo.transmission_lines 
				ORDER BY 1;
				""")
write_tab('trans_optional_params.tab',['TRANSMISSION_LINE','trans_dbid','trans_derating_factor','trans_terrain_multiplier','trans_new_build_allowed'],cur)

print '  trans_params.dat...'
with open('trans_params.dat','w') as f:
    f.write("param trans_capital_cost_per_mw_km:=1150;\n") # $1150 opposed to $1000 to reflect change to US$2016
    f.write("param trans_lifetime_yrs:=20;\n") # Paty: check what lifetime has been used for the wecc
    f.write("param trans_fixed_o_m_fraction:=0.03;\n")
    #f.write("param distribution_loss_rate:=0.0652;\n")

########################################################
# FUEL
#Paty: continue here

print '  fuels.tab...'
cur.execute("SELECT energy_source, co2_intensity, upstream_co2_intensity FROM switch_wecc_pyomo.energy_sources WHERE fuel IS TRUE;")
write_tab('fuels',['fuel','co2_intensity','upstream_co2_intensity'],cur)

print '  non_fuel_energy_sources.tab...'
cur.execute("SELECT energy_source FROM switch_wecc_pyomo.energy_sources WHERE non_fuel_energy_source IS TRUE;")
write_tab('non_fuel_energy_sources',['energy_source'],cur)

# Fuel projections are yearly averages in the DB. For now, Switch only accepts fuel prices per period, so they are averaged.
print '  fuel_cost.tab'
cur.execute("SELECT name, fuel, period_name, AVG(fuel_price) FROM switch_wecc_pyomo.fuel_yearly_prices CROSS JOIN switch_wecc_pyomo.timescales_periods WHERE fuel_yearly_prices_id = %s AND load_zones_scenario_id = %s AND projection_year BETWEEN period_start AND period_end AND period_name IN (SELECT DISTINCT p.period_name FROM switch_wecc_pyomo.timescales_sample_timeseries sts JOIN switch_wecc_pyomo.timescales_population_timeseries pts ON sts.sampled_from_population_timeseries_id=pts.population_ts_id JOIN switch_wecc_pyomo.timescales_periods p USING (period_id) WHERE sample_ts_scenario_id=%s) GROUP BY name, fuel, period_name ORDER BY 1, 2, 3;" % (fuel_id,load_zones_scenario_id, sample_ts_scenario_id))
write_tab('fuel_cost',['load_zone','fuel','period','fuel_cost'],cur)

########################################################
# GENERATOR TECHNOLOGIES

print '  generator_info.tab...'
cur.execute("SELECT technology_name, max_age, CASE WHEN variable THEN 1 ELSE 0 END, CASE WHEN baseload THEN 1 ELSE 0 END, CASE WHEN flexible_baseload THEN 1 ELSE 0 END, CASE WHEN cogen THEN 1 ELSE 0 END, CASE WHEN competes_for_space THEN 1 ELSE 0 END, variable_o_m, energy_source, technology_id, scheduled_outage_rate, forced_outage_rate, min_build_capacity, full_load_heat_rate, unit_size, CASE WHEN ror THEN 1 ELSE 0 END FROM switch_wecc_pyomo.generator_info WHERE generator_info_id = %s ORDER BY 1;" % gen_info_id) 
write_tab('generator_info',['generation_technology','g_max_age','g_is_variable','g_is_baseload','g_is_flexible_baseload','g_is_cogen','g_competes_for_space','g_variable_o_m','g_energy_source','g_dbid','g_scheduled_outage_rate','g_forced_outage_rate','g_min_build_capacity','g_full_load_heat_rate','g_unit_size', 'g_is_ror'],cur)

# Yearly overnight and fixed o&m cost projections are averaged for each study period.
print '  gen_new_build_costs.tab...'
cur.execute("SELECT technology_name, period_name, AVG(overnight_cost), AVG(fixed_o_m) FROM switch_wecc_pyomo.generator_yearly_costs JOIN switch_wecc_pyomo.generator_info USING (technology_name) CROSS JOIN switch_wecc_pyomo.timescales_periods WHERE generator_yearly_costs_id = %s AND generator_info_id = %s AND projection_year BETWEEN period_start AND period_end AND period_name IN (SELECT DISTINCT p.period_name FROM switch_wecc_pyomo.timescales_sample_timeseries sts JOIN switch_wecc_pyomo.timescales_population_timeseries pts ON sts.sampled_from_population_timeseries_id=pts.population_ts_id JOIN switch_wecc_pyomo.timescales_periods p USING (period_id) WHERE sample_ts_scenario_id=%s)  GROUP BY 1,2 ORDER BY 1,2;" % (gen_costs_id,gen_info_id,sample_ts_scenario_id)) 
write_tab('gen_new_build_costs',['generation_technology','investment_period','g_overnight_cost','g_fixed_o_m'],cur)

########################################################
# PROJECTS

#Paty: remember to change names of technologies to delete _EP

excluded_projs = ('chapiquina','chiburgo')
# Chapiquina doesn't have capacity factors defined.
# Chiburgo is a regulation reservoir which won't be modeled.

print '  project_info.tab...'
cur.execute("SELECT project_name, gen_tech, load_zone, connect_cost_per_mw, variable_o_m, full_load_heat_rate, forced_outage_rate, scheduled_outage_rate, project_id, capacity_limit_mw, hydro_efficiency FROM switch_wecc_pyomo.project_info_existing WHERE project_name NOT IN %s AND existing_projects_id = %s \
    UNION SELECT project_name, gen_tech, load_zone, connect_cost_per_mw, variable_o_m, full_load_heat_rate, forced_outage_rate, scheduled_outage_rate, project_id, capacity_limit_mw, hydro_efficiency FROM switch_wecc_pyomo.project_info_new JOIN switch_wecc_pyomo.new_projects_sets USING (project_id) WHERE new_projects_sets_id = %s ORDER BY 2,3;" % (excluded_projs, existing_projects_id, new_projects_id))
write_tab('project_info',['PROJECT','proj_gen_tech','proj_load_zone','proj_connect_cost_per_mw','proj_variable_om','tproj_full_load_heat_rate','proj_forced_outage_rate','proj_scheduled_outage_rate','proj_dbid','proj_capacity_limit_mw','proj_hydro_efficiency'],cur)

print '  proj_existing_builds.tab...'
cur.execute("SELECT project_name, start_year, capacity_mw FROM switch_wecc_pyomo.project_info_existing WHERE project_name NOT IN %s AND existing_projects_id = %s ;" % (excluded_projs,existing_projects_id))
write_tab('proj_existing_builds',['PROJECT','build_year','proj_existing_cap'],cur)

print '  proj_build_costs.tab...'
cur.execute("SELECT project_name, start_year, overnight_cost, fixed_o_m FROM switch_wecc_pyomo.project_info_existing WHERE project_name NOT IN %s AND existing_projects_id = %s ;" % (excluded_projs,existing_projects_id))
write_tab('proj_build_costs',['PROJECT','build_year','proj_overnight_cost','proj_fixed_om'],cur)

########################################################
# FINANCIALS

print '  financials.dat...'
with open('financials.dat','w') as f:
    f.write("param base_financial_year := 2016;\n")
    f.write("param interest_rate := .07;\n")
    f.write("param discount_rate := .07;\n")

########################################################
# VARIABLE CAPACITY FACTORS

#Pyomo will raise an error if a capacity factor is defined for a project on a timepoint when it is no longer operational (i.e. Canela 1 was built on 2007 and has a 30 year max age, so for tp's ocurring later than 2037, its capacity factor must not be written in the table).

# This will only get exactly the cf in the moment when the timepoint beings
# If a timepoint lasts for 2 hours, then the cf for the first hour will be
# stored.    

#The order is:
# 1: Fill new solar and wind with makeshift values by gentech
# 2: Fill existing solar and wind with makeshift values by gentech

# print '  variable_capacity_factors.tab...'
# cur.execute("SELECT info.project_name, sample_tp_id, capacity_factor FROM switch_wecc_pyomo.variable_capacity_factors_existing cf JOIN switch_wecc_pyomo.project_info_new info ON (info.gen_tech=cf.project_name) JOIN switch_wecc_pyomo.new_projects_sets np ON (np.project_id = info.project_id and new_projects_sets_id=%s) JOIN (SELECT * FROM switch_wecc_pyomo.timescales_sample_timepoints JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) WHERE sample_ts_scenario_id=%s) tps ON TO_CHAR(cf.timestamp_cst,'MMDDHH24')=TO_CHAR(tps.timestamp,'MMDDHH24') \
#     UNION SELECT info.project_name, sample_tp_id, capacity_factor FROM switch_wecc_pyomo.variable_capacity_factors_existing cf JOIN switch_wecc_pyomo.project_info_existing info ON info.gen_tech = cf.project_name JOIN (SELECT * FROM switch_wecc_pyomo.timescales_sample_timepoints JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) WHERE sample_ts_scenario_id=%s) tps ON TO_CHAR(cf.timestamp_cst,'MMDDHH24')=TO_CHAR(tps.timestamp,'MMDDHH24') AND existing_projects_id = %s \
#     ORDER BY 1,2;" % (new_projects_id,sample_ts_scenario_id,sample_ts_scenario_id, existing_projects_id))
# write_tab('variable_capacity_factors',['PROJECT','timepoint','proj_max_capacity_factor'],cur)


#The order is:
# 1: Fill new solar and wind with makeshift values by gentech
# 2: Fill existing solar and wind with 2015 real values and repeating them 
# year by year.
print '  variable_capacity_factors.tab...'
cur.execute("SELECT info.project_name, sample_tp_id, capacity_factor FROM switch_wecc_pyomo.variable_capacity_factors_existing cf JOIN switch_wecc_pyomo.project_info_new info ON (info.gen_tech=cf.project_name) JOIN switch_wecc_pyomo.new_projects_sets np ON (np.project_id = info.project_id and new_projects_sets_id=%s) JOIN (SELECT * FROM switch_wecc_pyomo.timescales_sample_timepoints JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) WHERE sample_ts_scenario_id=%s) tps ON TO_CHAR(cf.timestamp_cst,'MMDDHH24')=TO_CHAR(tps.timestamp,'MMDDHH24') \
    UNION SELECT info.project_name, sample_tp_id, capacity_factor FROM switch_wecc_pyomo.variable_capacity_factors_existing cf JOIN switch_wecc_pyomo.project_info_existing info ON info.project_name = cf.project_name JOIN (SELECT * FROM switch_wecc_pyomo.timescales_sample_timepoints JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) WHERE sample_ts_scenario_id=%s) tps ON TO_CHAR(cf.timestamp_cst,'MMDDHH24')=TO_CHAR(tps.timestamp,'MMDDHH24') AND existing_projects_id = %s \
    ORDER BY 1,2;" % (new_projects_id,sample_ts_scenario_id,sample_ts_scenario_id, existing_projects_id))
write_tab('variable_capacity_factors',['PROJECT','timepoint','proj_max_capacity_factor'],cur)


# Fill existing RoR projects. They have a constant flow per month,
# specified for the first day of every month. This flow is multiplied by
# the turbine's efficiency.
print '  ror_capacity_factors.tab...'
cur.execute("SELECT i.project_name, sample_tp_id, name, CASE WHEN (inflow*hydro_efficiency)/capacity_limit_mw < 1.2 THEN (inflow*hydro_efficiency)/capacity_limit_mw ELSE 1.2 END FROM switch_wecc_pyomo.project_info_existing i JOIN switch_wecc_pyomo.hydrologies h ON h.flow_name = i.project_name AND gen_tech='Hydro_RoR' \
    JOIN (SELECT * FROM switch_wecc_pyomo.timescales_sample_timepoints JOIN switch_wecc_pyomo.timescales_sample_timeseries USING (sample_ts_id) JOIN switch_wecc_pyomo.timescales_population_timeseries ts ON (ts.population_ts_id=sampled_from_population_timeseries_id) WHERE sample_ts_scenario_id=%s) tps ON (TO_CHAR(tps.timestamp,'MM') = TO_CHAR(h.year_month_day,'MM') AND existing_projects_id = %s) \
    JOIN switch_wecc_pyomo.hydro_scenarios s ON (s.period_id=tps.period_id AND h.hyd_year=s.hyd_year AND hyd_scenario_meta_id=%s)  \
    ORDER BY 1,2,3;" % (sample_ts_scenario_id, existing_projects_id, hydro_scenario_meta_id))
write_tab('ror_capacity_factors',['PROJECT','timepoint','scenario','ror_max_capacity_factor'],cur)


# Clean-up
shutdown()

end_time = time.time()

print '\nScript took %s seconds building input tables.' % (end_time-start_time)

