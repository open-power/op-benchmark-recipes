# SPECjbb2015 Enablement Kit

**Ingredients**
 - Hardware: System with about 10GB memory per core, 1GB of storage space on disk with a recent Linux ppc64LE  version installed.
 - SPECjbb2015 Kit from SPEC site
 - Open Power kit from IBM  for SPECjbb2015. Provides config files and run scripts and IBM JDK, etc. to run on Power.
- Steps (Procedure)
  - Download and install kit
  - Run the benchmark
  - Monitoring the runs progress and get the results
  - Additional information
  
  
**1) Download the SPECjbb2015 kit from the SPEC website**.

  [https://www.spec.org/order.html](https://www.spec.org/order.html)

For internal IBM use only since IBM has a license, download from the openperf public GSA space as follows:

  ```bash
  wget 'http://ausgsa.ibm.com/projects/o/openperf/openpower/public/jbb2015/SPECjbb2015-1.00.zip'
  ```

**2) Download the additional scripts and configuration files need to run the benchmark  ** on Power (specjbb2015.validation.kit.zip) :**

  ```bash
  wget 'http://ausgsa.ibm.com/projects/o/openperf/openpower/public/jbb2015/specjbb2015.validation.kit.zip'
  ```

**3) Unzip the SPECjbb2015 zip file that obtained from the SPEC website on your Power Linux (ppc64le) box.**

**4) cd to _SPECjbb2015_ dir created in the above step and unzip specjbb2015.validation.kit.zip there to get the additional scripts and configuration files needed to run the benchmark on Power Linux.**

(please chose to overwrite all files as this zip will replace the config files for the benchmark)



## Running the benchmark (run as root user)

Before running, make sure the _numactl_ package is installed and the system smt setting is _on_. In Ubuntu:
```bash
apt install numactl && ppc64_cpu --smt=on
```

Inside the _SPECjbb2015_ dir, depending of the Power machine (number of sockets and cores) run the appropriate script below :

    Single socket, 10 cores (Habanero), run : ./run_multi.1socket.10core.sh 
    
    Two sockets, 20 cores (10 cores/socket, Firestone) run: ./run_multi.2socket.20core.sh
    
    Two sockets, 24 cores - DCM (2 chips and 12 cores/socket, Tuleta) run: ./run_multi.2socket.dcm.24core.sh

If your configuration is different from above, the scripts can be modified for your hardware. 

Basically the number of Groups in the benchmark depend on the number of NUMA nodes in the machine, and the processor binding depends on the number of cores in each NUMA node. The differences in the scripts above illustrate the changes required.

Note : The scripts apply the appropriate Linux tuning to the machine before running the benchmarks by calling tune.sh  automatically, so this does not have to be done as a separate step.

- Monitoring the progress of the run and getting the results

 The run  takes about 2 hours to complete. Each run creates a results directory with the current time stamp as the name.

During the run you can cd to it and &quot;tail -f controller.out&quot; to watch the progress of the run.

When the run ends,  the end of this file (controller.out) has a message reporting the &quot;maxjOPs&#39; and &quot;critical&quot; jOPs for the run which are the metrics of interest

- Additional information

If you are interested in more details about the benchmark please see the SPEC link below :

  [https://www.spec.org/jbb2015](https://www.spec.org/jbb2015/) [/](https://www.spec.org/jbb2015/)

The link has a Users Guide and details of what the benchmark does, and other details, if you are interested.

Note : If needed, the kit can be run with OpenJDK, besides the IBM JDK included in the kit. 
