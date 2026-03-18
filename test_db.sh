#!/bin/bash
db_url="mysql://root:Password123321%21%40@localhost:3306/linux_exam"

echo "DATABASE_URL: $db_url"

# Extract using the same method as install.sh
db_pass=$(echo "$db_url" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
echo "Extracted password (URL-encoded): $db_pass"

# URL decode
db_pass_decoded=$(printf '%b' "${db_pass//%/\\x}")
echo "Decoded password: $db_pass_decoded"

# Test connection
echo "Testing connection..."
MYSQL_PWD="$db_pass_decoded" mysql -h localhost -P 3306 -u root -e "SELECT 1"
echo "Result: $?"
