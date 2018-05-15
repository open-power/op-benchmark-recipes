#!/bin/bash
######################################################################################################
# FIO-LINUX-SSD-SUITE.sh									                                         #
#												                                                     #
# Original Xiao Hua Xeng. Re-Written by KFattu - Added CPU util, Num jobs, new tests,etc             # 
# Made result file compatible with Intelliperf Database Table Fields                                 #
# 												                                                     #
# Script has been tested on Redhat, Ubuntu and SLES servers.                                         #
#                                       															 #
# Future Enhancements:																				 #
# 0) Add support for multipath devices.                        										 #
# 1) Automate precondition times/amounts value calculations to reduce user error. 					 #
# 2) Pass in precondition switch, w/default = true, to reduce number of scripts to maintain.		 #
# 3) Make a single generic precondition routine that can precondition with any R/W mix, op length &  #
#     spatial locality. But callers would set a fixed temporal locality (iodepth, jobs, etc.)        #
# 4) Converge this script with AIX script to reduce number of scripts to maintain.                   #
# 6)                                                           										 #
# 7)                                                           										 #
#                                                            										 #
# Change Log                                                                                         #
# Date     Who Marker What                                                                           #
# -------- --- ------ --------------------------------------------------------------------------     #
# 02202017 KF         Transfer Size Test Added 							                             #
# 03282017 KF         OLTP2, OLTP3 Added 							                                 #
# 03302017 KF	      Released Rev0								                                     # 
# ________ KF         Added Preconditioning Test for SSDs                                            #
# 05222017 CA  001    Replaced workload eyecatchers written to screen with a case statement.         #
# 06212017 CA  002    Preconditioning is now done with the same op length as the op length used for  #
#                     used for seq. and rand. tests. (Also, those test op lengths are no longer      #
#		              overwritten with op lengths from preconditioning routines.)	                 #
# 07282017 CA  na     Added "randrepeat=0" to job files to lower fio overhead.			   		     #
# 08032017 CA  003    Appended "/dev/" to raw devices for SuSE. Not sure why RHEL & Ubuntu work ?    #
# 08042017 CA  004	  Accept y or Y.																 #
# 08072017 CA  005	  Renamed the "adapter" input field to "config_id" to make it more broad.		 #
# 08102017 CA  006    Add support for multipath devices & remove need to have "/dev/" in device names#
######################################################################################################

#----------------------------------------------------------------------------------------------------
# Values that normally DO change from run-to-run, PLEASE change if needed
#  p.s. Need to automate calculation of these in the near future to provide consistent results 
#		regardless of tester. 
#----------------------------------------------------------------------------------------------------
SIZE=930g                   	# Footprint, in bytes, of LUN to access, Hint: Typ.values = 80% of LUN size
precond_rndwrite_time=7200 	    # Depends on SSD capacity and data rate (units = s)
precond_seqwrite_time=3600  	# Depends on SSD capacity and data rate (units = s)
								#  Hint: Goal is to write to 2X the capacity of the LUNs to ensure 
								#   garbage collection has started. Then start testing immediately 
								#   after. Time can be estimated by taking total LUN capacity and  
								#   dividing it by the expected data throughput (GB/s) of the LUN
								#   at that R/W ratio, op length and spatial locality.  
must_precond_rndwrite=true		# Typically reserved for testing NAND Flash based SSDs, but feel free
must_precond_seqwrite=true		#  to keep enabled for HDDs so that caches might get primed.
								# In future, set these with a single passed in parameter ?   
#----------------------------------------------------------------------------------------------------
# Default Values that normally need not change, but feel free to change if desired 
#----------------------------------------------------------------------------------------------------
stime=10                        # sleep time is set to 10 seconds (units = s)
test_time=180			        # test time is set to 3 minutes   (units = s)

#----------------------------------------------------------------------------------------------------
# Start doing real work...
#----------------------------------------------------------------------------------------------------
#Get the CPU Type from the system
cpuinfo=$(cat /proc/cpuinfo | awk 'NR==2 { print $3 }')
#echo $cpuinfo

#get the System MTM
model=$(lshw | sed -n 3p)
MTM=($model)
#echo ${MTM[1]}

