# zulip_postgres_backup.sh

> A custom postgres backup utility for a dokku-based Zulip installation
> where the postgres service uses the [`zulip/zulip-postgresql`](https://hub.docker.com/r/zulip/zulip-postgresql) image

Run this as a cron job, for example:

```
45 3 * * * $HOME/path/to/zulip-pg-backup/zulip_postgres_backup.sh remote bucket/path >> $HOME/path/to/zulip-pg-backup/logs/backup_`date +\%Y\%m\%d_\%H\%M\%S`.log 2>&1
```

