#!/bin/bash
set  -o pipefail
host=$1
today=$(date +%Y-%m-%d)
h_path="/backup/xtrabackup/${host}"
b_path="${h_path}/${today}"
retention=7

latest=$(ls -td $h_path/* -- 2> /dev/null | head -n1)

if [[ $latest ]]; then
    start_time=$(date -d "$(grep -Po "^start_time = \K.*" ${latest}/xtrabackup_checkpoints)" "+%s")
    retention=$(date -d "${retention} days ago" "+%s")
    if  [[ $start_time -gt $retention ]]; then
level="incr"
    fi
fi

if [[ ! -d ${b_path} ]]; then
    mkdir -p ${b_path}
else
    echo "Backup already taken today!"
    exit 1
fi

exec &>> ${b_path}/xtrabackup.log
echo  "Starting $level backup"

if [[ "$level" == "incr" ]]; then
    lsn=$(grep -Po "^to_lsn = \K.*" ${latest}/xtrabackup_checkpoints)
    ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream --incremental /tmp/${today}_mysqlxtrabackup/ --incremental-lsn=${lsn}" | xbstream -x -C ${b_path}/
else
    ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream /tmp/${today}_mysqlxtrabackup" | xbstream -x -C ${b_path}/
fi
