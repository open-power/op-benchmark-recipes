pkill java
ulimit -n 100000
ppc64_cpu --dscr=1

## Memory
echo 0 > /proc/sys/vm/nr_hugepages
free && sync && echo 3 > /proc/sys/vm/drop_caches && free

## OS scheduler
echo 1000 > /proc/sys/kernel/sched_migration_cost_ns
echo 150000000 > /proc/sys/kernel/sched_min_granularity_ns
echo 1000000000 > /proc/sys/kernel/sched_wakeup_granularity_ns

## CPU governor
cpupower frequency-set -g performance -u 3.8Ghz -d 3.8Ghz
