#!/bin/bash
#####################################################################################
# Copyright (c) 2017 IBM Corporation.
# All rights reserved. This program and the accompanying materials
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#************************************************************************************
# FUNCTION:
# Script that runs the multichase benchmark tool.
#************************************************************************************
# Contributors:
#   IBM Corporation, Ben Gibbs - initial implementation and documentation.
#####################################################################################
# for  lcpu in `seq 0 ${THRDS_PER_CORE} $((NUM_LCPUS - 1))`
# do

THRDS_PER_CORE=`lscpu | grep "Thread(s) per core:" | awk -F: '{ print $2 }' | xargs`
NUM_CORES=`ppc64_cpu --cores-on | awk '{ print $NF }'`
NUM_LCPUS=`echo "scale=0; ${NUM_CORES} * ${THRDS_PER_CORE}" | bc`

renice -n -20 $$
lcpu=8
echo "stride 8K 16K 32K 64K 128K 256K 512K 4M 8M 10M 16M 128M 256M"

for stride in 64 128 256 512 1024
do
    run1=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 8k`
    run2=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 16k`
    run3=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 32k`
    run4=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 64k`
    run5=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 128k`
    run6=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 256k`
    run7=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 512k`
    run8=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 4m`
    run9=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 8m`
    run10=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 10m`
    run11=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 16m`
    run12=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 128m`
    run13=`numactl --localalloc --physcpubind=${lcpu} ./multichase -s ${stride} -m 256m`
    printf "%d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f\n" ${stride} ${run1} ${run2} ${run3} ${run4} ${run5} ${run6} \
		${run7} ${run8} ${run9} ${run10} ${run11} ${run12} ${run13}
done

exit 0
