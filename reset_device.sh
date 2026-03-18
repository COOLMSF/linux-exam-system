#!/bin/bash
# Reset student device binding
cd /root/linux_exam_system

DATABASE_URL=$(grep "^DATABASE_URL=" .env | cut -d= -f2-)
DB_PASS=$(echo "$DATABASE_URL" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
DB_PASS=$(printf '%b' "${DB_PASS//%/\\x}")

MYSQL_PWD="$DB_PASS" mysql -h localhost -u root linux_exam -e "UPDATE students SET deviceId=NULL, apiToken=NULL WHERE studentId='root'"
echo "Device binding reset for student 'root'"
