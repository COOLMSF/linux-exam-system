#!/usr/bin/env node
/**
 * 批量导入 MySQL 数据库运维考试题目（9 道，满分 100 分）
 * 用法: node seed_mysql_questions.js
 * 
 * 依赖: mysql2 (已在项目 package.json 中)
 */
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// 从 .env 读取数据库连接
const envFile = fs.readFileSync(path.join(__dirname, '.env'), 'utf8');
const dbUrlMatch = envFile.match(/^DATABASE_URL=(.+)$/m);
if (!dbUrlMatch) { console.error('未找到 DATABASE_URL'); process.exit(1); }
const dbUrl = new URL(dbUrlMatch[1]);

const dbCfg = {
  host: dbUrl.hostname,
  port: parseInt(dbUrl.port) || 3306,
  user: dbUrl.username,
  password: decodeURIComponent(dbUrl.password),
  database: dbUrl.pathname.replace('/', ''),
};

// ═══════════════════════════════════════════════
// 题目定义（9 道题，与 score.sh 评分点一一对应）
// ═══════════════════════════════════════════════
const QUESTIONS = [
  {
    title: "第1题：MySQL 服务管理",
    content: `请完成以下 MySQL 服务管理操作：

1. 确认 MySQL 服务已停止（若正在运行则先停止）
2. 删除 /tmp/mysql_old_data 目录（模拟卸载旧数据）
3. 重新启动 MySQL 服务
4. 确保 MySQL 服务设置为开机自启

评分标准：
  - MySQL 服务正在运行 (2分)
  - MySQL 服务已设置为开机自启 (1分)
  - /tmp/mysql_old_data 目录已被清理 (1分)`,
    difficulty: 1,
    maxScore: 4,
    sortOrder: 1,
  },
  {
    title: "第2题：数据库安装与初始化配置",
    content: `请完成 MySQL 数据库的部署与配置：

1. 创建数据库 {{db_expected}}，字符集设为 utf8mb4
2. 确保 MySQL 监听端口为 {{port_expected}}
3. 设置 MySQL server-id 为 {{server_id_expected}}
4. 设置 max_connections 为 200
5. 将 /var/lib/mysql_backup/examdata.sql 中的数据导入到 {{db_expected}} 库
   （若文件不存在，请先创建该文件并写入以下内容：
    CREATE TABLE IF NOT EXISTS recovery_test(id INT PRIMARY KEY, val VARCHAR(50));
    INSERT INTO recovery_test VALUES(1,'recovered'),(2,'data'),(107,'verify');
   ）

提示：
  修改 /etc/mysql/mysql.conf.d/mysqld.cnf 或 /etc/my.cnf
  修改后需重启 MySQL 服务

评分标准：
  - 数据库 {{db_expected}} 存在 (1分)
  - 字符集为 utf8mb4 (1分)
  - 监听端口为 {{port_expected}} (1分)
  - server-id 配置正确 (1分)
  - max_connections 为 200 (1分)
  - recovery_test 表中 id=107 的记录存在 (8分)
  - 数据导入文件存在 (1分)`,
    difficulty: 3,
    maxScore: 14,
    sortOrder: 2,
  },
  {
    title: "第3题：用户与权限管理",
    content: `请在 MySQL 中完成以下用户和权限配置：

1. 在 {{db_expected}} 库中创建表空间相关配置：
   - 创建数据库 {{db_expected}}（若不存在）
   - 设置该库默认字符集为 utf8mb4，排序规则为 utf8mb4_general_ci

2. 创建 MySQL 用户 '{{user_expected}}'@'%'，密码为 'ExamPass123!'
   - 设置密码过期时间为 120 天

3. 授权管理：
   - 授予 {{user_expected}} 对 {{db_expected}} 库的 SELECT, INSERT, UPDATE, DELETE 权限
   - 授予 {{user_expected}} 对 {{db_expected}} 库的 CREATE, DROP 权限
   - 授予 {{user_expected}} 对 {{db_expected}} 库的 CREATE ROUTINE, EXECUTE 权限

评分标准：
  - 数据库字符集正确 (1分)
  - 用户 {{user_expected}} 存在 (1分)
  - 密码过期策略正确 (1分)
  - 拥有 SELECT 权限 (1分)
  - 拥有 CREATE 权限 (1分)
  - 拥有 CREATE ROUTINE 权限 (1分)
  - 拥有 EXECUTE 权限 (1分)
  - 拥有 DELETE 权限 (1分)`,
    difficulty: 2,
    maxScore: 8,
    sortOrder: 3,
  },
  {
    title: "第4题：表管理与数据导入导出",
    content: `使用用户 {{user_expected}} 或 root 在 {{db_expected}} 数据库中完成：

1. 创建部门表 tab_dept：
   CREATE TABLE tab_dept (
     dept_id INT PRIMARY KEY,
     dept_name VARCHAR(50) NOT NULL,
     manager VARCHAR(50),
     location VARCHAR(100)
   );
   并插入 46 条记录（可使用存储过程批量生成）：
   INSERT INTO tab_dept VALUES(1,'开发部','张三','北京'), (2,'测试部','李四','上海'), ...
   共 46 行。

2. 创建员工表 tab_emp：
   CREATE TABLE tab_emp (
     emp_id INT PRIMARY KEY AUTO_INCREMENT,
     employee_name VARCHAR(50) NOT NULL,
     dept_id INT,
     salary DECIMAL(10,2),
     hire_date DATE,
     FOREIGN KEY (dept_id) REFERENCES tab_dept(dept_id)
   );
   并导入 856 条员工记录。

3. 为 tab_emp 表添加 create_time 列，类型为 DATETIME，默认值为 CURRENT_TIMESTAMP。

4. 将 tab_emp 表导出为 CSV 文件：/var/lib/mysql-files/tab_emp.csv
   （使用 SELECT ... INTO OUTFILE 或 mysqldump）

提示：
  可编写存储过程批量插入测试数据：
  DELIMITER //
  CREATE PROCEDURE gen_dept() BEGIN DECLARE i INT DEFAULT 1; WHILE i<=46 DO INSERT INTO tab_dept VALUES(i, CONCAT('部门',i), CONCAT('经理',i), '城市'); SET i=i+1; END WHILE; END //
  DELIMITER ;
  CALL gen_dept();

评分标准：
  - tab_dept 表存在且有 46 条记录 (4分)
  - tab_emp 表存在且有 ≥856 条记录 (4分)
  - tab_emp 表有 create_time 列 (2分)
  - create_time 默认值为 CURRENT_TIMESTAMP (2分)
  - CSV 导出文件存在 (4分)
  - 导出文件内容非空 (2分)`,
    difficulty: 3,
    maxScore: 18,
    sortOrder: 4,
  },
  {
    title: "第5题：视图管理",
    content: `在 {{db_expected}} 数据库中创建以下视图：

1. 创建视图 v_empnum — 按部门统计人数：
   CREATE VIEW v_empnum AS
   SELECT d.dept_name, COUNT(e.emp_id) AS emp_count
   FROM tab_dept d
   LEFT JOIN tab_emp e ON d.dept_id = e.dept_id
   GROUP BY d.dept_id, d.dept_name;

   要求：能查询到"开发部"或"部门1"的记录。

2. 创建视图 v_empsal — 统计薪资超过 5000 的员工数和总薪资：
   CREATE VIEW v_empsal AS
   SELECT COUNT(*) AS high_salary_count, IFNULL(SUM(salary),0) AS total_salary
   FROM tab_emp
   WHERE salary > 5000;

   要求：high_salary_count > 0

评分标准：
  - 视图 v_empnum 存在 (2分)
  - v_empnum 查询结果包含"开发部"或"部门1" (2分)
  - 视图 v_empsal 存在 (2分)
  - v_empsal 中 high_salary_count > 0 (2分)`,
    difficulty: 2,
    maxScore: 8,
    sortOrder: 5,
  },
  {
    title: "第6题：存储过程与触发器",
    content: `在 {{db_expected}} 数据库中完成以下编程题：

1. 创建存储过程 sp_emp_salary_sum，功能：
   输入参数 p_dept_id (INT)，返回该部门薪资合计（OUT 参数 p_total DECIMAL）。
   DELIMITER //
   CREATE PROCEDURE sp_emp_salary_sum(IN p_dept_id INT, OUT p_total DECIMAL(12,2))
   BEGIN
     SELECT IFNULL(SUM(salary),0) INTO p_total FROM tab_emp WHERE dept_id = p_dept_id;
   END //
   DELIMITER ;

2. 创建事件日志表 t_eventlog：
   CREATE TABLE t_eventlog (
     id INT PRIMARY KEY AUTO_INCREMENT,
     event_type VARCHAR(20),
     event_table VARCHAR(50),
     event_data TEXT,
     created_at DATETIME DEFAULT CURRENT_TIMESTAMP
   );

3. 创建触发器 tr_eventlog：
   在 tab_emp 表上创建 AFTER INSERT 触发器，每次插入员工时自动记录到 t_eventlog。
   DELIMITER //
   CREATE TRIGGER tr_eventlog AFTER INSERT ON tab_emp FOR EACH ROW
   BEGIN
     INSERT INTO t_eventlog(event_type, event_table, event_data)
     VALUES('INSERT', 'tab_emp', CONCAT('emp_id=', NEW.emp_id, ', name=', NEW.employee_name));
   END //
   DELIMITER ;

评分标准：
  - 存储过程 sp_emp_salary_sum 存在 (5分)
  - 调用存储过程能正确返回结果 (5分)
  - 事件日志表 t_eventlog 存在 (2分)
  - 触发器 tr_eventlog 存在 (4分)
  - 触发器属于 {{user_expected}} 或当前用户 (2分)
  - 插入 tab_emp 后 t_eventlog 有记录 (2分)`,
    difficulty: 3,
    maxScore: 20,
    sortOrder: 6,
  },
  {
    title: "第7题：定时任务（Event Scheduler）",
    content: `配置 MySQL 事件调度器，完成以下定时任务：

1. 确保 Event Scheduler 已开启：
   SET GLOBAL event_scheduler = ON;
   （建议同时写入配置文件 my.cnf 持久化）

2. 创建定时事件 evt_daily_backup：
   - 每天凌晨 01:00 执行
   - 功能：向 t_eventlog 表写入一条备份日志
   CREATE EVENT evt_daily_backup
   ON SCHEDULE EVERY 1 DAY STARTS CONCAT(CURDATE()+1,' 01:00:00')
   DO
     INSERT INTO t_eventlog(event_type, event_table, event_data)
     VALUES('BACKUP', 'system', 'Daily full backup triggered');

3. 创建定时事件 evt_weekly_cleanup：
   - 每周执行一次
   - 功能：清理 30 天前的事件日志
   CREATE EVENT evt_weekly_cleanup
   ON SCHEDULE EVERY 1 WEEK
   DO
     DELETE FROM t_eventlog WHERE created_at < NOW() - INTERVAL 30 DAY;

评分标准：
  - Event Scheduler 已开启 (2分)
  - evt_daily_backup 事件存在 (3分)
  - evt_weekly_cleanup 事件存在 (3分)`,
    difficulty: 2,
    maxScore: 8,
    sortOrder: 7,
  },
  {
    title: "第8题：性能优化",
    content: `对 {{db_expected}} 数据库进行以下性能优化：

1. 在 tab_emp 表的 employee_name 列上创建索引：
   CREATE INDEX ix_emp_empname ON tab_emp(employee_name);

2. 收集 tab_emp 表的统计信息：
   ANALYZE TABLE tab_emp;

3. 调整 InnoDB 缓冲池大小为 256M：
   在 my.cnf 中设置：innodb_buffer_pool_size = 268435456
   或通过 SET GLOBAL（仅 8.0+）：
   SET GLOBAL innodb_buffer_pool_size = 268435456;

评分标准：
  - 索引 ix_emp_empname 存在 (3分)
  - 索引列为 employee_name (1分)
  - tab_emp 表统计信息已更新（非 NULL） (3分)
  - innodb_buffer_pool_size ≥ 256M (3分)`,
    difficulty: 2,
    maxScore: 10,
    sortOrder: 8,
  },
  {
    title: "第9题：数据库安全与备份恢复",
    content: `完成以下数据库安全和备份配置：

1. 开启 MySQL 二进制日志（Binary Log）：
   在 my.cnf 中设置：
   log-bin = /var/log/mysql/mysql-bin
   binlog_format = ROW
   重启 MySQL 使配置生效。

2. 配置二进制日志过期时间为 7 天：
   SET GLOBAL binlog_expire_logs_seconds = 604800;
   或在 my.cnf 中：expire_logs_days = 7

3. 创建备份目录并执行全库备份：
   mkdir -p /var/lib/mysql_backup
   mysqldump -u root --all-databases > /var/lib/mysql_backup/full_backup.sql

4. 对 {{db_expected}} 库单独做逻辑备份：
   mysqldump -u root {{db_expected}} > /var/lib/mysql_backup/{{db_expected}}.sql

评分标准：
  - 二进制日志已开启 (1分)
  - binlog 格式为 ROW (1分)
  - 二进制日志过期时间已设置 (1分)
  - 备份目录存在 (1分)
  - 全库备份文件存在 (3分)
  - 单库备份文件存在 (3分)`,
    difficulty: 2,
    maxScore: 10,
    sortOrder: 9,
  },
];

