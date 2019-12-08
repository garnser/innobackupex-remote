#!/bin/bash
set -o pipefail
host=$1
level=$2
today=$(date +%Y-%m-%d_%H)
h_path="/backup/xtrabackup/${host}"
b_path="${h_path}/${today}"

if [[ ! -d ${b_path} ]]; then
    mkdir -p ${b_path}
else
    echo "Backup already taken!"
    exit 1
fi

latest=$(ls -td $h_path/* -- 2> /dev/null | sed -n '2p')
lsn=$(grep -Po "^to_lsn = \K.*" ${latest}/xtrabackup_checkpoints)

if [[ "$level" == "Incremental" && -n $lsn ]]; then
    incremental="--incremental --incremental-lsn=${lsn}"
fi

exec &>> ${b_path}/xtrabackup.log
ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream ${incremental} /tmp/${today}_mysqlxtrabackup" | xbstream -x -C ${b_path}/
