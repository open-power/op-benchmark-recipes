#!/bin/bash

ARCH=`lscpu | awk '/Model name:/ { print $3 }'`
DLINE="=============================================================="
SLINE="--------------------------------------------------------------"

FORMAT1="%15s %15s %10s %10s %10s %10s %10s\n"
FORMAT2="%15d %15d %10.3f %10.3f %10.3f %10.3f %10.5f\n"
FORMAT3="%15s %15s %10.1f %10.1f %10.1f %10.1f\n"
HEADER1="ALLOCATED_ON ACCESSED_FROM MIN MAX MEDIAN MEAN STDDEV"
HEADER2="ALLOCATED_ON ACCESSED_FROM COPY SCALE ADD TRIAD"
SFX="out"

# discover post-processing list, assuming in-order functions named LT*
LTPOSTLIST=$(awk '/^function LT/ { print $2 }' $0 | sed -e "s/LT//" | grep -v lat_mem_rd | xargs echo)

# Use the current script location to decide where to save results
LTEXEC=`basename $0`
LTPATH=$(cd $(dirname "$0") ; pwd)
[[ ${LTPATH} == "." || ${LTPATH} == "" ]] && LTPATH=`pwd`

PRES=`echo ${LTPATH} | sed -e "s/\/bin/\\/RESULTS/"`      # Results directory

# Where is lat_mem_rd?
LTCMD="lat_mem_rd"

if [ ! -f  ${LTPATH}/${LTCMD} ]
then
    echo "${LTEXEC}: Cannot find the lat_mem_rd executable in ${LTPATH}"
    exit 1
fi

function Usage {
    echo "Usage: ${LTEXEC} [-ps set] [-nr runs] [-ni iterations] [-pe event]"
    echo "               [-bs buffer_size] [-st stride_size] [-perf] [-log]"
    echo "Where: -nr number of runs in each prefetch set (default: 1)"
    echo "       -ni number of iterations in each latter run (default: 5)"
    echo "       -pe pmcount event to trace (default: 108)"
    echo "       -bs  buffer size to use (default: 3000)"
    echo "       -st  stride size to use (default: 128)"
    echo "       -perf  enable perf stat collection (default: off) enabling this automatically adds '-log'"
    echo "       -log  keep the log files after competion (default: off)"
    echo ""
    echo "       Runs and iterations should be odd, adjusted to be so if not"
    echo ""
    exit 1
}

function Log {
    echo "`date "+%b%d %T"` : $@" |tee ${OUTLOG}
    return
}

function MLog {
    Log ${DLINE}
    Log "$@"
    Log ${SLINE}
    return
}

function StateLog {
    _FM1="%-16s : %s\n"
    echo ""
    echo ${DLINE}
    echo "Latter Test State"
    echo ${SLINE}
    echo ""
    printf "${_FM1}" "Command Line" "${LTEXEC} $@"
    printf "${_FM1}" "Latter Path" "${LTPATH}/${LTCMD}"
    printf "${_FM1}" "Architecture" "${ARCH}"
    printf "${_FM1}" "Buffer Size" "$(eval echo \"\${LT_BUFSIZE}\") MB"
    printf "${_FM1}" "Stride Length" "$(eval echo \"\${LT_STRIDESIZE}\") bytes"
    printf "${_FM1}" "Runs" "$(eval echo \"\${LTRUNS}\")"
    printf "${_FM1}" "Iterations" "$(eval echo \"\${LTITERS}\")"

    if [[ ${LT_LOG} == "TRUE" ]]
    then
        printf "${_FM1}" "Log Location" "$(eval echo \"\${LTDATADIR}\")"
    else
        printf "${_FM1}" "Log Location" "logs not stored"
    fi
    printf "${_FM1}" "Perf Events" "$(eval echo \"\${LTPMEVENT}\")"
    printf "${_FM1}" "Nodes Detected" "$(eval echo \"\${LTNODE_SET}\")"
    printf "${_FM1}" "Avg CPU Speed" "$(eval echo \"\${SPEED}\")"    
    echo ""
    return
}

# Run latter test for both pmcount on/off
 
