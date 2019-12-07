#!/bin/bash
set  -o pipefail
host=$1
today=$(date +%Y-%m-%d_%H)
h_path="/backup/xtrabackup/${host}"
b_path="${h_path}/${today}"
retention=7

# Right now backups will always  be full if the retention-time has passed, need some logic to handle multiple retention-periods
oldest=$(ls -td $h_path/* -- 2> /dev/null | head -n1)
if [[ $oldest ]]; then
    start_time=$(date -d "$(qpress -do ${latest}/xtrabackup_info.qp | grep -Po "^start_time = \K.*")" "+%s")
    retention=$(date -d "${retention} days ago" "+%s")
    if  [[ $start_time -gt $retention ]]; then
level="incr"
    fi
fi

if [[ ! -d ${b_path} ]]; then
    mkdir -p ${b_path}
else
    echo "Backup already taken!"
    exit 1
fi

exec &>> ${b_path}/xtrabackup.log
if [[ "$level" == "incr" ]]; then
    latest=$(ls -td $h_path/* -- 2> /dev/null | head -n1)
    lsn=$(grep -Po "^to_lsn = \K.*" ${latest}/xtrabackup_checkpoints)
    ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream --incremental /tmp/${today}_mysqlxtrabackup/ --incremental-lsn=${lsn}" | xbstream -x -C ${b_path}/
else
    ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream /tmp/${today}_mysqlxtrabackup" | xbstream -x -C ${b_path}/
fi
