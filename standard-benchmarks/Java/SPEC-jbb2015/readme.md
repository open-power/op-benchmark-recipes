# Running SPECjbb2015 on OpenPOWER(POWER9) systems
Target audience: OpenPOWER partners; IBM on-site application engineers
## Steps:
### 1. Get and install SPECjbb2015 kits:
By the time of this guide is was written, the version of SPECjbb2015 is 1.01.

Please copy all the files and directories to the installation folder, i.e `/spec/specjbb2015/`.

```bash
sudo mkdir /mnt/specjbb_iso
sudo mount -oloop,ro SPECjbb2015-1_01.iso /mnt/specjbb_iso
sudo mkdir -p /spec/specjbb2015/
sudo cp -a /mnt/specjbb_iso/* /spec/specjbb2015/
```
### 2. Install IBM JDK8:
The latest version of the IBM JAVA SDK can be obtained at https://developer.ibm.com/javasdk/downloads/sdk8/
### 3. Copy over the patch files and tuning file:
```bash
sudo cp run_multi.sh.patch /spec/specjbb2015/
sudo cp config/specjbb2015.props.patch /spec/specjbb2015/config/
sudo cp tune.p9.sh /spec/specjbb2015/
```
### 4. Patch the default "run_multi.sh" and "specjbb2015.props" files:
The default files will have ".orig" appended to the filename while the contents of "run_multi.sh" and "specjbb2015.props" will be changed.
```bash
cd /spec/specjbb2015
patch -b < run_multi.sh.patch
cd /spec/specjbb2015/config
patch -b < specjbb2015.props.patch
```
### 5. Verify/modify "run_multi.sh" and "tune.p9.sh", if necessary:
The patched "run_multi.sh" uses numactl to bind processor/memory for a system with 2 sockets (12 cores per socket) with at least 450GB of memory.
Please identify how many sockets, cores and memory the SUT has and modify "run_multi.sh" and "tune.p9.sh" (particularly hugepage allocation) accordingly.
### 6. Launch "run_multi.sh" and check result:
```bash
sudo screen -L ./run_multi.sh
# Check the result in the "/spec/specjbb2015/<timestamp>" directory. 
sudo grep "RUN RESULT" /spec/specjbb2015/<timestamp>/controller.out
```
