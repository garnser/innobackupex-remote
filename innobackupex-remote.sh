#!/bin/bash
set -o pipefail
host=$1
level=$2
f_freq=7
h_path="/backup/xtrabackup/${host}"
b_path="${h_path}/"$(date +%Y-%m-%d_%H)

if [ -d ${b_path} ]; then
    echo "Backup already taken!"
    exit 1
fi

mkdir -p ${b_path}

find ${h_path} -maxdepth 2 -ctime -${f_freq} -name "xtrabackup_checkpoints" | xargs grep -q 'from_lsn = 0'
if [[ $?-ne 0 ]]; then
    level="Full"
fi

lsn=$(grep -Po "^to_lsn = \K.*" $(ls -td $h_path/* -- 2> /dev/null | sed -n '2p')/xtrabackup_checkpoints)

if [[ "$level" == "Incremental" && -n $lsn ]]; then
    incremental="--incremental --incremental-lsn=${lsn}"
fi

exec &>> ${b_path}/xtrabackup.log
ssh mysql@${host} " --compress --slave-info --safe-slave-backup --stream=xbstream ${incremental} /tmp/mysqlxtrabackup" | xbstream -x -C ${b_path}/