#!/usr/bin/env bash

backup=$1
basedir=$(dirname $backup | awk -F '/' '{ print $NF }')
backupdate=$(echo $backup | awk -F '/' '{ print $NF }' | cut -d '_' -f1)
root_psw=$2
server_version=$(grep 'Using server version' $backup/xtrabackup.log | awk '{ print $4 }' | cut -d '-' -f1)

full_backup=$backupdate
incr_backups=()

echo -n "Identifying last full backup..."
while [ 1 ]; do
  i=$((i+1))
  grep -q 'backup_type = full-backuped' /backup/xtrabackup/$basedir/${full_backup}*/xtrabackup_checkpoints
  if [ $? -eq 0 ]; then
    break
  else
    incr_backups+=("${full_backup}")
    full_backup=$(date -d "${backupdate} $i day ago" +%Y-%m-%d)
  fi
done
echo "done"

compose_file=$(mktemp /tmp/docker-compose.XXXX.yml)
temp_dir=$(mktemp -d /backup/dbrestore/${basedir}-${backupdate}.XXXX)

cd /backup/xtrabackup/${basedir}/${full_backup}*/
qp_count=$(find . -name "*.qp" | wc -l)
if [ $qp_count -gt 0 ]; then
  echo -n "Decompressing full backup..."
  innobackupex --decompress . 1> /dev/null
  echo "done"
  echo -n "Removing compressed files..."
  find . -name "*.qp" -delete
  echo "done"
fi

echo -n "Copy base backup to target directory..."
rsync -axH * ${temp_dir}
echo "done"
echo -n "Prepare base backup..."
xtrabackup --prepare --apply-log-only --target-dir=${temp_dir}/ 1> /dev/null
echo "done"
#xtrabackup --copy-back --target-dir=${temp_dir}/

echo "=== Starting incremental restores ==="
for b in ${incr_backups[@]}; do
    cd /backup/xtrabackup/${basedir}/${b}*/
    $cur_dir=$(pwd)
    qp_count=$(find . -name "*.qp" | wc -l)
    if [ $qp_count -gt 0 ]; then
      echo -n "Decompressing incremental backup..."
      innobackupex --decompress . 1> /dev/null
      echo "done"
      echo -n "Removing compressed files..."
      find . -name "*.qp" -delete
      echo "done"
    fi
    cd ${temp_dir}
    echo -n "Apply logs..."
    xtrabackup --prepare --apply-log-only --target-dir=${temp_dir}/ --incremental-dir=${cur_dir} 1> /dev/null
    echo "done"
done

cd ${temp_dir}
echo -n "Apply logs..."
innobackupex --apply-log . 1> /dev/null
echo "done"

docker_image=$(docker run -d --rm -t -v ${temp_dir}:/var/lib/mysql mysql:${server_version})

echo "Image is up and running, when finished perform the following:"
echo "docker stop ${docker_image}"
echo "rm -fr ${temp_dir}"
