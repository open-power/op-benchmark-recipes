## POWER Instructions

* The *iostat* and *fio* tools must be installed on the machine. In ubuntu:
```bash
 apt install systat fio
```

* Run the FIO script as follows:
```bash
 FIO-LINUX-SSD-SUITE.sh -d <devicelist>  # i.e. sda2 (without /dev/)
``` 

* The devices in list must be unmounted and **MUST NOT** include your OS partition.


> For more information, please consult: https://github.com/axboe/fio
