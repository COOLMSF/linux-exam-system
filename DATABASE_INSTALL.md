# Database Installation, Initialization and Migration Guide

This document describes the database installation, initialization, migration, and testing procedures for the Linux Exam System.

## Table of Contents

1. [Overview](#overview)
2. [Database Installation](#database-installation)
3. [Database Initialization](#database-initialization)
4. [Database Migration](#database-migration)
5. [Testing](#testing)
6. [Troubleshooting](#troubleshooting)

## Overview

The Linux Exam System uses MySQL (or MariaDB/DM8 with MySQL compatibility) as its database. The installation script handles:

- MySQL server installation
- Database and user creation
- Schema migration using Drizzle ORM
- Verification and testing

## Database Installation

### Automatic Installation (Recommended)

Run the one-click installation script:

```bash
sudo bash install.sh
```

This will:
1. Install MySQL server and client
2. Start the MySQL service
3. Create the `linux_exam` database
4. Create the `exam_user` database user with a random password
5. Update the `.env` file with the database connection string

### Reset Database (Forgot Password)

If you forgot the database password or want to reset all data:

```bash
sudo bash install.sh --reset-db
```

**Warning**: This will:
- Delete the existing `linux_exam` database
- Delete the `exam_user` user
- Create a new database and user with a random password
- Re-run all database migrations
- **All exam records, student data, and questions will be permanently lost!**

The script will ask for confirmation before proceeding.

### Manual Installation

If you prefer to install MySQL manually:

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install mysql-server mysql-client
sudo systemctl start mysql
sudo systemctl enable mysql
```

#### CentOS/Kylin

```bash
sudo yum install mysql-server mysql
sudo systemctl start mysqld
sudo systemctl enable mysqld
```

### Verify MySQL Installation

```bash
mysqladmin ping -h localhost
# Should output: mysqld is alive
```

## Database Initialization

### Using Install Script

The install script automatically initializes the database:

```bash
sudo bash install.sh
```

### Manual Initialization

1. Connect to MySQL as root:

```bash
mysql -h localhost -u root -p
```

2. Create database and user:

```sql
CREATE DATABASE IF NOT EXISTS linux_exam 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'exam_user'@'localhost' 
  IDENTIFIED BY 'your_secure_password';

GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
FLUSH PRIVILEGES;
```

3. Update `.env` file:

```env
DATABASE_URL=mysql://exam_user:your_secure_password@localhost:3306/linux_exam
```

## Database Migration

### Using Drizzle ORM

The project uses Drizzle ORM for schema management.

1. Generate migrations:

```bash
pnpm db:push
```

This command:
- Generates migration files based on schema changes
- Applies migrations to the database

### Manual Migration

If Drizzle fails, you can apply SQL migrations manually:

```bash
# Apply all migration files
for sql_file in drizzle/*.sql; do
  MYSQL_PWD="your_password" mysql -h localhost -u exam_user linux_exam < "$sql_file"
done
```

### Migration Files Location

Migration files are stored in `drizzle/`:
- `drizzle/schema.ts` - TypeScript schema definitions
- `drizzle/0000_*.sql` - SQL migration files

### Current Schema Tables

The system creates the following tables:

| Table | Description |
|-------|-------------|
| `users` | User accounts (admins) |
| `students` | Student accounts |
| `question_categories` | Question categories |
| `questions` | Exam questions |
| `scoring_rules` | Scoring rules for questions |
| `scoring_check_items` | Individual check items for scoring |
| `exam_sessions` | Exam session definitions |
| `exam_question_assignments` | Student-question assignments |
| `exam_records` | Exam attempt records |
| `score_details` | Detailed scores per question |

## Testing

### Bash Test Script

Run comprehensive database tests:

```bash
# Run all tests
bash test_database_install.sh

# Run only unit tests
bash test_database_install.sh --unit

# Run only integration tests
bash test_database_install.sh --integration

# Show help
bash test_database_install.sh --help
```

Test categories:
- **Unit Tests**: MySQL installation, service status, configuration
- **Integration Tests**: Database connection, table structure, migrations
- **Function Tests**: CRUD operations (INSERT, SELECT, UPDATE, DELETE)
- **Performance Tests**: Connection latency, concurrent connections

### Node.js Integration Tests

Run Vitest-based integration tests:

```bash
# Run all tests including database tests
pnpm test

# Run only database integration tests
pnpm test:db

# Run with watch mode
pnpm test:db --watch
```

Test coverage:
- Database connection
- Schema validation
- User CRUD operations
- Student CRUD operations
- Question and category operations
- Exam session operations
- Scoring rules and check items
- Exam records and score details
- Performance tests

### NPM Scripts

```bash
# Run all tests
pnpm test

# Run database integration tests
pnpm test:db

# Run bash database tests
pnpm db:test

# Push database migrations
pnpm db:push
```

## Troubleshooting

### MySQL Connection Failed

**Error**: `Can't connect to MySQL server`

**Solutions**:
1. Check if MySQL is running:
   ```bash
   systemctl status mysql
   # or
   service mysql status
   ```

2. Start MySQL if not running:
   ```bash
   sudo systemctl start mysql
   ```

3. Check port 3306 is listening:
   ```bash
   ss -tlnp | grep 3306
   ```

### Database User Permission Denied

**Error**: `Access denied for user 'exam_user'@'localhost'`

**Solutions**:
1. Verify user exists:
   ```sql
   SELECT User, Host FROM mysql.user WHERE User='exam_user';
   ```

2. Grant permissions:
   ```sql
   GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
   FLUSH PRIVILEGES;
   ```

3. Check password in `.env` matches the database user password

### Migration Failed

**Error**: `Table doesn't exist` or `Column not found`

**Solutions**:
1. Re-run migrations:
   ```bash
   pnpm db:push
   ```

2. Manually apply migrations:
   ```bash
   bash -c 'for f in drizzle/*.sql; do MYSQL_PWD="password" mysql -u exam_user linux_exam < "$f"; done'
   ```

3. Verify tables exist:
   ```bash
   MYSQL_PWD="password" mysql -u exam_user linux_exam -e "SHOW TABLES;"
   ```

### Test Failures

**Error**: Tests failing with connection errors

**Solutions**:
1. Ensure MySQL is running
2. Verify `.env` file exists and has correct `DATABASE_URL`
3. Check database user has proper permissions
4. Run tests with verbose output:
   ```bash
   bash test_database_install.sh --all 2>&1 | tee test_output.log
   ```

### Character Set Issues

**Error**: `Incorrect string value`

**Solutions**:
1. Verify database character set:
   ```sql
   SELECT DEFAULT_CHARACTER_SET_NAME 
   FROM information_schema.SCHEMATA 
   WHERE SCHEMA_NAME='linux_exam';
   ```

2. Should be `utf8mb4`. If not, recreate database:
   ```sql
   DROP DATABASE linux_exam;
   CREATE DATABASE linux_exam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

## Security Notes

1. **Change Default Passwords**: The install script generates random passwords. For production, use strong, unique passwords.

2. **Restrict User Permissions**: The `exam_user` should only have access to the `linux_exam` database.

3. **Secure .env File**: Ensure `.env` is not committed to version control and has proper file permissions:
   ```bash
   chmod 600 .env
   ```

4. **Network Security**: By default, MySQL binds to localhost only. For remote access, configure MySQL and firewall appropriately.

## Support

For additional help:
1. Check installation logs: `/var/log/linux-exam-install.log` or `/tmp/linux-exam-install.log`
2. Review MySQL error logs: `/var/log/mysql/error.log`
3. Run diagnostic tests: `bash test_database_install.sh --all`