function LTlat_mem_rd {
    Log "Running tests..."

    ulimit -d unlimited
    export MEMORY_AFFINITY=mcm

    # Store the current prefetch and SMT settings
    CURR_PREFETCH=`ppc64_cpu --dscr | sed 's/DSCR is //'`
    CURR_SMT=`ppc64_cpu --smt | sed "s/SMT=//" | xargs`

    for _PREFETCH in ${LTPREFETCH_SET}
    do
        ppc64_cpu --dscr=${_PREFETCH}
        if [ ! -d ${LTNAME_PREFETCH}.${_PREFETCH} ]
        then
            mkdir ${LTNAME_PREFETCH}.${_PREFETCH}
        fi
        cd ${LTNAME_PREFETCH}.${_PREFETCH}

        _RUN=1
        while (( ${_RUN} <= ${LTRUNS} ))
        do
            if [ ! -d  ${LTNAME_RUN}.${_RUN} ]
            then
                mkdir ${LTNAME_RUN}.${_RUN}
            fi

            cd ${LTNAME_RUN}.${_RUN}
            i=0

            for _CHIP in ${LTCHIP_SET}
            do
                _ARGS="${LTITERS}i${LT_BUFSIZE} ${LT_STRIDESIZE} ${_CHIP} ${LTCHIP_SET}"
                _OF1="${LTNAME_LAT}.${_CHIP}.${LTNAME_OUT}"

                if [[ ${LTRUN_PMCOUNT} == "TRUE" ]]
                then
                    # do the run with perf if it was requested
                    Log "${LTPMCMD} ${LTCMD} ${_ARGS}"
                    _OF2="${LTNAME_LAT}.${_CHIP}.${LTNAME_PMCOUT}"
                    numactl --m ${nodes[$i]} ${LTPMCMD} ${LTPATH}/${LTCMD} ${_ARGS} >> ${_OF2} 2>&1
                else
                    # Otherwise just do the run
                    Log "${LTCMD} ${_ARGS}"
                    numactl --m ${nodes[$i]} ${LTPATH}/${LTCMD} ${_ARGS} >> ${_OF1} 2>&1
                fi
                (( i += 1 ))
            done
            cd ..
            (( _RUN += 1 ))
        done
        cd ..
    done

    # Test cache latencies (prefetch is always off for this)

    ppc64_cpu --dscr=1

    for _CHIP in ${LTCHIP_SET}
    do
        _ARGS="${LTPATH}/${LTCMD} 60 128 ${_CHIP}"
        _OF3="${_CHIP}.cache.out"
        Log "${_ARGS}"
        ${_ARGS} >> ${_OF3} 2>&1
    done

    # Turn SMT off and prefetch on for stream measurements
    ppc64_cpu --smt=off

    # Measure STREAM results
    for _SRC_NODE in ${LTNODE_SET}
    do
       for _DST_NODE in ${LTNODE_SET}
       do
            # Figure out which CPUs to run on and how many there are
            _CPU_SET=`numactl --hardware | grep "${_DST_NODE} cpus: " | sed "s/node ${_DST_NODE} cpus: //" | xargs`
            _CPU_NUM=`echo "${_CPU_SET}" | wc -w`

            # Actually run
            _OF4="${_SRC_NODE}.${_DST_NODE}.${STNAME_OUT}"
            export OMP_NUM_THREADS="${_CPU_NUM}"
            export GOMP_CPU_AFFINITY="${_CPU_SET}"
            Log "numactl -m ${_SRC_NODE} ${LTPATH}/${STCMD}"
            numactl -m ${_SRC_NODE} ${LTPATH}/${STCMD} >> ${_OF4} 2>&1
        done
    done

    # Run at a system level if there is more than one node
    if [[ $( echo ${LTNODE_SET} | wc -w ) > 1 ]]
    then
        for _NODE in ${LTNODE_SET}
        do
            _CPU_SET=`numactl --hardware | grep "${_NODE} cpus: " | sed "s/node ${_NODE} cpus: //" | xargs`
            _SYS_CPU_SET="${_SYS_CPU_SET} ${_CPU_SET}"
        done

        _SYS_CPU_NUM=`echo "${_SYS_CPU_SET}" | wc -w`
        export OMP_NUM_THREADS="${_SYS_CPU_NUM}"
        export GOMP_CPU_AFFINITY="${_SYS_CPU_SET}"

        _OF4="system.${STNAME_OUT}"
        Log "${LTPATH}/${STCMD}"
        ${LTPATH}/${STCMD} >> ${_OF4} 2>&1
    fi

    #Restore prefetch and smt settings
    ppc64_cpu --smt=${CURR_SMT}
    ppc64_cpu --dscr=${CURR_PREFETCH}
    return
}

