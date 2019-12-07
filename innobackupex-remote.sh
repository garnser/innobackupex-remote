#!/bin/bash
set -o pipefail
host=$1
b_path="/backup/xtrabackup/${host}"
retention=7
level="full"
today=$(date +%Y-%m-%d)
gzip="true"

if [[ ! -d $b_path ]]; then
    mkdir -p $b_path
fi

ssh -q -l mysql -T $host 2> /dev/null
if [ $? -ne 1 ]; then
    echo "Unable to connect to ${host}"
    exit 1
fi

latest=$(ls -td $b_path/*.checkpoints -- 2> /dev/null | head -n1)
l_type=$(grep backup_type ${latest} 2> /dev/null | awk '{ print $NF }')
if [[ "$l_type" == "incremental" || "$l_type" == "full-backuped" ]]; then
    start_time=$(date -d "$(grep -Po "^start_time = \K.*" ${latest})" "+%s")
    retention=$(date -d "${retention} days ago" "+%s")
    if  [[ $start_time -gt $retention ]]; then
    level="incr"
    fi
fi

if [[ ! -e ${b_path}/${today}.tar.gz ]]; then
    mkdir -p ${b_path}/${today}
else
    echo "Backup already taken today!"
    exit 1
fi

exec &>> ${b_path}/${today}.log
echo  "Starting $level backup"

if [[ "$level" == "incr" ]]; then
    lsn=$(grep -Po "^to_lsn = \K.*" ${latest})
    ssh mysql@${host} " --slave-info --safe-slave-backup --no-timestamp --stream=xbstream --incremental /tmp/${today}_mysqlxtrabackup/ --incremental-lsn=${lsn}" | xbstream -x -C ${b_path}/${today}/
else
    ssh mysql@${host} "innobackupex --slave-info --safe-slave-backup --no-timestamp --stream=xbstream /tmp/${today}_mysqlxtrabackup" | xbstream -x -C ${b_path}/${today}/
fi

cp ${b_path}/${today}/xtrabackup_checkpoints ${b_path}/${today}.checkpoints

if [[ "$gzip" == "true" ]]; then
    tar -C ${b_path} -zcf ${today}.tar.gz ${today}
    rm -fr ${b_path}/${today}
fi

