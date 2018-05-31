# Running SPEC CPU2006 on Power ppc64le systems
## Steps

#### 1. Install Advanced Toolchain
Please refer to URL:
https://developer.ibm.com/linuxonpower/advance-toolchain/advtool-installation/

Currently advance toolchain is at version 11.0. Version 9.0 has been tested to run IBM binary for SPEC CPU2006. 

>*Note: download and install Advanced Toolchain is expected to be slow.*

#### 2. Install IBM XLC and XLF runtime and addons packages
Download and install IBM XLC runtime version 13.1.5:
http://www-01.ibm.com/support/docview.wss?uid=swg24042868

Download and install IBM XLC addons version 13.1.5:
http://www-01.ibm.com/support/docview.wss?uid=swg24042866

Download and install IBM XLF runtime version 15.1.5:
http://www-01.ibm.com/support/docview.wss?uid=swg24042871

Download and install IBM XLF addons version 15.1.5:
http://www-01.ibm.com/support/docview.wss?uid=swg24042869

#### 3. Install SPEC CPU2006 package
##### 3.1 Extract SPEC CPU2006 package: 

Assume SPEC CPU2006 license is purchased from http://spec.org/ and SPEC CPU2006 code package is downloaded.  
```bash
mkdir -p /home/spec/cpu2006 
tar xvf <cpu2006-1.x.tar> -C /home/spec/cpu2006
```

Note: if you obtain an ISO version of CPU2006, please find **cpu2006.tar.xz** under **install_archives/** directory.    
```bash
mkdir -p /mnt/iso
mount -oloop,ro <cpu2006-1.x.iso> /mnt/iso
tar xf /mnt/iso/install_archives/cpu2006.tar.xz -C /home/spec/cpu2006
umount /mnt/iso
```    
##### 3.2 Download and extract toolset for ppc64le
Visit https://www.spec.org/cpu2006/src.alt/ and download **linux-ubuntu14_04-ppc64le-67.tar.**

*Note: The file is kernel independent and currently good for Ubuntu xenial/artful.*
```bash
wget 'https://www.spec.org/cpu2006/src.alt/linux-ubuntu14_04-ppc64le-67.tar'
tar xf linux-ubuntu14_04-ppc64le-67.tar -C /home/spec/cpu2006
```    
##### 3.3 Install SPEC CPU2006 
Please invoke **./install.sh** to install SpecCPU2006.

```bash
cd /home/spec/cpu2006 
./install.sh 
```

You will need type "yes" to confirm installation directory. This may take a minute or two to finish.

#### 4. Compile the SPEC CPU2006 binary for ppc64le
Copy the provided config file to `/home/spec/cpu2006/config`. Then calculate the number of _hugepages_ per 
the [hugetlbpage support page](https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt)
```bash
source .shrc
ulimit -s unlimited
export HUGETLB_MORECORE=yes
export HUGETLB_VERBOSE=0
echo $num > /proc/sys/vm/nr_hugepages # i.e. $num=60000
swapoff -a

runspec -a validate -c $CONFIG -T peak -S $SYMBOL -r int
# $CONFIG is the configuration file 
# $SYMBOL is the system configuration (preprocessor macro) in the config file, i.e. p9_32_core
```

#### 5. Launch SPEC CPU2006 run
To run CPU2006 integer part (both base and peak), please run:
```bash
cd /home/spec/cpu2006
rm -f screenlog.0
screen -L ./wrap_cpu2006_ref_int.sh
```

To run CPU2006 float point part (both base and peak), please run:
```bash
cd /home/spec/cpu2006
rm -f screenlog.0
screen -L ./wrap_cpu2006_ref_fp.sh
```
You can check screenlog.0 to find the run's log.

