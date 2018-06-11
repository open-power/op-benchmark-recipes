#!/bin/bash

cache_line_size=128

nodes="$(for i in /sys/devices/system/node/node[0-9]*; do basename $i | sed 's/node//'; done)"
threads_per_node="$(ls -1d /sys/devices/system/node/node0/cpu[0-9]* | wc -l)"

for threads in $(seq 1 ${threads_per_node})
do
  echo "INFO: ${threads}T"
  echo ""
  for cpu in $nodes
  do
    echo -n -e "\tCPU${cpu}"
  done
  echo ""
  for memory in $nodes
  do
    echo -n -e "MEM${memory}"
    for cpu in $nodes
    do
      multichase=$(numactl --membind=${memory} --cpubind=${cpu} -- ./multichase -t${threads} -n5 -c parallel8 -s 4096 -m1g -T1m -v | tail -1)
      result=$(echo "scale=3; (${cache_line_size})/(($multichase)/(${threads}))" | bc -l -q)
      echo -n -e "\t${result}"
    done
    echo ""
  done
  echo ""
done

# EOF
