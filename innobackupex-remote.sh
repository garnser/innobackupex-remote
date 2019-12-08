#!/bin/bash
set -o pipefail
host=$1
level=$2
today=$(date +%Y-%m-%d_%H)
h_path="/backup/xtrabackup/${host}"
b_path="${h_path}/${today}"

if [[ ! -d ${h_path} ]]; then
    level="Full"
fi

if [[ ! -d ${b_path} ]]; then
    mkdir -p ${b_path}
else
    echo "Backup already taken!"
    exit 1
fi

exec &>> ${b_path}/xtrabackup.log

latest=$(ls -td $h_path/* -- 2> /dev/null | sed -n '2p')
lsn=$(grep -Po "^to_lsn = \K.*" ${latest}/xtrabackup_checkpoints)

if [[ "$level" == "Incremental" && -n $lsn ]]; then
    ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream --incremental /tmp/${today}_mysqlxtrabackup/ --incremental-lsn=${lsn}" | xbstream -x -C ${b_path}/
else
    ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream /tmp/${today}_mysqlxtrabackup" | xbstream -x -C ${b_path}/
fi
