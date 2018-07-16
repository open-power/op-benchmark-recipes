#based out of https://www.spec.org/jbb2015/results/res2018q2/jbb2015-20180328-00289.html
ulimit -n 100000
ppc64_cpu --dscr=1

## Memory
echo 0 > /proc/sys/vm/nr_hugepages
free && sync && echo 3 > /proc/sys/vm/drop_caches && free

pg_size=$(grep -i hugepagesize /proc/meminfo |awk '{print $2}')
pg_num=$(echo $(( $(numactl -H |grep "node 0 size" |awk '{print $4}') * 9 / 10 / $(( $pg_size / 1024 )) )) )

for x in `find /sys/devices/system/node/ -iname cpu[0-9]* | sed "s/cpu.*//" | sort -u` ; do 
  echo $pg_num >  ${x}/hugepages/hugepages-${pg_size}kB/nr_hugepages 
done

## OS scheduler
echo 1000 > /proc/sys/kernel/sched_migration_cost_ns
echo 150000000 > /proc/sys/kernel/sched_min_granularity_ns
echo 1000000000 > /proc/sys/kernel/sched_wakeup_granularity_ns

## CPU governor
cpupower frequency-set -g performance
