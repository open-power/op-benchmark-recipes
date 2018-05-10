#!/bin/bash

export LD_LIBRARY_PATH=/opt/libopenblas/lib:/opt/ibm/lib:/opt/ibm/lib:$LD_LIBRARY_PATH
export HUGETLB_MORECORE=yes

ppc64_cpu --smt=off
cd hpl-2.2/bin/ppc64le_openblas
mpirun --allow-run-as-root -np 20 -bind-to core --mca btl sm,self,tcp xhpl 
