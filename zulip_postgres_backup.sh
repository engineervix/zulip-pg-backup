#!/usr/bin/env bash

# =================================================================================================
# A custom dokku backup script for a postgres database service created via
# the `zulip/zulip-postgresql` image, which is configured differently from a 
# standard postgres database service, resulting in problems backing up the
# database using the standard dokku-postgres plugin's `postgres:backup` command,
# which fails with:
# 
# `pg_dump: error: could not translate host name "dokku-postgres-postgres-zulip" to address: Temporary failure in name resolution`
# 
# We therefor have to create a workaround to backup the database, which is
# what this script does.

# Steps:
# 1. get the password from `SECRETS_postgres_password`
# 2. get the container name from `docker ps`
# 3. dump the database
# 4. upload the dump to the backup service (RCLONE_REMOTE & RCLONE_PATH are args to this script)
# 5. if step 4 is successful, delete the dump file

# author:       Victor Miti <https://github.com/engineervix>
# license:      BSD-3-Clause
# =================================================================================================

set -e  # Exit immediately if any command fails

# 1. cd to project directory
cd "${HOME}/SITES/zulip-pg-backup" || { echo "Failed to change directory."; exit 1; }

# Source the .env file so we can retrieve healthchecks.io ping URL
# shellcheck source=/dev/null
source healthchecks.env

# Send success signal to healthchecks.io
function send_healthcheck_success() {
    curl -fsS --retry 3 "${HEALTHCHECKS_PING_URL}" > /dev/null
}

# Send failure signal to healthchecks.io
function send_healthcheck_failure() {
    curl -fsS --retry 3 "${HEALTHCHECKS_PING_URL}/fail" > /dev/null
}

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <RCLONE_REMOTE> <RCLONE_PATH>"
    exit 1
fi

RCLONE_REMOTE=$1
RCLONE_PATH=$2

# Fetch necessary details for the backup
db_password=$(dokku config:get zulip SECRETS_postgres_password)
container=$(docker ps --format "{{.Names}}" | grep postgres | grep zulip)
db_name="zulip"
db_user="zulip"
filename="${db_name}_pg_backup_$(date '+%Y%m%d_%H%M%S').sql.gz"

# Dump the database and gzip the output
docker exec -i "$container" /bin/bash -c "PGPASSWORD=$db_password pg_dump -Fc --no-acl --no-owner -U $db_user -w $db_name" | gzip > "${filename}" || { echo "Failed create a database dump."; send_healthcheck_failure; exit 1; }

# Upload the backup to your desired remote location, using rclone
if rclone copy "$filename" "${RCLONE_REMOTE}:${RCLONE_PATH}/"; then
    # If successful, delete the local backup file
    echo "Backup successfully uploaded. Deleting local backup file..."
    rm -rv "$filename"
else
    # If the upload fails, print an error message and exit
    echo "Error: Failed to upload backup to $RCLONE_REMOTE. Keeping the local backup file: $filename"
    send_healthcheck_failure
    exit 1
fi

# Send success signal to healthchecks.io
send_healthcheck_success
