#!/bin/bash

# Set database connection details
DB_USER="postgres"
DB_PASSWORD="pass"
DB_HOST="localhost"
DB_PORT="54445"
CURRENT_DATE=$(date +'%Y%m%d')
BACKUP_PATH="/data2/${CURRENT_DATE}"
mkdir -p ${BACKUP_PATH}
JOBS=20  # Number of parallel jobs
#S3_BUCKET="http://s3.thr1.url.ir/postgresql-backups"
S3_BUCKET="postgresql-backups"
BACKUP_FILENAME="${CURRENT_DATE}_postgres_backup.tar.gz"





#
## Export PGPASSWORD so it’s used by all PostgreSQL commands
export PGPASSWORD="$DB_PASSWORD"

echo "Starting PostgreSQL backup..."

# ---- DUMP ALL SCHEMAS ----
echo "Dumping all schemas..."
pg_dumpall -s -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > "$BACKUP_PATH/all_schema.sql"
if [ $? -ne 0 ]; then
    echo "Schema dump failed."
    exit 1
fi

# Get a list of non-template databases
databases=$(psql -t -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -c "SELECT datname FROM pg_database WHERE NOT datistemplate;" | grep '\S' | awk '{$1=$1};1')

# Loop through each database and perform parallel dump
for db in $databases; do
    echo "Dumping database: $db"
    pg_dump -h "$DB_HOST" -U "$DB_USER" -Fd -b -v -d "$db"  -p "$DB_PORT"   -j "$JOBS" -f "$BACKUP_PATH/$db"
    if [ $? -ne 0 ]; then
        echo "Backup of database $db failed."
        exit 1
    fi
done

tar -czvf "$BACKUP_PATH/$BACKUP_FILENAME" -C "$BACKUP_PATH" all_schema.sql $(echo $databases | xargs)

if [ $? -ne 0 ]; then
    echo "Compression failed."
    exit 1
fi



echo "Backup compression completed successfully: $BACKUP_PATH/$BACKUP_FILENAME"

# ---- UPLOAD TO S3 ----
echo "Uploading $BACKUP_FILENAME to S3..."
#aws s3 cp "$BACKUP_PATH/$BACKUP_FILENAME"  --endpoint-url="http://s3.thr1.sotoon.ir" "$S3_BUCKET/$BACKUP_FILENAME"
aws s3 cp "$BACKUP_PATH/$BACKUP_FILENAME"   s3://postgresql-backups --endpoint-url "http://s3.thr1.sotoon.ir/"
if [ $? -ne 0 ]; then
    echo "Upload to S3 failed."

    exit 1
fi

echo "DELTE BACKUPFILE"

rm -rf "$BACKUP_PATH/all_schema.sql"
for db in $databases; do
    rm -rf "$BACKUP_PATH/$db"
done

echo "Backup uploaded to S3 successfully: $S3_BUCKET/$BACKUP_FILENAME"

 Unset the PGPASSWORD variable for security
unset PGPASSWORD

#
## ---- RESTORE ----
#echo "Starting PostgreSQL restore..."
#
## Restore all schemas
#psql -h "$DB_HOST" -U "$DB_USER" -p "$DB_PORT" < "$BACKUP_PATH/all_schema.sql"
#if [ $? -ne 0 ]; then
#    echo "Schema restore failed."
#    exit 1
#fi
#
## Loop through each database and restore from backup
#for db in $databases; do
#    echo "Restoring database: $db"
#    createdb -h "$DB_HOST" -U "$DB_USER" -p "$DB_PORT" "$db" 2>/dev/null || echo "Database $db already exists, skipping creation."
#
#    # Perform restore with parallel jobs
#    pg_restore -h "$DB_HOST" -U "$DB_USER"  -p "$DB_PORT" -d "$db" -j "$JOBS" -v "$BACKUP_PATH/$db"
#    if [ $? -ne 0 ]; then
#        echo "Restore of database $db failed."
#        exit 1
#    fi
#done
#
#echo "Restore completed successfully."
#
## Unset the PGPASSWORD variable for security
#unset PGPASSWORD
#
