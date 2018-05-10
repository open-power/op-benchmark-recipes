## Stream on OpenPOWER systems
Target audience: OpenPOWER partners; IBM on-site application engineers
### Steps:
#### 1. Get stream code:
```bash
 wget 'http://www.cs.virginia.edu/stream/FTP/Code/stream.c'
```
#### 2. Compile with gcc with below array size
```bash
 gcc -m64 -O3 -fopenmp -DSTREAM_ARRAY_SIZE=536895856 -DNTIMES=20 -mcmodel=large stream.c -o stream
```
#### 3. Running with "smt=off" and OpenMP affinity
Here we assume System under test is a two node system, each node is 20 cores and each core has 8 threads. This will make the logical CPU as 0-159. 

System will be set up with "--smt=off", so only logical CPU "0,8,16,...,156" are "online". Other logical CPU are marked with "offline". 

Command line will be below:
```bash
sudo ppc64_cpu --smt=off
sudo ppc64_cpu --dscr=7
OMP_NUM_THREADS=40 GOMP_CPU_AFFINITY=0-159:8 ./stream
```

For OMP_NUM_THREADS=40, it means 40 copies of stream will be used. So each core will run a copy (with *"--smt=off"*).

For GOMP_CPU_AFFINITY=0-159:4, it means CPU binding is using "0,4,8,12,...,156" CPU binding is starting with 0 and step is 4.

For a 16 core system with one node, command line will be:
```bash
sudo ppc64_cpu --smt=off
sudo ppc64_cpu --dscr=7
OMP_NUM_THREADS=16 GOMP_CPU_AFFINITY=0-63:4 ./stream
```

For a 22 core with two node, command line will be:
```bash
sudo ppc64_cpu --smt=off
sudo ppc64_cpu --dscr=7
OMP_NUM_THREADS=44 GOMP_CPU_AFFINITY=0-175:4 ./stream
```
#### 4. Testing stream for cross node (NUMA).
First find NUMA node number using `numactl --hardware` or `numactl -H`. 

Assume a two node system and NUMA node number are **node_a** and **node_b**.

Moreover, assume there are 20 cores in each NUMA node, and logical CPU 0-79 is on **node_a** and 80-159 is on **node_b**. 

>Note: **node_a** and **node_b** are usually 0 and 1 but some systems may have different node numbering, like 0 and 8.
```bash
sudo ppc64_cpu --smt=off
sudo ppc64_cpu --dscr=7
OMP_NUM_THREADS=20 GOMP_CPU_AFFINITY=0-79:4 numactl --membind <node_b> ./stream
OMP_NUM_THREADS=20 GOMP_CPU_AFFINITY=80-159:4 numactl --membind <node_a> ./stream
```
#### 5. Checking the result.
Results are printed to screen. 

Please check Copy/Scale/Add/Triad MBytes/sec
### FAQ:
#### Q0: Is there an official FAQ for stream workload from the author?
**A0**: Yes. Please see http://www.cs.virginia.edu/stream/ref.html
#### Q1: Why tuning SMT off?
**A1**: There will be very small performance gap between SMT on and SMT off. To getbest performance, it's good to use SMT off.
#### Q2: Why change STREAM_ARRAY_SIZE instead of using default value?  
**A2**: It's required by stream to use at least four times of last level cache for STREAM_ARRAY_SIZE. 
#### Q3. What is OpenPOWER POWER9 system memory bandwidth theoretical value?
**A3**: For OpenPOWER system (power9 based) with 4 memory channels, and memory speed is 2133MHz, then the theoretical memory bandwidth is 	`4(ch)*8(transaction_to_byte)*2.133(GHz)*2(socket)`, which is 136.5GB/sec. Usually stream's triad will get 80% - 85% efficiency.
