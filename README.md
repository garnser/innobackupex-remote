# innobackupex-remote
Script to handle  full and incremental mysql backups using  xtrabackup/innobackupex

## Installation
Get the latest relese of qpress and Xtrabackup and install it on the origin and recipient  system.

<https://www.percona.com/downloads/Percona-XtraBackup-LATEST/>

Generate an SSH-key on the recipient-system without a passphrase.

```
$ sudo useradd xtrabackup
$ sudo su - xtrabackup
$ ssh-keygen -b 4096 -t rsa -f /tmp/sshkey -q -N ""
```

Add the public key and limitations to the mysql-user on the origin system *~/.ssh/authorized_keys*
`command="/usr/bin/innobackupex $SSH_ORIGINAL_COMMAND",no-port-forwarding,no-x11-forwarding,no-agent-forwarding key_type key`

Create a *.my.cnf* file for the mysql user on the origin system

```
$ echo '[client]
user=USERNAME
password=PASSWORD' >> ~/.my.cnf
```

## Configuration

Within the script you can set a few options.

```
h_path    # Backup path, default /backup/xtrabackup/${host}
retention # Retention period in days, default 7
```

## Run

Run it as follows:

`$ ./innobackupex-remote.sh <origin-hostname>`

As you run it will store your backups in the destination-folder divided by dates.

```
$ find /backup/xtrabackup/ -maxdepth 2
/backup/xtrabackup/
/backup/xtrabackup/origin-hostname
/backup/xtrabackup/origin-hostname/2019-12-06
/backup/xtrabackup/origin-hostname/2019-12-07
```

Within the folders you'll also find the `xtrabackup.log` which contains the output of the backup-operation.

## Recover

All backups are compressed with qp, to do a recovery you need to uncompress these first.

`$ innobackupex --decompress <backupfolder>`

To perform a full restore please refer to <https://www.percona.com/doc/percona-xtrabackup/2.4/innobackupex/incremental_backups_innobackupex.html#preparing-an-incremental-backup-with-innobackupex>