# post process each run directory, computing standard deviation

function LTpost {
    Log "Post-processing individual latter runs"

    for _PDIR in ${LTNAME_PREFETCH}.*
    do
        cd ${_PDIR} > /dev/null
        for _RDIR in ${LTNAME_RUN}.*
        do
            cd ${_RDIR} >/dev/null
            _CHIPSET=`ls -1 lat.*.out | cut -f 2- -d "." | cut -f -1 -d "." | sort -nu | xargs`

            ls *.${SFX} > /dev/null 2>&1 || continue        # Skip if no files

            # Compute min, max, mean
            _OF1="${LTNAME_LATENCY}.${SFX}"

            printf "${FORMAT1}\n" ${HEADER1} > ${_OF1}

            for _CHIPX in ${_CHIPSET}
            do
                _IF1="${LTNAME_LAT}.${_CHIPX}.${SFX}"
                for _CHIPY in ${_CHIPSET}
                do
                    _ARGS="Running on CPU: ${_CHIPY}"
                    _LATVALS="$(grep -A ${LTITERS} "${_ARGS}" ${_IF1} | awk '/\./ { print $2 }' | sort -n | xargs)"
                    _MINLAT=`echo ${_LATVALS} | awk '{ print $1 }'`
                    _MAXLAT=`echo ${_LATVALS} | awk '{ print $NF }'`
                    _TOTAL=`echo ${_LATVALS} | sed -e 's/ /+/g'`
                    _TOTAL=`echo "scale=3; ${_TOTAL}" | bc -l`
                    _MEDNUM=$(( (${LTITERS} / 2) + 1))
                    _MEDLAT=`echo ${_LATVALS} | awk -v mval=${_MEDNUM} '{ print $mval }'`
                    _MEAN=$(echo "scale=3; ${_TOTAL}/${LTITERS}" | bc -l)
                    _STDDEV=$(echo $_LATVALS | awk -vM=${_MEAN} '{ for ( i = 1; i <= NF; i++ ) { sum += ( $i - M ) * ( $i - M ) }; print sqrt(sum/NF)}')

                    # Use node ID instead of CPU
                    _NODEX=$(CPUtoNode ${_CHIPX})
                    _NODEY=$(CPUtoNode ${_CHIPY})
                    printf "${FORMAT2}" ${_NODEX} ${_NODEY} ${_MINLAT} ${_MAXLAT} ${_MEDLAT} ${_MEAN} ${_STDDEV} >> ${_OF1}
                done # _CHIPY
                echo "" >> ${_OF1}
            done # _CHIPX

            # lay out the pairs
            _OF2="${LTNAME_LATENCYP}.${SFX}"

            # Log "Lay out chip pairs: $_OF2"
            printf "${FORMAT1}\n" ${HEADER1} > ${_OF2}

            (( _XCNT = 0 ))
            for _CHIPX in ${_CHIPSET}
            do
                (( _XCNT += 1 ))
                (( _YCNT = 0 ))

                for _CHIPY in ${_CHIPSET}
                do
                    if (( ${_CHIPX} != ${_CHIPY} ))
                    then
                        (( _YCNT += 1 ))
                        if (( ${_YCNT} >= ${_XCNT} ))
                        then
                            awk '{ if (($1=="'${_CHIPX}'") && ($2=="'${_CHIPY}'")) print $0 }' ${_OF1} >>${_OF2}
                            awk '{ if (($1=="'${_CHIPY}'") && ($2=="'${_CHIPX}'")) print $0 }' ${_OF1} >>${_OF2}
                            print >>${_OF2}
                        fi
                    fi

                done # _CHIPY
            done # _CHIPX
            cd ..
        done # _RDIR
        cd ..
    done # _PDIR
    return
}

