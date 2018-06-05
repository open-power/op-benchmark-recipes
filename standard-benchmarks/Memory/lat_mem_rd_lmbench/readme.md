## Running LMbench's lat_mem_rd on Power Systems

Target audience: OpenPOWER partners; IBM on-site application engineers

Make sure the _build essentials kit_ and _numactl_ are installed. In Ubuntu:
```bash
apt install build-essential numactl
```

### Steps
#### 1. Download lmbench3 and untar it.

Please visit http://www.bitmover.com/lmbench/ and download lmbench 3.0.
You can use below command line to download: 

```bash
wget 'http://www.bitmover.com/lmbench/lmbench3.tar.gz'
```

Untar it with below command:

```bash
tar xf lmbench3.tar.gz # creates lmbench3 directory
```

#### 2. Modify src/Makefile and make binary

Build binary using the provided Makefile.new with below code:

```bash
cp Makefile.new lmbench3/src/Makefile
cd lmbench3/src/
make
cd -
```

#### 3. Run lat_mem_rd

```bash
echo always > /sys/kernel/mm/transparent_hugepage/enabled
ppc64_cpu --smt=off
ppc64_cpu --dscr=1
cd lmbench3/bin
numactl --physcpubind 0 --membind 0 ./lat_mem_rd 2000 512 # local memory check
numactl --physcpubind 0 --membind 8 ./lat_mem_rd 2000 512 # cross memory check
```
