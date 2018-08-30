# Running [SPECjbb2015](https://www.spec.org/jbb2015/) and OpenJDK on OpenPOWER systems

## Steps:
### 1. Install SPECjbb2015 kit:
By the time of this guide is was written, the version of SPECjbb2015 is 1.01.

Please copy all the files and directories to the installation folder, i.e `/spec/specjbb2015/`.

```bash
sudo mkdir /mnt/specjbb_iso
sudo mount -oloop,ro SPECjbb2015-1_01.iso /mnt/specjbb_iso
sudo mkdir -p /spec/specjbb2015/
sudo cp -a /mnt/specjbb_iso/* /spec/specjbb2015/
```
### 2. Install Open JDK8:
Please follow the instructions in http://openjdk.java.net/install/index.html 
### 3. Copy over the patch files and tuning file:
```bash
sudo cp run_multi.sh.patch /spec/specjbb2015/
sudo cp specjbb2015.props.patch /spec/specjbb2015/config/
sudo cp tune.openjdk.sh /spec/specjbb2015/
```
### 4. Patch the default "run_multi.sh" and "specjbb2015.props" files:
The default files will have *.orig* appended to the filename while the contents of `run_multi.sh` and `specjbb2015.props` will be changed.
```bash
cd /spec/specjbb2015
patch -b < run_multi.sh.patch
cd /spec/specjbb2015/config
patch -b < specjbb2015.props.patch
```
### 5. Verify/modify "run_multi.sh" and "tune.p9.sh", if necessary:
The patched `run_multi.sh` uses **numactl** to bind processor/memory for a system with 2 sockets (12 cores per socket) with at least 512GB of memory.

Please identify how many sockets, cores and memory the SUT has and modify `run_multi.sh` and `tune.openjdk.sh` accordingly.

For more information please refer to the [SPECjbb2015 user guide](https://www.spec.org/jbb2015/docs/userguide.pdf).
### 6. Launch "run_multi.sh" and check result:
```bash
sudo screen -L ./run_multi.sh
# Check the result in the "/spec/specjbb2015/<timestamp>" directory. 
sudo grep "RUN RESULT" /spec/specjbb2015/<timestamp>/controller.out
```
