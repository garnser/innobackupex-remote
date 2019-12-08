#!/bin/bash
set -o pipefail
host=$1
h_path="/backup/xtrabackup/${host}"
b_path="${h_path}/"$(date +%Y-%m-%d_%H)

mkdir -p ${b_path} 2> /dev/null || echo "Backup already taken!" && exit 1

lsn=$(grep -Po "^to_lsn = \K.*" $(ls -td $h_path/* -- 2> /dev/null | sed -n '2p')/xtrabackup_checkpoints)
if [[ "$2" == "Incremental" && -n $lsn ]]; then
    incremental="--incremental --incremental-lsn=${lsn}"
fi

exec &>> ${b_path}/xtrabackup.log
ssh mysql@${host} " --compress --slave-info --safe-slave-backup --no-timestamp --stream=xbstream ${incremental} /tmp/mysqlxtrabackup" | xbstream -x -C ${b_path}/
