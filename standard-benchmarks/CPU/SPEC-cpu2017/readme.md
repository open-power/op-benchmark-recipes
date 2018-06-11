# Running SPEC CPU2017 on Power ppc64le systems
## Steps

### 1. Install Advanced Toolchain (AT)
Please refer to URL:
https://developer.ibm.com/linuxonpower/advance-toolchain/advtool-installation/

Currently AT is at version 11.0, which has been tested to run SPEC cpu2017. 

>*Note: download and install Advanced Toolchain is expected to be slow.*
### 2. Install IBM XLC and XLF compilers (includes runtime)
Download and install IBM XL C/C++ for Linux:
https://www.ibm.com/developerworks/downloads/r/xlcpluslinux/index.html

Download and install IBM XL Fortran for Linux: 
https://www.ibm.com/developerworks/downloads/r/xlfortranlinux/index.html

### 3. Install IBM Feedback Directed Program Restructing (FDPR) for Linux on Power
The ppc64le `fdprpro` package, a post-link optimizer, can be found at: https://developer.ibm.com/linuxonpower/sdk-packages/
>This is not necessary to run binaries, but it is highly recommended.
### 4. Install SPEC CPU2017 package
##### 4.1 Extract SPEC CPU2017 package: 
Assuming SPEC CPU2017 license has been purchased from http://spec.org/, and the code package has been downloaded:  
```bash
mkdir -p /home/spec/cpu2017 # this path will be used throughout the entire recipe 
tar xvf <cpu2017-1.x.tar> -C /home/spec/cpu2017
```

Note: if you obtain an ISO version of CPU2017, please find **cpu2017.tar.xz** under **install_archives/** directory.    
```bash
mkdir -p /mnt/iso
mount -oloop,ro <cpu2017-1.x.iso> /mnt/iso
tar xf /mnt/iso/install_archives/cpu2017.tar.xz -C /home/spec/cpu2017
umount /mnt/iso
```    
##### 4.2 Install SPEC CPU2017 
Please invoke **./install.sh** to install SpecCPU2017.
```bash
cd /home/spec/cpu2017 
./install.sh 
```

You will need type "yes" to confirm installation directory. This may take a minute or two to finish.
>For more information please refer to: https://www.spec.org/cpu2017/Docs/install-guide-unix.html
### 5. Compile the SPEC CPU2017 binary for ppc64le
Copy the provided config file to `/home/spec/cpu2017/config` and edit it so the paths are correct. 
>Provided config file assumes FDPR has been installed. See `step 3`.

Calculate the number of _hugepages_ per 
the [hugetlbpage support page](https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt). Our guideline is 480-800 2MB (RPT) hugepages per copy.

```bash
source ./shrc                           # Source SPEC shrc
ulimit -s unlimited                     # Set stack size to unlimited

export HUGETLB_MORECORE=yes             # Enable the hugepage malloc() feature
export HUGETLB_VERBOSE=0                # Quiet
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/FDPR"     # Assumed installation path for FPDR
export LD_PRELOAD="/opt/at11.0/lib64/libhugetlbfs.so"   # Assumed installation path for AT11.0
export MALLOC_MMAP_MAX_="0"             # Disable mmap for servicing large allocation requests
export XLFRTEOPTS="intrinthds=1"        # Number of threads for parallel execution of MATMUL and RANDOM_NUMBER XLF procedures
export XLSMPOPTS="spins=0:yields=0:schedule=STATIC:stack=8000000" # set XLC scheduling/parallelization/tuning runtime options
export TCMALLOC_MEMFS_MALLOC_PATH="/dev/hugepages/"

echo $num > /proc/sys/vm/nr_hugepages   # Huge pages allocated i.e. $num=11520 for 24 copies
sync; echo 3 > /proc/sys/vm/drop_caches # Drop cache 
swapoff -a                              # Turn off all swap spaces

runcpu --action validate --config $CONFIG --tuning peak -S $SYMBOL # previous --rate option is not longer neeeded
# $CONFIG is the configuration file 
# $SYMBOL is the system configuration in the config file, i.e. p9_32_core
```
>For more information on `runcpu` please refer to: https://www.spec.org/cpu2017/Docs/runcpu.html 

### 6. Run
We have provided a script to facilitate running the benchmark. The only requirement is to provide the number of copies for a SPECrate run.
```bash
./RUN_2017.sh 4 # run 4 copies
```