#Request a unique test identifier from the user
echo -n "WARNING: IPDS web interface only shows 1st 32 characters of this field."					#A005
echo																								#A005
echo -n "Enter unique test identifier, such as adapter name, drive name etc. and press [ENTER]: " 	#C005
read test_id																						#C005

#get number of disks being tested
numdisks=$#
numdisks=$((numdisks-1))

#get OS name and Version
OS=$(cat /etc/*-release | sed -n 's/^ID=//p')
OS=$(echo $OS | cut -d "=" -f 2 | tr -d '"')
#echo $OS

version=$(cat /etc/*-release | grep 'VERSION_ID')
version=$(echo $version | cut -d "=" -f 2 | tr -d '"')
#echo $version

osver=$OS$version
#echo $osver

clean_up()
{
    echo "Test finished!!"
#    pkill iostat
    exit 0
}

trap clean_up SIGINT

usage()
{
    echo "`basename $0 ` -[d|h] args "
    echo "  -h print this usage."
    echo "  -d specify the raw disk, eg. -d sdb or -d sdb sdc dm-5."			#C006 
    echo "  -f specify the test file path and name, eg. -f /mnt/testfile."
    echo "  -s specify the file size used for file system test"
}

fs_sync()
{
   sync
   echo 3 >/proc/sys/vm/drop_caches 
}

# Collect detailed system information
#  lpcpu.mod2.tar.bz2 file will be included with this script. Run - tar xvfj lpcpu.mod2.tar.bz2
#tar xvfj lpcpu.mod2.tar.bz2

#/root/FIO-LINUX-HDD/lpcpu/lpcpu.sh profilers="" duration=0 output_dir=/root/FIO-LINUX-HDD

# cd lpcpu then run ./lpcpu.sh.
# Data is stored as follows - /tmp/lpcpu_data.habpart44.default.2017-02-14_1038.tar.bz2

random_test()             
{
    echo "random test for ssds"
    rw_arr=randrw
    rtime=$test_time
    rwmixread=(0 100 70 60 90)
    blksize=(4k)
    
#   for bs in ${blksize[@]}
#   do
    for mix in ${rwmixread[@]}
    do
        case  $mix in                                       #A001
            60)  echo "Running OLTP1 Test";;                #A001
            90)  echo "Running OLTP2 Test";;                #A001
            70)  echo "Running OLTP3 Test";;                #A001
           100)  echo "Running 100% 4KB Random Read Test";; #A001
             0)  echo "Running 100% 4KB Random Write Test";;#A001
             *)                                             #A001
        esac                                                #A001

		if [ "$mix" == "0" ] && [ "$must_precond_rndwrite" == "true" ]; then
	    	echo "Running random write preconditioning";
	    	must_precond_rndwrite=false;
	    	precond_random_write_test
		fi

	    if [ "$mix" == "90" ]; then
#			echo "Running OLTP2 Test";		D001 No longer needed
			bs=(8k)
			rw_arr=randrw
			rtime=$test_time
			qdepth=(1 4 8 16 32 64 128)
			numjobs=(1 2)
			for qd in ${qdepth[@]}
			do
	            for nj in ${numjobs[@]}
		    	do	
					echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $output_log
		        	RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime SIZE=$SIZE fio --minimal $rawjob_file >> $output_log  
					echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $iostat_log 
					iostat -txm 3 65                        >> $iostat_log   &  # Added for iostat file
					echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $vmstat_log
					vmstat -w 3 65                          >> $vmstat_log   &						
					tail -n1 $output_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $output_data
						fs_sync		# Linux only
					sleep $stime
		    	done 		# for nj in ${numjobs[@]}
			done			# for qd in ${qdepth[@]}
	    else
	    	rtime=$test_time
	    	bs=(4k)
	    	rw_arr=randrw
	    	qdepth=(1 4 8 16 32 64 128)
			numjobs=(1 2)
			for qd in ${qdepth[@]}
			do
		    	for nj in ${numjobs[@]}
		    	do	
					if [ "$mix" == "70" ]; then
#			    		echo "Running OLTP3 Test";	#D001 No longer needed
			    		rw_arr=randrw:2	
			    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****"  >> $output_log 
			    		RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime SIZE=$SIZE fio --minimal $rawjob_file >> $output_log
		    	    	echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $iostat_log
		    	    	iostat -txm 3 65                        >> $iostat_log   &  # Added for iostat file
			    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $vmstat_log
			    		vmstat -w 3 65                          >> $vmstat_log   &							
			    		tail -n1 $output_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $output_data
			    			fs_sync	# Linux only
			    		sleep $stime
		    		else
			    		rw_arr=randrw
			    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $output_log 
			    		RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime SIZE=$SIZE fio --minimal $rawjob_file >> $output_log 
		    	    	echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $iostat_log 
			    		iostat -txm 3 65                        >> $iostat_log   &  # Added for iostat file	
			    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $vmstat_log
			    		vmstat -w 3 65                          >> $vmstat_log   &							
			    		tail -n1 $output_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $output_data
			    			fs_sync	# Linux only
			    		sleep $stime
					fi
		    	done		# for nj in ${numjobs[@]}
			done 			# for qd in ${qdepth[@]}
	    fi
    done  					# for mix in ${rwmixread[@]}
#done 						# for bs in blksize
}

sequential_test()
{
    echo "sequential test for ssds"
    rw_arr=rw               # rw indicates Sequential workload
    rtime=$test_time        # User may vary as needed
    rwmixread=(0 100 50)    # Please consult before changing the order of tests as it impacts performance  
    blksize=(256k)
   
    for bs in ${blksize[@]}
    do
        for mix in ${rwmixread[@]}
        do
            case  $mix in                                         	#A001
                100) echo "Running 100% big op Sequential Reads";; 	#A001
                0)   echo "Running 100% big op Sequential Writes";;	#A001
                50)  echo "Running 100% big op Sequential Duplex";;	#A001
                *)                                                 	#A001
            esac                                                  	#A001

	    	if [ "$mix" == "0" ] && [ "$must_precond_seqwrite" == "true" ]; then
				echo "Running Sequential write preconditioning";
				must_precond_seqwrite=false;
				precond_sequential_write_test
			fi

			rtime=$test_time
			qdepth=(1 4 8 16 32 64 128)	# User may vary as needed
			numjobs=(1)   		# User may vary as needed
            for qd in ${qdepth[@]}
			do
		    	for nj in ${numjobs[@]}
		    	do	
					echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $output_log
                	RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime SIZE=$SIZE fio --minimal $rawjob_file >> $output_log
					echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $iostat_log 
					iostat -txm 3 65                        >> $iostat_log   &  # Added for iostat file
					echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $vmstat_log
					vmstat -w 3 65                          >> $vmstat_log   &					
                    tail -n1 $output_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $output_data
                    fs_sync
                    sleep $stime
		    	done 		# for nj in ${numjobs[@]}
            done			# for qd in ${qdepth[@]}
    	done				# for mix in ${rwmixread[@]}
    done					# for bs in blksize
}

transfer_size_test()   
{
    rw_arr=$1
    echo "Random and Sequential tests across transfer length: $rw_arr"
    rtime=$test_time       # User may vary as needed          
    qdepth=(64)            # User may vary as needed
    numjobs=(1)            # User may vary as needed.
    rwmixread=(100 0)      # Please consult before changing the order of tests as it impacts performance
    blksize=(512 1k 2k 4k 8k 16k 32k 64k 128k 256k 512k 1024k)  # User may vary as needed

    for bs in ${blksize[@]}
    do
        for mix in ${rwmixread[@]}
        do
            case  $mix in                                             #A001
                100) echo "Running Transfer_Size w/Random Reads";;    #A001
                0)   echo "Running Transfer_Size w/Random Writes";;   #A001
                *)                                                    #A001
            esac                                                      #A001
            for qd in ${qdepth[@]}
	    	do
				for nj in ${numjobs[@]}
            	do
		    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $blktest_log
                    RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime SIZE=$SIZE fio --minimal $rawjob_file  >> $blktest_log
		    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $iostat_log 
		    		iostat -txm 3 65                        >> $iostat_log   &  # Added for iostat file
		    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $vmstat_log
		    		vmstat -w 3 65                          >> $vmstat_log   &
		    		tail -n1 $blktest_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $output_data
                    fs_sync			# Linux only
                    sleep $stime
            	done	# for nj in ${numjobs[@]}
       	    done		# for qd in ${qdepth[@]}
    	done			# for mix in ${rwmixread[@]}
    done				# for bs in blksize
}

precond_random_write_test()              # Preconditioning before random write workload
{
    echo "preconditioning random 4K test for ssds"
    rw_arr=randrw
    rtime=$precond_rndwrite_time     
    qdepth=(128)    # User may vary as needed
	numjobs=(1)     # Recommend to keep numjobs=1 for preconditioning test.          
    rwmixread=(0)
#    blksize=(4k)    Use the same op length as the desired small-length random-op tests  D002

    for bs in ${blksize[@]}
    do
        for mix in ${rwmixread[@]}
        do
            for qd in ${qdepth[@]}
	    	do
				for nj in ${numjobs[@]}
				do	
		    		echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****" >> $precond_data
                    RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime fio --minimal $precond_file >> $precond_data
#                   tail -n1 $output_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $precond_data
                    fs_sync			# Linux only
                    sleep $stime
                done
            done
        done
    done
}

precond_sequential_write_test()              # Preconditioning before sequential write workload
{
    echo "Preconditioning seq write test for ssds"
    rw_arr=rw
    rtime=$precond_seqwrite_time       
    qdepth=(128)      # User may vary as needed
    numjobs=(1)       # Recommend to keep numjobs=1 for preconditioning test.
    rwmixread=(0)
#    blksize=(256k)	Use the same op length as the desired seq. op tests			D002

    for bs in ${blksize[@]}
    do
        for mix in ${rwmixread[@]}
        do
            for qd in ${qdepth[@]}
	    	do
				for nj in ${numjobs[@]}
				do	
	            	echo "****INFOFIO;$cpuinfo;${MTM[1]};$test_id;$numdisks;$osver;$rw_arr;$mix;$bs;$qd;$nj;"`date`" ****"  >> $precond_data
                    RWTYPE=$rw_arr MIX=$mix BLKSIZE=$bs IODEPTH=$qd NUMJOBS=$nj RUNTIME=$rtime fio --minimal $precond_file >> $precond_data
#                   tail -n1 $output_log |awk -F ";" '{printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n","'$rw_arr'","'$bs'","'$qd'","'$nj'","'$mix'",$7,$8,$40,$48,$49,$81,$88,$89}' |tee -a $precond_data
                    fs_sync
                    sleep $stime
            	done
            done
    	done
    done
}

get_sys_config()
{
    echo "****disk configuration ****" >> $config_log

    type lsscsi &> /dev/null
    if [ $? -eq 0 ]; then
        lsscsi >> $config_log
    fi
    
    type lsblk &> /dev/null
    if [ $? -eq 0 ]; then
        lsblk >> $config_log
    fi    

    for d in $dev_name
    do
        echo "/sys/block/`basename $d`/queue/read_ahead_kb" >> $config_log
        cat /sys/block/`basename $d`/queue/read_ahead_kb >> $config_log

        echo "/sys/block/`basename $d`/queue/scheduler" >> $config_log
        cat /sys/block/`basename $d`/queue/scheduler >> $config_log

        echo "/sys/block/`basename $d`/queue/nr_requests" >> $config_log
        cat /sys/block/`basename $d`/queue/nr_requests >> $config_log

    done

#    iostat -xm -c 5 > $io_log &
}
    
output_dir=fio_output
output_log=$output_dir/fio_`date +%Y%m%d%H%M`.fio
blktest_log=$output_dir/blktest_`date +%Y%m%d%H%M`.log
config_log=$output_dir/config_`date +%Y%m%d%H%M`.log
iostat_log=$output_dir/fio_`date +%Y%m%d%H%M`.iostat
vmstat_log=$output_dir/fio_`date +%Y%m%d%H%M`.vmstat
output_data=$output_dir/fio_`date +%Y%m%d%H%M`.csv
rawjob_file=$output_dir/fio_`date +%Y%m%d%H%M`.job
fio_result=$output_dir/rawdata_`date +%Y%m%d%H%M`.fio  #create .fio file separately.
precond_file=$output_dir/precond_`date +%Y%m%d%H%M`.job  # job file for preconditioning added on 3/10
precond_data=$output_dir/precond_`date +%Y%m%d%H%M`.log


output_check()
{
    if [ ! -d $output_dir ]; then
        mkdir -p $output_dir 2>/dev/null
    fi

    if [ -e $output_log ]; then
        echo "log file exist, remove it"
        rm $output $result -rf
    fi

    if [ -e $rawjob_file ]; then
        rm $rawjob_file -rf
    fi
    
	if [ -e $precond_file ]; then
        rm $precond_file -rf
    fi 
    echo "iotype,bs,qd,nj,rmix,rbw_kb,riops,rlat_us,wbw_kb,wiops,wlat_us,cpu_usr,cpu_sys" >> $output_data  # Added numjobs nj
}

while getopts :d:f:s:h:?: OPTION
do
    case $OPTION in
    h) usage; exit 0;;
    d) dev_input=$OPTARG;;
    f) file_input=$OPTARG;;
    s) file_size=$OPTARG;;
    esac
done

if [ "$dev_input" = "" ] && [ "$file_input" = "" ]; then
    usage;
    exit 0;
fi

if [ "$dev_input" != "" ]; then
    dev_name=`echo $*|awk -F "-d" '{print $2}'|cut -f 1`  	#C006
    echo "The data may be erased:${dev_name}" 
    echo -n "Are you sure to continue the testing?[Y/N]:"
    read confirm
    if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then	# C004
        exit 0
    fi
fi

if [ "$file_input" != "" ]; then
    file_name=`echo $*|awk -F "-f" '{print $2}'|cut -d "-" -f 1`
    echo "Test file:${file_name}"
    echo -n "Are you sure to continue the testing?[Y/N]:"
    read confirm
    if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then	# C004
        exit 0
    fi
fi

output_check

dev_num=0

cat <<EOF >> $rawjob_file
[global]
randrepeat=0
buffered=0
direct=1
norandommap=1
group_reporting=1
size=\${SIZE}
ioengine=libaio
rw=\${RWTYPE}
bs=\${BLKSIZE}
iodepth=\${IODEPTH}
rwmixread=\${MIX}
runtime=\${RUNTIME}
ramp_time=5
time_based=1
numjobs=\${NUMJOBS}
#random_generator=tausworthe64
EOF


cat <<EOF >> $precond_file
[global]
randrepeat=0
buffered=0
direct=1
norandommap=1
group_reporting=1
ioengine=libaio
rw=\${RWTYPE}
bs=\${BLKSIZE}
iodepth=\${IODEPTH}
rwmixread=\${MIX}
runtime=\${RUNTIME}
ramp_time=5
time_based=1
numjobs=\${NUMJOBS}
#random_generator=tausworthe64
EOF
#random_generator=tausworthe64 - Use this in Job file for NVMe workloads

for disk in $dev_name
do
#	if [ -f /etc/SuSE-release ] ; then								#A003 D006
    disk="/dev/"$disk   				# Append dev. file location  A003
#	fi																#A003 D006
  	if [ -b $disk ] ; then		
       	dev_num=`expr $dev_num + 1`
       	echo "" >>$rawjob_file
       	echo "[job$dev_num]" >>$rawjob_file
       	echo "filename=$disk" >>$rawjob_file
		echo "" >>$precond_file
       	echo "[job$dev_num]" >>$precond_file
       	echo "filename=$disk" >>$precond_file
    else
       	echo "$disk is not a valid raw disk."
       	exit 0
    fi
done

for file in $file_name
do
    dev_num=`expr $dev_num + 1`
    echo "" >>$rawjob_file
    echo "[job$dev_num]" >>$rawjob_file
    echo "filename=$file" >>$rawjob_file
    echo "filesize=$file_size" >>$rawjob_file
    echo "" >>$precond_file
    echo "[job$dev_num]" >>$precond_file
    echo "filename=$file" >>$precond_file
    echo "filesize=$file_size" >>$precond_file	
done


get_sys_config
random_test 
sequential_test
transfer_size_test randrw
transfer_size_test rw

clean_up

exit 0
