#
HARNESS="/spec/spec2017/v1.0/"
CONFIG=config/LE64Test_P9.cfg
COPIES=$1

#---------------------------------------------------------------------------------------------------

ppc64_cpu --dscr=0

#---------------------------------------------------------------------------------------------------

cd $HARNESS
ulimit -s unlimited
. shrc
echo 0 > /proc/sys/kernel/randomize_va_space
echo always > /sys/kernel/mm/transparent_hugepage/enabled
mount -t hugetlbfs hugetlbfs /dev/hugepages
export HUGETLB_MORECORE=yes
export HUGETLB_VERBOSE=0
echo 60000 > /proc/sys/vm/nr_hugepages

# INT ----------------------------------------------------------------------------------------------

runcpu --config=$CONFIG --copies=$COPIES --tune=peak -i ref -S fdpr -n 1 -l -I -N intrate
rm -Rf ${HARNESS}*/benchspec/CPU/*/run/*

# FP -----------------------------------------------------------------------------------------------

runcpu --nobuild --config=$CONFIG --copies=$COPIES --tune=peak  -i ref -S fdpr -n 1 -l -I -N fprate
rm -Rf ${HARNESS}*/benchspec/CPU/*/run/*

#---------------------------------------------------------------------------------------------------
