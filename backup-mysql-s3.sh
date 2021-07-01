#!/bin/bash
# Backup mysql databases to S3
#
# Environment variables:
#	AWS_ACCESS_KEY
#	AWS_ACCESS_SECRET
#	AWS_REGION
#	MYSQL_HOST
#	MYSQL_USER
#	MYSQL_PASS
#	BACKUP_BUCKET
#	BACKUP_PATH	Must end with '/'

ensure_aws_credentials()
{
	if [[ -z "$AWS_ACCESS_KEY" ]]; then
		echo "AWS credentials not provided"
		exit 1
	fi
	if [[ -z "$AWS_ACCESS_SECRET" ]]; then
		echo "AWS credentials not provided"
		exit 1
	fi
	if [[ -z "$AWS_REGION" ]]; then
		echo "AWS region not provided"
		exit 1
	fi
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
	
	# Try getting list of DB to ensure credentials are correct
	mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "-p$MYSQL_PASS" -s -e 'SHOW DATABASES;' 1>/dev/null 2>/dev/null
	if [[ "$?" != "0" ]]; then
		echo "Unable to connect to mysql with provided credentials"
		exit 2
	fi
}

ensure_aws_credentials
ensure_mysql_credentials

if [[ -z "$BACKUP_BUCKET" ]]; then
	echo "Backup bucket not provided"
	exit 3
fi

DATABASE_LIST=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "-p$MYSQL_PASS" -s -e 'SHOW DATABASES;' 2>/dev/null)
DATABASE_LIST_FILTERED=()

while IFS= read -r LINE; do
	if [[ "$LINE" == "information_schema" || "$LINE" == "performance_schema" || "$LINE" == "mysql" || "$LINE" == "sys" ]]; then
		true
	else
		DATABASE_LIST_FILTERED+=("$LINE")
	fi
done <<< "$DATABASE_LIST"

printf -v DATE '%(%Y-%m-%d)T\n' -1 
SALT=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 5 ; echo '')

for DB in "${DATABASE_LIST_FILTERED[@]}"; do
	echo "Backing up '$DB'"
	
	OUT_FILE="/tmp/$DB.$SALT.sql"

	mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" "-p$MYSQL_PASS" "$DB" > "$OUT_FILE"
	bzip2 "$OUT_FILE"
	OUT_FILE="/tmp/$DB.$SALT.sql.bz2"
	
	AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$AWS_ACCESS_SECRET" AWS_DEFAULT_REGION="$AWS_REGION" aws s3 cp "$OUT_FILE" "s3://$BACKUP_BUCKET/$BACKUP_PATH$DATE/$DB.sql.bz2"
	
	rm "$OUT_FILE"
done