# Consolidate all the run data into common files

function LTallpost {

    # Log "Post-processing latency data for all runs"

    for _PDIR in ${LTNAME_PREFETCH}.*
    do
        cd ${_PDIR} > /dev/null
        _CHIPSET=`cd $LTNAME_RUN.1; ls -1 lat.*.out | cut -f 2- -d "." | cut -f -1 -d "." | sort -nu | xargs`

        # consolidate standard deviations
        _IF1="${LTNAME_LATENCY}.${SFX}"
        _OF1="${LTNAME_ALLLATENCY}.${SFX}"
        _FLIST=$(find . -name "${_IF1}")

        # Skip if no files
        [[ ${_FLIST} == "" ]] && continue

        printf "${FORMAT1}" ${HEADER1} > ${_OF1}
        for _NODEX in ${LTNODE_SET}
        do
            for _NODEY in ${LTNODE_SET}
            do
                for _FILE in ${_FLIST}
                do
                    awk '{ if (( $1 =="'${_NODEX}'" ) && ( $2=="'${_NODEY}'" )) print $0 }' ${_FILE} >> ${_OF1}
                done
            done       # _CHIPY
            echo ""  >> ${_OF1}
        done           # _CHIPX

        # Consolidate pairs
        _IF2="${LTNAME_LATENCYP}.${SFX}"
        _OF2="${LTNAME_ALLLATENCYP}.${SFX}"
        _FLISTP=`find . -name "${_IF2}"`

        # Skip if no files
        [[ ${_FLIST} == "" ]] && continue

        printf "${FORMAT1}\n" ${HEADER1} >${_OF2}

        (( _XCNT = 0 ))
        for _CHIPX in ${_CHIPSET}
        do
            (( _XCNT += 1 ))
            (( _YCNT = 0 ))

            for _CHIPY in ${_CHIPSET}
            do
                if (( ${_CHIPX} != ${_CHIPY} ))
                then
                    (( _YCNT += 1 ))
                    if (( ${_YCNT} >= ${_XCNT} ))
                    then
                        for _FILE in ${_FLISTP}
                        do
                            awk '{ if (($1 == "'${_CHIPX}'") && ($2 == "'${_CHIPY}'")) print $0 }' ${_FILE} >> ${_OF2}
                            awk '{ if (($1 == "'${_CHIPY}'") && ($2 == "'${_CHIPX}'")) print $0 }' ${_FILE} >> ${_OF2}
                            echo "" >> ${_OF2}
                        done
                        echo "" >> ${_OF2}
                    fi
                fi
            done     # _CHIPY
        done         # _CHIPX
        cd ..

        # Display cache latencies
        _FM1="  %-12s : %s\n"
        echo ""
        echo ${DLINE}
        echo "Cache Latencies (ns)"
        echo ${SLINE}

        for _CHIP in ${LTCHIP_SET}
        do
            _OF3="${_CHIP}.cache.out"
            if [ ! -f ${_OF3} ]
            then
                echo "The file ${_OF3} does not exist."
                exit 2
            fi

            if [[ ${ARCH} == "POWER8" ]]
            then
                L1=`cat ${_OF3} | grep -m 1 "60 " | awk '{ print $2 }' | xargs`
                L2=`cat ${_OF3} | grep -m 1 "480 " | awk '{ print $2 }' | xargs`
                L3=`cat ${_OF3} | grep -m 1 "4096 " | awk '{ print $2 }' | xargs`
                L3_1=`cat ${_OF3} | grep -m 1 "34816 " | awk '{ print $2 }' | xargs`
                L4=`cat ${_OF3} | grep -m 1 "51200 " | awk '{ print $2 }' | xargs`
            elif [[ ${ARCH} == "POWER9" ]]
            then
                L1=`cat ${_OF3} | grep -m 1 "16 " | awk '{ print $2 }' | xargs`
                L2=`cat ${_OF3} | grep -m 1 "256 " | awk '{ print $2 }' | xargs`
                L3=`cat ${_OF3} | grep -m 1 "5120 " | awk '{ print $2 }' | xargs`
            else
                echo "${LTEXEC}: Unable to determine the architecture."
                exit 2
            fi

            echo  "CPU ${_CHIP} (Node $(CPUtoNode ${_CHIP}))"
            printf "${_FM1}" "L1" "${L1}"
            printf "${_FM1}" "L2" "${L2}"
            printf "${_FM1}" "L3" "${L3}"

            if [[ ${ARCH} == "POWER8" ]]
            then
                printf "${_FM1}" "Shared L3" "${L3_1} (approximate)"
                printf "${_FM1}" "L4" "${L4} (approximate)"
            fi
            echo ""
        done
        cd - > /dev/null

        # Display the memory latencies to the screen
        echo ${DLINE}
        echo "Memory Latencies (ns)"
        echo ${SLINE}
        cat ${_OF1}
        cd - > /dev/null

        # Display the stream bandwidth results
        echo ${DLINE}
        echo "Memory Bandwidth (MB/s)"
        echo ${SLINE}
        printf "${FORMAT1}" ${HEADER2}

        for _SRC_NODE in ${LTNODE_SET}
        do
            for _DST_NODE in ${LTNODE_SET}
            do
                _OF4="${_SRC_NODE}.${_DST_NODE}.${STNAME_OUT}"

                _COPY=`cat ${_OF4} | grep "Copy:" | awk '{ print $2 }'`
                _SCALE=`cat ${_OF4} | grep "Scale:" | awk '{ print $2 }'`
                _ADD=`cat ${_OF4} | grep "Add:" | awk '{ print $2 }'`
                _TRIAD=`cat ${_OF4} | grep "Triad:" | awk '{ print $2 }'`
                printf "${FORMAT3}" ${_SRC_NODE} ${_DST_NODE} ${_COPY} ${_SCALE} ${_ADD} ${_TRIAD}
            done
            echo ""
        done

        # Run at a system level if there is more than one node
        if [[ $(echo ${LTNODE_SET} | wc -w) > 1 ]]
        then
            _OF4="system.${STNAME_OUT}"

            _COPY=$(cat ${_OF4} | grep "Copy:" | awk '{ print $2 }')
            _SCALE=$(cat ${_OF4} | grep "Scale:" | awk '{ print $2 }')
            _ADD=$(cat ${_OF4} | grep "Add:" | awk '{ print $2 }')
            _TRIAD=$(cat ${_OF4} | grep "Triad:" | awk '{ print $2 }')

            printf "${FORMAT3}" "" "SYSTEM" ${_COPY} ${_SCALE} ${_ADD} ${_TRIAD}
            echo ""
        fi
        echo ${SLINE}

    done # _PDIR
    return
}

