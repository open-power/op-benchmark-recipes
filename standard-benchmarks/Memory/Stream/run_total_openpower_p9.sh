#!/bin/bash


source common.rc
ppc64_cpu --dscr=7

echo "OMP_NUM_THREADS=$totalcorenum GOMP_CPU_AFFINITY=0-$lastthread:4 ./stream"
OMP_NUM_THREADS=$totalcorenum GOMP_CPU_AFFINITY=0-$lastthread:4 ./stream

ppc64_cpu --dscr=$current_dscr
