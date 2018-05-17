#!/bin/bash

ulimit -s unlimited
ppc64_cpu --dscr=0
ppc64_cpu --smt=4

echo never > /sys/kernel/mm/transparent_hugepage/enabled

threadnum=$(expr $(lscpu -p=cpu | tail -n 1) + 1)
corenum=$(expr $(lscpu -p=core | tail -n 1) + 1)
echo "Total core number: $threadnum"
echo "Total thread number: $corenum"
LPSZ=2M

if [ $LPSZ == "2M" ] ; then
	LPNUM=$(expr 512 \* $threadnum)
fi

echo "Hugepage number(2M): $LPNUM"

sysctl vm.nr_hugepages=$LPNUM


source shrc

runspec -c LE64Test_P9 --define p9_${corenum}_core=1 --define install_path=$(pwd) --tune base --rate --size=ref fp
runspec -c LE64Test_P9 --define p9_${corenum}_core=1 --define install_path=$(pwd) --tune peak --rate --size=ref fp