# Returns the node of the cpu
function CPUtoNode {
    echo ${chips[$1]}
    return
}

##############################################################################
# MAIN
##############################################################################

CMDLINE="$@"
while (( $# > 0 ))
do
    case $1 in
        -ps) # prefetch settings
            # this should always be "1" (off)
            # we'll allow this to be set for testing, but it won't be documented
            LTPREFETCH_SET="$2"
            shift 2
            ;;
        -nr) # number of runs
            LTRUNS="$2"
            shift 2
            ;;
        -ni) # number of iterations
            LTITERS="$2"
            shift 2
            ;;
        -pe) # pmcount event to trace
            LTPMEVENT="$2"
            shift 2
            ;;
        -bs) # Buffer size to use
            LT_BUFSIZE="$2"
            shift 2
            ;;
        -st) # STRIDE size to use
            LT_STRIDESIZE="$2"
            shift 2
            ;;
        -perf) # enable perf collection
            LTRUN_PMCOUNT="TRUE"
            shift
            ;;
        -log) # keep the log after running
            LT_LOG="TRUE"
            shift
            ;;
        -\?)
            Usage 0
            ;;
        -help)
            Usage 0
            ;;
        -*)
            print "ERROR: Unrecognized parameter: $1"
            Usage 1
            ;;
        *)
            break
            ;;
    esac
done

