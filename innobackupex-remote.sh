#!/bin/bash
set -o pipefail
host=$1
level=$2
f_freq=7
retention=28
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

p_ret=$(find ${h_path} -maxdepth 2 -ctime +${retention} -name "xtrabackup_checkpoints" | xargs grep -l 'from_lsn = 0' | head -n -1 | wc -l)
if [[ $p_ret -ge 1 ]]; then
    closest=$(find ${h_path} -maxdepth 2 -ctime +${retention} -name "xtrabackup_checkpoints" | xargs grep -l 'from_lsn = 0' | tail -n 1)
    c_ts=$(date -d "$(stat ${closest} | grep -Po 'Change: \K[0-9-]+ [0-9:]+')" "+%s")
    ret_rm=$(echo "$(( ($(date "+%s") - $(date -d "$(stat ${closest} | grep -Po 'Change: \K[0-9-]+ [0-9:]+')" "+%s")) / 86400 ))"
    # NOT TESTED, USE WITH EXTREME CAUTION!!
    #find ${h_path} -maxdepth 1 -ctime +${ret_rm} | xargs rm -fr
fi
