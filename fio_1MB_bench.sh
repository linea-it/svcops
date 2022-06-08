#!/bin/bash

FIOBIN=/home/carlosadean/bin
NTHREADS=4
# Set shared folder available to all nodes
SHAREDIR=/home/carlosadean/public_html

# do not change the values
SAVEHERE="$1"
LOGDIR=/tmp/fio_logs

function fio_write() {
    echo
    echo "##############################"
    echo "### 1024k sequential write ###"
    echo "##############################"
    echo

    ${FIOBIN}/fio \
      --name write \
      --eta=always \
      --eta-newline=1s \
      --filename=${SAVEHERE}/file_write_1M_${HOSTNAME}.dat \
      --rw=write \
      --size=30g \
      --blocksize=1024k \
      --ioengine=psync \
      --direct=1 \
      --numjobs=${NTHREADS} \
      --runtime=70s \
      --time_based=1 \
      --group_reporting \
      > ${LOGDIR}/write
}

function fio_read() {
    echo
    echo "#############################"
    echo "### 1024k sequential read ###"
    echo "#############################"
    echo

    ## In order for all results be redirected to stout and to a file, the option
    ## '--eta=always and eta-newline=1s' must be specified. Not clear on official docs.

    ${FIOBIN}/fio \
      --name read \
      --eta=always \
      --eta-newline=1s \
      --filename=${SAVEHERE}/file_read_1M_${HOSTNAME}.dat \
      --rw=read \
      --size=30g \
      --blocksize=1024k \
      --ioengine=psync \
      --direct=1 \
      --numjobs=${NTHREADS} \
      --runtime=70s \
      --time_based=1 \
      --group_reporting \
      > ${LOGDIR}/read
}

function fio_randread() {
    echo
    echo "##########################"
    echo "### 1024k random read  ###"
    echo "##########################"
    echo

    ${FIOBIN}/fio \
      --name randread \
      --eta=always \
      --eta-newline=1s \
      --filename=${SAVEHERE}/file_randread_1M_${HOSTNAME}.dat \
      --rw=randread \
      --size=30g \
      --blocksize=1024k \
      --ioengine=psync \
      --direct=1 \
      --numjobs=${NTHREADS} \
      --runtime=70s \
      --time_based=1 \
      --group_reporting \
      > ${LOGDIR}/randread
}

function fio_randwrite() {
    echo
    echo "##########################"
    echo "### 1024k random write ###"
    echo "##########################"
    echo

    ${FIOBIN}/fio \
      --name randwrite \
      --eta=always \
      --eta-newline=1s \
      --filename=${SAVEHERE}/file_randwrite_1M_${HOSTNAME}.dat \
      --rw=randrw \
      --size=30g \
      --blocksize=1024k \
      --ioengine=psync \
      --direct=1 \
      --numjobs=${NTHREADS} \
      --runtime=70s \
      --time_based=1 \
      --group_reporting \
      > ${LOGDIR}/randwrite
}

function fio_readwrite() {
    # Perform mixed read/write operation at the same time. Option "--rwmixwrite="
    # sets the % of write operations. If it's 20, means 80% read and 20% write
    echo
    echo "##############################"
    echo "### 1024k sequential mixed ###"
    echo "### read and write         ###"
    echo "##############################"
    echo

    ${FIOBIN}/fio \
      --name mixed_rdwr \
      --eta=always \
      --eta-newline=1s \
      --filename=${SAVEHERE}/file_mixed_1M_${HOSTNAME}.dat \
      --rw=readwrite \
      --rwmixwrite=50 \
      --size=30g \
      --blocksize=1024k \
      --ioengine=psync \
      --direct=1 \
      --numjobs=${NTHREADS} \
      --runtime=70s \
      --time_based=1 \
      --group_reporting \
      > ${LOGDIR}/readwrite

}

function parse() {
    # Log parsing
    cd ${LOGDIR}
    for logfile in write read randread ; do
      mkdir -p ${SHAREDIR}/l${logfile}
      echo ${HOSTNAME} > ${SHAREDIR}/l${logfile}/${logfile}_${HOSTNAME}_parsed.log
      grep "Jobs:" ${LOGDIR}/$logfile \
      | awk -F '[' '{print $4}' \
      | cut -d'=' -f 2 \
      | cut -d'M' -f 1 \
      | tr -d ']' \
      >> ${SHAREDIR}/l${logfile}/${logfile}_${HOSTNAME}_parsed.log
    done
}

function special_parse() {
    # for randwrite and readwrite only, because performance results
    # are split up in read and write operations
    cd ${LOGDIR}
    for logfile in randwrite readwrite; do
      mkdir -p ${SHAREDIR}/l${logfile}
      echo ${HOSTNAME} > ${SHAREDIR}/l${logfile}/${logfile}_${HOSTNAME}_parsed.log
      grep "Jobs:" ${LOGDIR}/$logfile \
      | awk -F '[' '{print $4}' \
      | cut -d'=' -f 2,3 \
      | cut -d'M' -f 1,2 \
      | tr -d 'MiB/s' \
      | tr -d 'w=' \
      | awk '{print "="$0}' \
      | sed s/,/+/g \
      >> ${SHAREDIR}/l${logfile}/${logfile}_${HOSTNAME}_parsed.log
    done
}

function save_clean() {
    # After all, save an clean
    mkdir -p ${SHAREDIR}/bench_logs/${HOSTNAME}
    cp -R ${LOGDIR}/* ${SHAREDIR}/bench_logs/${HOSTNAME}
    rm -Rf ${LOGDIR}
    echo "End. Please run the script merge.sh from a single server"
    echo "It will merge all results in files per test type"
    echo "For plotting, files must be imported on Excel software"

}

## Main ##

if [ $# -eq 1 ]; then
    # creating ${LOGDIR} folder
    mkdir -p ${LOGDIR}
    fio_write
    fio_read
    fio_randread
    fio_randwrite
    fio_readwrite
    parse
    special_parse
    save_clean

else
    echo -e "\nSet the filesystem that will be tested"
    echo -e "Example: ./fio_1MB_bench.sh /lustre/t0 \n"
    exit 1
fi



