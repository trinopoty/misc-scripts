#!/bin/bash
# Backup mysql databases to S3

parse_args()
{
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mysql-host)
                export MYSQL_HOST=$2
                shift
                shift
                ;;
            --mysql-user)
                export MYSQL_USER=$2
                shift
                shift
                ;;
            --mysql-pass)
                export MYSQL_PASS=$2
                shift
                shift
                ;;
            --s3-bucket)
                export BACKUP_BUCKET=$2
                shift
                shift
                ;;
            --s3-prefix)
                export BACKUP_PATH=$2
                shift
                shift
                ;;
            -*|--*)
                echo "Unknown option: $1"
                exit 1
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
}

ensure_mysql_credentials()
{
    if [[ -z "$MYSQL_HOST" ]]; then
        echo "Mysql host not provided"
        exit 2
    fi
    if [[ -z "$MYSQL_USER" ]]; then
        echo "Mysql username not provided"
        exit 2
    fi
    if [[ -z "$MYSQL_PASS" ]]; then
        echo "Mysql password not provided"
        exit 2
    fi
}

parse_args "$@"
ensure_mysql_credentials

if [[ -z "$BACKUP_BUCKET" ]]; then
    echo "Backup bucket not provided"
    exit 3
fi

DATABASE_LIST=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "-p$MYSQL_PASS" -s -e 'SHOW DATABASES;' 2>/dev/null)
if [[ "$?" != "0" ]]; then
    echo "Unable to connect to mysql with provided credentials"
    exit 2
fi

DATABASE_LIST_FILTERED=()

while IFS= read -r LINE; do
    if [[ "$LINE" == "information_schema" || "$LINE" == "performance_schema" || "$LINE" == "mysql" || "$LINE" == "sys" ]]; then
        true
    else
        DATABASE_LIST_FILTERED+=("$LINE")
    fi
done <<< "$DATABASE_LIST"

printf -v DATE '%(%Y-%m-%d %H:%M:%S)T\n' -1 
SALT=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 5 ; echo '')

for DB in "${DATABASE_LIST_FILTERED[@]}"; do
    echo "Backing up '$DB'"

    OUT_FILE="/tmp/$DB.$SALT.sql"

    mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" "-p$MYSQL_PASS" "$DB" > "$OUT_FILE"
    bzip2 "$OUT_FILE"
    OUT_FILE="/tmp/$DB.$SALT.sql.bz2"

    aws s3 cp "$OUT_FILE" "s3://$BACKUP_BUCKET/$BACKUP_PATH$DATE/$DB.sql.bz2"

    rm "$OUT_FILE"
done