async function main() {
  let conn;
  try {
    conn = await mysql.createConnection(dbCfg);
    console.log('数据库连接成功\n');

    // 1. 创建分类
    await conn.execute(`
      INSERT INTO question_categories (name, description)
      VALUES ('MySQL 数据库运维', 'MySQL/达梦数据库安装配置、SQL操作、性能优化、备份恢复')
      ON DUPLICATE KEY UPDATE description='MySQL/达梦数据库安装配置、SQL操作、性能优化、备份恢复'
    `);
    const [catRows] = await conn.execute("SELECT id FROM question_categories WHERE name='MySQL 数据库运维'");
    const categoryId = catRows[0].id;
    console.log(`✓ 分类创建成功 (categoryId=${categoryId})`);

    // 2. 删除该分类下旧题目
    await conn.execute('DELETE FROM questions WHERE categoryId = ?', [categoryId]);

    // 3. 插入新题目
    for (const q of QUESTIONS) {
      await conn.execute(`
        INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
        VALUES (?, ?, ?, ?, ?, 1, ?)
      `, [q.title, q.content, categoryId, q.difficulty, q.maxScore, q.sortOrder]);
    }
    console.log(`✓ 已插入 ${QUESTIONS.length} 道题目`);

    // 4. 查看总分
    const [sumRow] = await conn.execute(
      'SELECT COUNT(*) AS cnt, SUM(maxScore) AS total FROM questions WHERE categoryId = ?',
      [categoryId]
    );
    console.log(`  题目数：${sumRow[0].cnt}，满分：${sumRow[0].total}`);

    // 5. 列出所有题目
    const [rows] = await conn.execute(
      'SELECT id, title, maxScore, sortOrder FROM questions WHERE categoryId = ? ORDER BY sortOrder',
      [categoryId]
    );
    console.log('\n题目列表：');
    console.log('─'.repeat(60));
    for (const r of rows) {
      console.log(`  [ID:${r.id}] ${r.title} (${r.maxScore}分)`);
    }
    console.log('─'.repeat(60));
    console.log(`\n分类 ID: ${categoryId}`);
    console.log('创建考试时请选择此分类，题目数设为 9。');

    await conn.end();
  } catch (err) {
    console.error('执行失败:', err.message);
    if (conn) await conn.end();
    process.exit(1);
  }
}

main();
