# innobackupex-remote
Script to handle  full and incremental mysql backups using  xtrabackup/innobackupex

## Installation
Get the latest relese of Xtrabackup and install it on the origin and recipient  system.

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
b_path    # Backup path, default /backup/xtrabackup/${host}
retention # Retention period in days, default 7
gzip      # Compress backups, default true
```

## Run

Run it as follows:

`$ ./innobackupex-remote.sh <hostname>`

As you run it will generate a few files

```
$ cd /backup/xtrabackup/
$ find .
.
./origin-hostname
./origin-hostname/2019-12-06.tar.gz
./origin-hostname/2019-12-06.log
./origin-hostname/2019-12-06.checkpoints
./origin-hostname/2019-12-07.log
./origin-hostname/2019-12-07.checkpoints
./origin-hostname/2019-12-07.tar.gz
```

The tar.gz will contain your backups. The log-files contains the xtrabackup log output and the checkpoint-files will contain information about the given backup and LSN ID for managing incremental backups.

```
$ cat ./origin-hostname/2019-12-07.checkpoints
backup_type = incremental
from_lsn = 150458875511
to_lsn = 150458875685
last_lsn = 150458875685
compact = 0
recover_binlog_info = 0
```