#!/bin/bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGVERSION=1.0

RESULTS_FILE=sockperf.results
TEMP_FILE=/tmp/sockperf
DEFAULT_PORT=12000
DEFAULT_MSGSZ=128

function clean_up 
{
    for kp in `ps -e | grep " sockperf" | awk '{print $1}'`
    do
        kill -9 $kp > /dev/null 2>1
    done
    rm -f ${TEMP_FILE}_*
    exit 0
}

function post_process
{
    echo "" >> ${RESULTS_FILE}
    echo "===================================" >> ${RESULTS_FILE}
    echo "= Results for each thread" >> ${RESULTS_FILE}
    echo "===================================" >> ${RESULTS_FILE}

    echo 1 | awk '{ printf("%8s %6s %6s %6s %6s %6s\n", "Messages", "Size", "Secs", "Msgs/s", "MB/sec", "Mb/s") }' >> ${RESULTS_FILE}

    for f in `ls ${TEMP_FILE}_*`
    do
        echo "Processing ${f}"
        cat $f | awk -v msz=${msgsz} '{
            if ( $5 == "messages" ) {
                msgs=$4
                secs=$8
            }
            if ( $2 == "Summary:" ) {
                if ( $3 != "BandWidth" ) {
                    mrate=$6 
                }
                else
                {
                    printf("%8d %6d %6.2f %6d %6.2f %6.2f\n", msgs, msz, secs, mrate, $5, substr($7,2))
                }
            }
        }' >> ${RESULTS_FILE}
            
    done
}
    
function setup_environment
{
    # Need to run as root to set configuration of network tunables.
    if [ "${UID}" != "0" ] [ "${EUID}" != 0 ]
    then
        echo "${PROGNAME}: ERROR: root authority is required. Use sudo."
        exit 1
    fi

    # Tune for optimal Redis benchmark performance
    echo 3 > /proc/sys/vm/drop_caches
    echo 1 > /proc/sys/vm/overcommit_memory
    echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle
    echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
    echo 32768 > /proc/sys/net/core/somaxconn
    echo 16384 >  /proc/sys/net/ipv4/tcp_max_syn_backlog

    # 16MB per socket
    echo 65536 > /proc/sys/net/core/rmem_default
    echo 65536 > /proc/sys/net/core/wmem_default
    echo "4194304 4194304 4194304" > /proc/sys/net/ipv4/tcp_mem
    echo 4194304 > /proc/sys/net/core/rmem_max
    echo 4194304 > /proc/sys/net/core/wmem_max
    echo "4096 87380 4194304" > /proc/sys/net/ipv4/tcp_rmem
    echo "4096 87380 4194304" > /proc/sys/net/ipv4/tcp_wmem

    # Increase the number of outstanding syn requests allowed.
    echo 4096 > /proc/sys/net/ipv4/tcp_max_syn_backlog
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies
    echo 1 > /proc/sys/net/ipv4/tcp_no_metrics_save
    echo "12000 60000" > /proc/sys/net/ipv4/ip_local_port_range

    echo "never" > /sys/kernel/mm/transparent_hugepage/enabled

    sysctl -p >> ${RESULTS_FILE} 2>1
    return
}

function identify_system
{
    # Discover the type of system we are on.
    echo "`lscpu | grep "^Architecture:" | awk '{ if ( $2 == "x86_64" ) print "0"; else print "1"; exit }'`"
    return
}

############################ MAIN BODY ####################################

trap clean_up EXIT

# Setup defaults

#ncores=`get_numCores`
#smt_mode=`get_smt`
#(( nthreads = ${ncores} * ${smt_mode} ))

nthreads=`nproc`
(( last_cpu = ${nthreads} - 1 ))
port=${DEFAULT_PORT}
do_tcp=1                                # Default is to use TCP/IP protocol
TCP_FLAG="--tcp"                        # TCP/IP protocol flag
bufsz=262144                            # Default 256K buffer size
msgsz=${DEFAULT_MSGSZ}                  # Default 128B message size
run_time=30                             # Default run is for 30 seconds per test
is_server=0                             # Default is to run as client
ip_addr="10.0.0.101"                    # Default IP address of server

while getopts "b:ci:m:n:p:st:u" opt
do
    case ${opt} in
        b) bufsz=${OPTARG};;            # Size of buffer to use
        c) do_config=1;;                # Configure system with perf tunings
        i) ip_addr=${OPTARG};;          # IP address to use
        m) msgsz=${OPTARG};;            # Message size to be used
        n) nthreads=${OPTARG};;         # To override max system configuration
        p) port=${OPTARG};;             # Starting port
        s) is_server=1;;                # This is the server
        t) run_time=${OPTARG};;         # Length of time for test to run
        u) do_tcp=0;;                   # Change to using UDP for testing
    esac
done

echo "SOCKPERF TEST RESULTS" > ${RESULTS_FILE}
echo "=====================" >> ${RESULTS_FILE}
echo "Hostname:              `hostname`" >> ${RESULTS_FILE}
lscpu >> ${RESULTS_FILE}
echo "=====================" >> ${RESULTS_FILE}

if [ "${do_config}" == "1" ]
then
    echo "Doing configuation of system tunables." >> ${RESULTS_FILE}
    setup_environment
fi

if [ "${do_tcp}" == "0" ]
then
    TCP_FLAG=                 # Will default to UDP
fi

echo "=========================================" >> ${RESULTS_FILE}
echo "= netstat -i output BEFORE" >> ${RESULTS_FILE}
echo "=========================================" >> ${RESULTS_FILE}
netstat -i >> ${RESULTS_FILE}

echo "Place an instance on each logical CPU in the system."

for c in `cat /proc/cpuinfo | grep "processor" | awk '{ print $3 }'`
do
    if [ "${is_server}" == "1" ]
    then
        # This is the server.
        echo "${PROGNAME}: Starting server on CPU ${c}} using port ${port}" >> ${RESULTS_FILE}
       ./sockperf server --ip ${ip_addr} ${TCP_FLAG} --port ${port} --buffer-size ${bufsz} --cpu-affinity ${c} >> ${RESULTS_FILE} 2>1
    else
        # This is the client.
        ./sockperf tp --ip ${ip_addr} ${TCP_FLAG} --msg-size ${msgsz} --buffer-size ${bufsz} --time ${run_time} \
            --port ${port} --sender-affinity ${c} >> ${TEMP_FILE}_CPU${c} 2>1
    fi

    (( port = ${port} + 1 ))
done
wait
echo "=========================================" >> ${RESULTS_FILE}
echo "= netstat -i output AFTER" >> ${RESULTS_FILE}
echo "=========================================" >> ${RESULTS_FILE}
netstat -i >> ${RESULTS_FILE}

if [ "${is_server}" == "0" ]
then
    post_process
fi
echo "Getting ready to exit. Please wait."
clean_up
