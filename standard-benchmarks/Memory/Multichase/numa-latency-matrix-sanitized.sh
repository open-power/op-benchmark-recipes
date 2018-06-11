#!/bin/bash
# print out a matrix of local/remote memory latencies such as:
#
#    cpu:      0      1      2      3
# mem:
#      0:   95.4  104.4  101.0  137.7
#      1:  105.6   94.5  137.1  106.0
#      2:  102.8  137.5   94.6  105.8
#      3:  135.3  102.4  102.9   95.1
#
# which says that if the code is running on node 1 and memory on
# node 2 then the latency is 137.5ns.

if [ ! -d /sys/devices/system/node ]; then
        echo "/sys/devices/system/node doesn't exist" 1>&2
        exit 1
fi

nodes="$(for i in /sys/devices/system/node/node[0-9]*; do basename $i | sed 's/node//'; done)"

printf "   cpu:"
for i in $nodes; do
        printf "%7u" $i
done
printf "\nmem:\n"

# find min, max local and max remote
min_local=-1
min_local_cpu=0
min_local_mem=0
max_local=-1
max_local_cpu=0
max_local_mem=0

min_remote=-1
min_remote_cpu=0
min_remote_mem=0
max_remote=-1
max_remote_cpu=0
max_remote_mem=0

nodes_no=0
sum_local=0
sum_remote=0

# parameters used for P9 DD1 measurements
# stride : needs to be larger than 256B as Power has 128B cacheline
# size   : 1g seems to work
stride=1024
size=${1:-1g}

for m in $nodes; do
        printf "%6u:" $m
	nodes_no=$(($nodes_no + 1))
        for c in $nodes; do
		val=`numactl --membind=$m --cpubind=$c -- ./multichase -s $stride -m $size`
		val=${val// /}	# trim val
		# test value is numeric
		if [ `python -c "print '$val'.replace('.','',1).isdigit()"` == "False" ]; then
		  printf " %s" $val
		  continue
		fi
                printf "%7.1f" $val

		if [ $c -eq $m ]; then # ---local---
		  sum_local=`python -c "print $sum_local + $val"`
		  # min local
		  if [ `python -c "print $min_local==-1"` == "True" ] || 
		      [ `python -c "print $min_local > $val"` == "True" ]; then
		    min_local=$val
		    min_local_cpu=$c
		    min_local_mem=$m
		  fi
		  # max local
		  if [ `python -c "print $max_local==-1"` == "True" ] || 
		      [ `python -c "print $max_local < $val"` == "True" ]; then
		    max_local=$val
		    max_local_cpu=$c
		    max_local_mem=$m
		  fi
		else # ---remote---
		  sum_remote=`python -c "print $sum_remote + $val"`
		  #min remote
		  if [ `python -c "print $min_remote==-1"` == "True" ] || 
		      [ `python -c "print $min_remote > $val"` == "True" ]; then	
		    min_remote=$val
		    min_remote_cpu=$c
		    min_remote_mem=$m
		  fi
		  #max remote
		  if [ `python -c "print $max_remote==-1"` == "True" ] || 
		      [ `python -c "print $max_remote < $val"` == "True" ]; then	
		    max_remote=$val
		    max_remote_cpu=$c
		    max_remote_mem=$m
		  fi
		fi
	done
        printf "\n"
done

average_total=`python -c "print ($sum_local + $sum_remote) / ($nodes_no * $nodes_no)"`
average_local=`python -c "print $sum_local / $nodes_no "`
if [ $nodes_no -eq 1 ]; then
  min_remote=$min_local
  max_remote=$max_local
  average_remote=$average_local
else
  average_remote=`python -c "print $sum_remote / ($nodes_no * ($nodes_no - 1))"`
fi

echo ""
echo "Min local $min_local on cpu $min_local_cpu and mem $min_local_mem"
echo "Max local $max_local on cpu $max_local_cpu and mem $max_local_mem"
echo "Min remote $min_remote on cpu $min_remote_cpu and mem $min_remote_mem"
echo "Max remote $max_remote on cpu $max_remote_cpu and mem $max_remote_mem"
echo "Average local $average_local"
echo "Average remote $average_remote"
echo "Average total $average_total"
echo ""

# EOF
