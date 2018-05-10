# Linpack_HPL running with OpenBLAS
Target audience: OpenPOWER partners
> instructions assume Ubuntu installation.

Normal user "openpower" is used for steps below.
#### 1. Install supported packages:
1. Download and install IBM XLF for linux runtime and add-on:
 
   [IBM XL Fortran Runtime for Linux 15.1.2](http://www-01.ibm.com/support/docview.wss?uid=swg24040216)
     
   [IBM XL Fortran Addons for Linux 15.1.2](http://www-01.ibm.com/support/docview.wss?uid=swg24040219)

   >Note: Version 15.1.4 and 15.1.5 have known issue for working with openblas and HPL2.2.*

2. Install Advance toolchain 

   AT9.0 is verified. Later version should be ok (or better). To install AT, please refer to below link:

   https://developer.ibm.com/linuxonpower/advance-toolchain/advtool-installation/

3. Install OpenMPI
 
   ```bash
   sudo apt install openmpi-common libopenmpi-dev openmpi-bin libopenmpi2
   ```	

4. Build OpenBLAS
 
   Currently, 0.2.19 version is verified. Later versions should be fine (or better) but have not been verified. To download OpenBLAS and build it:

      ```bash
      git clone `http://github.com/xianyi/OpenBLAS/`
      # alternatively you could : wget 'http://github.com/xianyi/OpenBLAS/archive/v0.2.19.tar.gz'
      cd OpenBLAS
      make -j20
      sudo mkdir /opt/libopenblas
      sudo make PREFIX=/opt/libopenblas/ install
     ```
#### 2. Make Linpack/HPL (2.2)
Please make sure `$PATH`, `LD_LIBRARY_PATH`, `$CC` and `$CXX` are pointing to the values below:
   
   ```bash
   export PATH=/opt/atX.0/bin:$PATH # X being the version you've installed
   export CC=/opt/atX.0/bin/gcc
   export CXX=/opt/atX.0/bin/g++
   export LD_LIBRARY_PATH=/opt/atX.0/lib64:/opt/libopenblas/lib:/opt/ibm/xlsmp/4.1.X/lib:/opt/ibm/xlf/15.1X/lib
   ```
		
Please also check Make.ppc64_le_openblas file first:
   
   ```bash
   wget 'http://www.netlib.org/benchmark/hpl/hpl-2.2.tar.gz'
   tar xf hpl-2.2.tar.gz 
   cp Make.ppc64le_openblas hpl-2.2
   # MODIFY Make.ppc64le_openblas
   cd hpl-2.2 
   make arch=ppc64le_openblas 
   ```
   
> NOTE: Before running make, ensure all variables and paths are pointing to the correct versions/values in the Makefile.ppc64_le_openblas file.
#### 3. Run Linpack/HPL
1. Prepare HPL.dat with tune value. 
   
   Please refer to [Linpack HPL.dat Tuning](Linpack_HPL.dat_tuning.md).
	
2. Enable HugeTLB
   
   First get Hugepagesize:  
       
   ```bash
   cat /proc/meminfo | grep Hugepagesize
   Hugepagesize: 16384 kB
   ```

   Assuming you have calculated *N* using the document above:

   ```bash
   #Calculate LP for number of large page:
   LP = ( N * N * SIZEOF_DOUBLE ) / HUGEPAGE_SIZE
   #For example, with 128GB memory you will get N with 115606 from step 5.
   LP = (115606 * 115606 * 8) / (16384 * 1024) = 6372
   ```

   Set *hugepage* number with below command:
     
   ```bash
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
   echo 6372 > /proc/sys/vm/nr_hugepages # LP
   ```

   *hugetlbfs* should be mounted on */libhugetlbfs* with *type hugetlbfs (rw)*
     
   ```bash
   mkdir /libhugetlbfs
   groupadd libhuge
   chgrp libhuge /libhugetlbfs
   chmod 770 /libhugetlbfs
   usermod openpower -G libhuge # (assume openpower user is the current user)
   mount -t hugetlbfs hugetlbfs /libhugetlbfs
   export HUGETLB_MORECORE=yes
   ```
		
  3.Check compiled results by running `ldd xhpl`
   
   ```bash
   /opt/at11.0/bin/ldd bin/ppc64le_openblas/xhpl 	# example
	linux-vdso64.so.1 (0x00007751bb1b0000)
	libopenblas.so.0 => /opt/libopenblas/lib/libopenblas.so.0 (0x00007751bad30000)
	libxlf90_r.so.1 => /opt/ibm/lib/libxlf90_r.so.1 (0x00007751ba380000)
	libxlfmath.so.1 => /opt/ibm/lib/libxlfmath.so.1 (0x00007751ba350000)
	libxlomp_ser.so.1 => /opt/ibm/lib/libxlomp_ser.so.1 (0x00007751ba320000)
	libmpi.so.20 => /usr/lib/powerpc64le-linux-gnu/libmpi.so.20 (0x00007751ba190000)
	libc.so.6 => /opt/at11.0/lib64/power8/libc.so.6 (0x00007751b9f60000)
	libhugetlbfs.so => /opt/at11.0/lib64/libhugetlbfs.so (0x00007751b9f20000)
	libm.so.6 => /opt/at11.0/lib64/power8/libm.so.6 (0x00007751b9de0000)
	libpthread.so.0 => /opt/at11.0/lib64/power8/libpthread.so.0 (0x00007751b9d90000)
	libgomp.so.1 => /opt/at11.0/lib64/power8/libgomp.so.1 (0x00007751b9d30000)
	/opt/at11.0/lib64/ld64.so.2 (0x00007751bb1d0000)
	librt.so.1 => /opt/at11.0/lib64/power8/librt.so.1 (0x00007751b9d00000)
	libgcc_s.so.1 => /opt/at11.0/lib64/power8/libgcc_s.so.1 (0x00007751b9cc0000)
	libdl.so.2 => /opt/at11.0/lib64/power8/libdl.so.2 (0x00007751b9c90000)
	libopen-rte.so.20 => /usr/lib/powerpc64le-linux-gnu/libopen-rte.so.20 (0x00007751b9bc0000)
	libopen-pal.so.20 => /usr/lib/powerpc64le-linux-gnu/libopen-pal.so.20 (0x00007751b9ae0000)
	libhwloc.so.5 => /usr/lib/powerpc64le-linux-gnu/libhwloc.so.5 (0x00007751b9a70000)
	libutil.so.1 => /opt/at11.0/lib64/power8/libutil.so.1 (0x00007751b9a40000)
	libnuma.so.1 => /usr/lib/powerpc64le-linux-gnu/libnuma.so.1 (0x00007751b9a10000)
	libltdl.so.7 => /usr/lib/powerpc64le-linux-gnu/libltdl.so.7 (0x00007751b99e0000)
   ```

  4. Run *xhpl* with below scripts (using openpower as user)
		
   Please create **run_hpl.sh** and run with *screen* utility
      
   ```bash       
   cat run_hpl.sh
    #!/bin/bash
   
    export LD_LIBRARY_PATH=/opt/libopenblas/lib:/opt/ibm/lib:/opt/ibm/lib:$LD_LIBRARY_PATH
    export HUGETLB_MORECORE=yes
    
    cd hpl-2.2/bin/ppc64le_openblas
    mpirun -np <corenum> -bind-to core --mca btl sm,self,tcp xhpl
   
    ## END OF FILE
       
   chmod a+x ./run_hpl.sh
   screen -L ./run_hpl.sh
   ```
