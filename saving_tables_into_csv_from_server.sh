#!/bin/bash

function print_help {
  echo $0 # The name of this file. 
  cat <<END_HELP
SYNOPSIS
		./get_switch_input_tables.sh
DESCRIPTION
	Pull input data for Switch from databases and other sources, formatting it for AMPL
This script assumes that the input database has already been built by the script 'Build WECC Cap Factors.sql'

INPUTS
 --help                   Print this message
 -t | --tunnel            Initiate an ssh tunnel to connect to the database. This won't work if ssh prompts you for your password.
 -u [DB Username]
 -p [DB Password]
 -D [DB name]
 -P/--port [port number]
 -h [DB server]
All arguments are optional.
END_HELP
}


# Export SWITCH input data from the Switch inputs database into text files that will be read in by AMPL
# This script assumes that the input database has already been built by the script 'Build WECC Cap Factors.sql'

write_to_path='inputs'

db_server="switch-db2.erg.berkeley.edu"
DB_name="switch_inputs_wecc_v2_2"
port=3306
ssh_tunnel=0

# Set the umask to give group read & write permissions to all files & directories made by this script.
umask 0002

###################################################
# Detect optional command-line arguments
help=0
while [ -n "$1" ]; do
case $1 in
  -t | --tunnel)
    ssh_tunnel=1; shift 1 ;;
  -u)
    user=$2; shift 2 ;;
  -p)
    password=$2; shift 2 ;;
  -P)
    port=$2; shift 2 ;;
  --port)
    port=$2; shift 2 ;;
  -D)
    DB_name=$2; shift 2 ;;
  -h)
    db_server=$2; shift 2 ;;
  --help)
		print_help; exit ;;
  *)
    echo "Unknown option $1"
		print_help; exit 0 ;;
esac
done

##########################
# Get the user name and password 
# Note that passing the password to mysql via a command line parameter is considered insecure
#	http://dev.mysql.com/doc/refman/5.0/en/password-security.html
default_user=$(whoami)
if [ ! -n "$user" ]
then 
	printf "User name for MySQL $DB_name on $db_server [$default_user]? "
	read user
	if [ -z "$user" ]; then 
	  user="$default_user"
	fi
fi
if [ ! -n "$password" ] 
then 
	printf "Password for MySQL $DB_name on $db_server? "
	stty_orig=`stty -g`   # Save screen settings
	stty -echo            # To keep the password vaguely secure, don't let it show to the screen
	read password
	stty $stty_orig       # Restore screen settings
	echo " "
fi

function clean_up {
  [ $ssh_tunnel -eq 1 ] && kill -9 $ssh_pid # This ensures that the ssh tunnel will be taken down if the program exits abnormally
  unset password
}

function is_port_free {
  target_port=$1
  if [ $(netstat -ant | \
         sed -e '/^tcp/ !d' -e 's/^[^ ]* *[^ ]* *[^ ]* *.*[\.:]\([0-9]*\) .*$/\1/' | \
         sort -g | uniq | \
         grep $target_port | wc -l) -eq 0 ]; then
    return 1
  else
    return 0
  fi
}

#############
# Try starting an ssh tunnel if requested
if [ $ssh_tunnel -eq 1 ]; then 
  echo "Trying to open an ssh tunnel. If it prompts you for your password, this method won't work."
  local_port=3307
  is_port_free $local_port
  while [ $? -eq 0 ]; do
    local_port=$((local_port+1))
    is_port_free $local_port
  done
  ssh -N -p 22 -c 3des "$user"@"$db_server" -L $local_port/127.0.0.1/$port &
  ssh_pid=$!
  sleep 1
  connection_string="-h 127.0.0.1 --port $local_port -u $user -p$password $DB_name"
  trap "clean_up;" EXIT INT TERM 
else
  connection_string="-h $db_server --port $port -u $user -p$password $DB_name"
fi

test_connection=`mysql $connection_string --column-names=false -e "select count(*) from existing_plants;"`
if [ ! -n "$test_connection" ] && [ $ssh_tunnel -eq 1 ]; then
        echo "First DB connection attempt failed. This sometimes happens if the ssh tunnel initiation is slow. Waiting 5 seconds, then will try again."
        sleep 5;
        test_connection=`mysql $connection_string --column-names=false -e "select count(*) from existing_plants;"`
fi
  
if [ ! -n "$test_connection" ]; then
	connection_string=`echo "$connection_string" | sed -e "s/ -p[^ ]* / -pXXX /"`
	echo "Could not connect to database with settings: $connection_string"
	exit 0
fi


###########################


INTERMITTENT_PROJECTS_SELECTION="(( avg_cap_factor_percentile_by_intermittent_tech >= 0.75 or cumulative_avg_MW_tech_load_area <= 3 * total_yearly_load_mwh / 8766 or rank_by_tech_in_load_area <= 5 or avg_cap_factor_percentile_by_intermittent_tech is null) and technology <> 'Concentrating_PV')"
cap_factor_table="_cap_factor_intermittent_sites_v2"
cap_factor_csp_6h_storage_table='_cap_factor_csp_6h_storage_adjusted'
proposed_projects_table="_proposed_projects_v3"
proposed_projects_view="proposed_projects_v3"

echo '	Saving proposed projects cap factors...'
mysql $connection_string -e "\
select project_id, load_area, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor  \
  FROM study_timepoints \
    JOIN load_scenario_historic_timepoints USING(timepoint_id)\
    JOIN $cap_factor_table ON(historic_hour=hour)\
    JOIN $proposed_projects_table USING(project_id)\
    JOIN load_area_info_v3 USING(area_id)\
  WHERE load_scenario_id=21 \
    AND $INTERMITTENT_PROJECTS_SELECTION \
    AND technology_id <> 7 \
UNION \
select project_id, load_area, technology, timepoint_id, DATE_FORMAT(datetime_utc,'%Y%m%d%H') as hour, cap_factor_adjusted as cap_factor  \
  FROM study_timepoints \
    JOIN load_scenario_historic_timepoints USING(timepoint_id)\
    JOIN $cap_factor_csp_6h_storage_table ON(historic_hour=hour)\
    JOIN $proposed_projects_table USING(project_id)\
    JOIN load_area_info_v3 USING(area_id)\
  WHERE load_scenario_id=21 \
    AND $INTERMITTENT_PROJECTS_SELECTION \
    AND technology_id = 7;" >> ampl_cap_factor.csv



cd ..
