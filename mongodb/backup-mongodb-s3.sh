#!/bin/bash

UPLOAD_BUCKET=""
HOME_DIR="/home/$(whoami)"
BACKUP_DIR="$HOME_DIR/.mongo-backup"

rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

mongodump

rm -rf "$BACKUP_DIR/dump/admin"

for database in "$BACKUP_DIR/dump"/*; do
  database=$(basename "$database")
  FILE_NAME="[$(hostname)]-$(date +'%H%M')-$database.tar.bz2"
  UPLOAD_KEY="database/$(date +'%Y/%m/%d')/$FILE_NAME"

  tar -c "dump/$database" | bzip2 > "$FILE_NAME"
  /usr/local/bin/aws s3 cp "$FILE_NAME" "s3://$UPLOAD_BUCKET/$UPLOAD_KEY"
done

cd "$HOME_DIR"
rm -rf "$BACKUP_DIR"