# Make sure we're run as root
if ! [ $(id -u) = 0 ]
then
    echo ""
    echo "Latter must be run as root or sudo to set prefetch and SMT mode."
    echo "Prefetch and SMT modes will be restored on exit of this script."
    echo "Exiting..."
    echo ""
    exit 1
fi

# Get the current speed (this will take a few seconds)
SPEED=`ppc64_cpu --frequency -t 5 | grep "avg:" | sed -e "s/avg:\t//"`

# Set the defaults
LTPREFETCH_SET=${LTPREFETCH_SET:-"1"}
LTRUNS=${LTRUNS:-"1"}
LTITERS=${LTITERS:-"5"}
LTPMEVENT=${LTPMEVENT:-"r000001C04E,r000002C048,r000003C04A,r000004C04C,r500fa,r600f4"}
LTRUNLIST=${LTRUNLIST:-"lat_mem_rd ${LTPOSTLIST}"}
LTDATADIR=${LTDATADIR:-${PRES}/latter.$(date +%Y-%m-%d.%T)}
LT_BUFSIZE=${LT_BUFSIZE:-"3000"}
LT_STRIDESIZE=${LT_STRIDESIZE:-"128"}
LTRUN_PMCOUNT=${LTRUN_PMCOUNT:-"FALSE"}
LT_LOG=${LT_LOG:-"FALSE"}

# Force things to be odd
LTRUNS=$(( ((${LTRUNS} / 2) * 2) + 1 ))
LTITERS=$(( ((${LTITERS} / 2) * 2) + 1 ))

# Static Variables
LTPMCMD="perf stat -e ${LTPMEVENT}"

let nodes[0]=0
typeset -A chips

LTCHIP_SET=`numactl --hardware | grep " cpus:" | awk '{ print $4 }' | xargs`
 
# Only pick up the NODES that have cpus
LTNODE_SET=`numactl --hardware | grep " cpus:" | awk '($4 != "") { print $2 }' | xargs`
LTNAME_RUN="run"
LTNAME_PREFETCH="prefetch"
LTNAME_LAT="lat"
LTNAME_LATENCY="latency.SD"
LTNAME_LATENCYP="${LTNAME_LATENCY}.pairs"
LTNAME_ALLLATENCY="latency.allruns.SD"
LTNAME_ALLLATENCYP="${LTNAME_ALLLATENCY}.pairs"
LTNAME_FINLATENCY="latency.allruns.latfinal"
LTNAME_FINLATENCYP="${LTNAME_FINLATENCY}.pairs"

# Some stream variables
STCMD="stream"
STNAME_OUT="stream.out"

# Setup node array
i=0
for _NODE_X in ${LTNODE_SET}
do
    nodes[$i]=${_NODE_X}
    (( i = i + 1 ))
done

# Create association between chips(cpu's) and nodes
i=0
for _CHIP_X in ${LTCHIP_SET}
do
    chips[${_CHIP_X}]=${nodes[$i]}
    (( i = i + 1 ))
done

# Create the log directory
mkdir -p ${LTDATADIR}
OUTLOG="${LTDATADIR}/log.out"
OUTCONFIG="${LTDATADIR}/config.out"

# test for perf if it is requested
LTNAME_OUT="out"
LTNAME_PMCOUT="perf.out"

if [[ ${LTRUN_PMCOUNT} == "TRUE" ]]
then
    if  ! type perf > /dev/null
    then
        Log "Cannot find perf executable, skipping those tests"
        LTPMEVENT="perf not available"
        LTRUN_PMCOUNT="FALSE"
    fi
    SFX=${LTNAME_PMCOUT}
    LT_LOG="TRUE"
else
    LTPMEVENT="perf not requested"
    SFX=${LTNAME_OUT}
fi

StateLog ${CMDLINE} | tee ${OUTLOG}
echo ${SLINE}

for RUN in ${LTRUNLIST}
do
    cd ${LTDATADIR}
    LT${RUN}
done

# MLog "Processing complete"
echo "" >> ${OUTLOG}
echo "" >> ${OUTLOG}

if [[ ${LT_LOG} != "TRUE" ]]
then
    rm -r ${LTDATADIR}
fi
exit 0

