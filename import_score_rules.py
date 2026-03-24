#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将 score.sh 的评分逻辑导入为系统评分规则配置
对应达梦数据库操作考试的 9 道题目
"""

import asyncio
import os
import sys
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

# 检查依赖
try:
    import mysql.connector
except ImportError:
    print("[错误] 缺少依赖：pip3 install mysql-connector-python")
    sys.exit(1)


# 数据库配置
DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 3306)),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "linux_exam"),
}


# 9 道题目的评分规则配置（基于 score.sh）
SCORE_RULES = [
    {
        "question_title": "数据库卸载",
        "question_content": """请完整卸载达梦数据库软件，包括：
1. 停止数据库服务
2. 删除数据库安装目录
3. 清理相关配置文件
4. 清理环境变量

注意事项：
- 确保数据库服务已完全停止
- 删除所有安装相关文件
- 清理 /etc 下的配置文件
- 移除环境变量中的数据库路径""",
        "category": "达梦数据库操作",
        "difficulty": 2,
        "max_score": 4,
        "rule_name": "数据库卸载评分",
        "initial_score": 4,
        "check_items": [
            {
                "description": "检查数据库软件是否已卸载",
                "check_type": "file_not_exists",
                "check_target": "/home/dmdba/dmdbms/jar",
                "expected_value": None,
                "compare_operator": "eq",
                "deduction_points": 4,
                "fail_message": "数据库软件未成功卸载",
                "sort_order": 1,
            },
        ],
    },
    {
        "question_title": "重新安装部署数据库",
        "question_content": """请重新安装并配置达梦数据库，要求：
1. 安装路径：/dm
2. 数据库名：DAMENG
3. 实例名：PROD
4. 端口号：5236
5. 字符集：UTF-8 (1)
6. 恢复原有数据

安装完成后确保数据库服务正常启动。""",
        "category": "达梦数据库操作",
        "difficulty": 3,
        "max_score": 14,
        "rule_name": "数据库安装部署评分",
        "initial_score": 14,
        "check_items": [
            {
                "description": "检查安装路径是否正确",
                "check_type": "file_exists",
                "check_target": "/dm",
                "expected_value": None,
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "安装路径错误，应为 /dm",
                "sort_order": 1,
            },
            {
                "description": "检查数据库名",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_dbname.sql",
                "expected_value": "DAMENG",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "数据库名应为 DAMENG",
                "sort_order": 2,
            },
            {
                "description": "检查实例名",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_instance.sql",
                "expected_value": "PROD",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "实例名应为 PROD",
                "sort_order": 3,
            },
            {
                "description": "检查端口号",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_portnum.sql",
                "expected_value": "5236",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "端口号应为 5236",
                "sort_order": 4,
            },
            {
                "description": "检查字符集设置",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_charset.sql",
                "expected_value": "1",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "字符集应为 UTF-8",
                "sort_order": 5,
            },
            {
                "description": "检查数据恢复",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_recover.sql",
                "expected_value": "107",
                "compare_operator": "eq",
                "deduction_points": 8,
                "fail_message": "原有数据库的数据未恢复",
                "sort_order": 6,
            },
        ],
    },
    {
        "question_title": "表空间及用户规划",
        "question_content": """请创建表空间和用户，要求：
1. 创建表空间 TBS，初始大小 64MB，每次扩展 2MB，最大 5120MB
2. 创建用户 DMEXAM，默认表空间为 TBS
3. 密码有效期 120 天
4. 授予 TABLE 和 PROCEDURE 权限

SQL 参考：
CREATE TABLESPACE TBS DATAFILE '/dm/data/TBS.DBF' SIZE 64 AUTOEXTEND ON NEXT 2 MAXSIZE 5120;
CREATE USER DMEXAM IDENTIFIED BY Dameng123 DEFAULT TABLESPACE TBS;
""",
        "category": "达梦数据库操作",
        "difficulty": 2,
        "max_score": 8,
        "rule_name": "表空间及用户评分",
        "initial_score": 8,
        "check_items": [
            {
                "description": "检查表空间初始大小",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tbsinitsize.sql",
                "expected_value": "64",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "表空间初始大小应为 64MB",
                "sort_order": 1,
            },
            {
                "description": "检查表空间扩展值",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tbsnext.sql",
                "expected_value": "2",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "表空间扩展值应为 2MB",
                "sort_order": 2,
            },
            {
                "description": "检查表空间最大值",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tbsmax.sql",
                "expected_value": "5120",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "表空间最大值应为 5120MB",
                "sort_order": 3,
            },
            {
                "description": "检查用户是否存在",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_usertest.sql",
                "expected_value": "DMEXAM",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "用户 DMEXAM 不存在",
                "sort_order": 4,
            },
            {
                "description": "检查密码有效期设置",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_userlife.sql",
                "expected_value": "120",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "密码有效期应为 120 天",
                "sort_order": 5,
            },
            {
                "description": "检查用户默认表空间",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_usertbs.sql",
                "expected_value": "TBS",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "用户默认表空间应为 TBS",
                "sort_order": 6,
            },
            {
                "description": "检查用户权限",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_userprivs.sql",
                "expected_value": "TABLE,PROCEDURE",
                "compare_operator": "contains",
                "deduction_points": 1,
                "fail_message": "用户权限配置错误",
                "sort_order": 7,
            },
        ],
    },
    {
        "question_title": "表管理及数据导出",
        "question_content": """请完成以下表管理操作：
1. 导入部门表（46 条数据）
2. 导入员工表（856 条数据）
3. 为员工表添加 CREATETIME 列，默认值为 SYSDATE
4. 将 TAB_EMP 表导出到 /dm/data/TAB_EMP.CSV

提示：使用 dexp 工具进行数据导出。""",
        "category": "达梦数据库操作",
        "difficulty": 2,
        "max_score": 18,
        "rule_name": "表管理及导出评分",
        "initial_score": 18,
        "check_items": [
            {
                "description": "检查部门表数据",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tabdata1.sql",
                "expected_value": "46",
                "compare_operator": "eq",
                "deduction_points": 4,
                "fail_message": "部门表未能导入或数据量不正确",
                "sort_order": 1,
            },
            {
                "description": "检查员工表数据",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tabdata2.sql",
                "expected_value": "856",
                "compare_operator": "eq",
                "deduction_points": 4,
                "fail_message": "员工表未能导入或数据量不正确",
                "sort_order": 2,
            },
            {
                "description": "检查 CREATETIME 列",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tab_col.sql",
                "expected_value": "CREATETIME",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "CREATETIME 列添加失败",
                "sort_order": 3,
            },
            {
                "description": "检查默认值设置",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_data_default.sql",
                "expected_value": "SYSDATE",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "默认值设置错误",
                "sort_order": 4,
            },
            {
                "description": "检查 TAB_EMP 表导出",
                "check_type": "file_exists",
                "check_target": "/dm/data/TAB_EMP.CSV",
                "expected_value": None,
                "compare_operator": "eq",
                "deduction_points": 8,
                "fail_message": "TAB_EMP 表没有导出",
                "sort_order": 5,
            },
        ],
    },
    {
        "question_title": "创建视图",
        "question_content": """请创建以下视图：
1. V_EMPNUM: 统计各部门员工数量，查询'开发部'应返回正确人数
2. V_EMPSAL: 查询工资最高的前 10 名员工，最低工资应为 7237

要求：
- 视图名必须准确
- 数据查询正确""",
        "category": "达梦数据库操作",
        "difficulty": 2,
        "max_score": 8,
        "rule_name": "视图创建评分",
        "initial_score": 8,
        "check_items": [
            {
                "description": "检查视图 V_EMPNUM",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_view_tab1.sql",
                "expected_value": "V_EMPNUM",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "视图 V_EMPNUM 不存在",
                "sort_order": 1,
            },
            {
                "description": "检查 V_EMPNUM 内容（开发部人数）",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_view_content1.sql",
                "expected_value": "开发部",
                "compare_operator": "contains",
                "deduction_points": 2,
                "fail_message": "视图 V_EMPNUM 数据不正确",
                "sort_order": 2,
            },
            {
                "description": "检查视图 V_EMPSAL",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_view_tab2.sql",
                "expected_value": "10",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "视图 V_EMPSAL 不存在或数据量错误",
                "sort_order": 3,
            },
            {
                "description": "检查 V_EMPSAL 内容（最低工资）",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_view_content2.sql",
                "expected_value": "7237",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "视图 V_EMPSAL 数据不正确",
                "sort_order": 4,
            },
        ],
    },
    {
        "question_title": "数据库开发",
        "question_content": """请完成以下数据库开发任务：
1. 创建函数，返回员工总数（应为 270）
2. 创建事件日志表 T_EVENTLOG
3. 创建触发器 TR_EVENTLOG，记录表变更

要求：
- 函数能正确返回统计结果
- 触发器能正确记录日志""",
        "category": "达梦数据库操作",
        "difficulty": 3,
        "max_score": 20,
        "rule_name": "数据库开发评分",
        "initial_score": 20,
        "check_items": [
            {
                "description": "检查函数返回值",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_proc.sql",
                "expected_value": "270",
                "compare_operator": "eq",
                "deduction_points": 10,
                "fail_message": "函数创建失败或返回值错误",
                "sort_order": 1,
            },
            {
                "description": "检查事件日志表",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_tab1.sql",
                "expected_value": "T_EVENTLOG",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "记录触发器信息的表不存在",
                "sort_order": 2,
            },
            {
                "description": "检查触发器",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_trigg1.sql",
                "expected_value": "TR_EVENTLOG",
                "compare_operator": "eq",
                "deduction_points": 8,
                "fail_message": "触发器创建失败",
                "sort_order": 3,
            },
        ],
    },
    {
        "question_title": "定时作业",
        "question_content": """请创建以下定时作业：
1. FULLBAK: 每天 01:00 执行整库备份，间隔 1 天，类型 2
2. DELARCH: 每天 01:00 删除归档，间隔 0 天，类型 1

要求：
- 作业名称准确
- 执行时间正确
- 作业类型正确""",
        "category": "达梦数据库操作",
        "difficulty": 2,
        "max_score": 8,
        "rule_name": "定时作业评分",
        "initial_score": 8,
        "check_items": [
            {
                "description": "检查 FULLBAK 作业",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_job1.sql",
                "expected_value": "FULLBAK,1,01:00:00,2",
                "compare_operator": "contains",
                "deduction_points": 4,
                "fail_message": "FULLBAK 作业配置不正确",
                "sort_order": 1,
            },
            {
                "description": "检查 DELARCH 作业",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_job2.sql",
                "expected_value": "DELARCH,0,01:00:00,1",
                "compare_operator": "contains",
                "deduction_points": 4,
                "fail_message": "DELARCH 作业配置不正确",
                "sort_order": 2,
            },
        ],
    },
    {
        "question_title": "性能优化",
        "question_content": """请完成以下性能优化操作：
1. 在 EMPLOYEE_NAME 列创建索引 IX_EMP_EMPNAME
2. 收集 TAB_EMP 表的统计信息
3. 设置 SQL 缓冲区大小为 500

提示：使用 DBMS_STATS 包收集统计信息。""",
        "category": "达梦数据库操作",
        "difficulty": 2,
        "max_score": 10,
        "rule_name": "性能优化评分",
        "initial_score": 10,
        "check_items": [
            {
                "description": "检查索引创建",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_index.sql",
                "expected_value": "IX_EMP_EMPNAME",
                "compare_operator": "eq",
                "deduction_points": 3,
                "fail_message": "索引 IX_EMP_EMPNAME 未创建",
                "sort_order": 1,
            },
            {
                "description": "检查索引列",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_index_count.sql",
                "expected_value": "EMPLOYEE_NAME",
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "索引列不正确",
                "sort_order": 2,
            },
            {
                "description": "检查统计信息收集",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_statistic.sql",
                "expected_value": "NULL",
                "compare_operator": "ne",
                "deduction_points": 4,
                "fail_message": "未搜集 TAB_EMP 表的统计信息",
                "sort_order": 3,
            },
            {
                "description": "检查 SQL 缓冲区大小",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_sqlbuf.sql",
                "expected_value": "500",
                "compare_operator": "eq",
                "deduction_points": 3,
                "fail_message": "SQL 缓冲区大小设置错误",
                "sort_order": 4,
            },
        ],
    },
    {
        "question_title": "数据库安全",
        "question_content": """请完成以下安全配置：
1. 打开数据库归档模式
2. 设置归档路径为 /dm/arch
3. 设置归档文件大小为 128MB
4. 创建备份目录 /dm/backup/
5. 执行一次整库备份（生成.meta 文件）
6. 执行逻辑备份（生成 dmexam.dmp 和 dmexam.log）""",
        "category": "达梦数据库操作",
        "difficulty": 3,
        "max_score": 10,
        "rule_name": "数据库安全评分",
        "initial_score": 10,
        "check_items": [
            {
                "description": "检查归档模式",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_arch.sql",
                "expected_value": "Y",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "未打开归档",
                "sort_order": 1,
            },
            {
                "description": "检查归档路径",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_arch_dest.sql",
                "expected_value": "/dm/arch",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "归档路径错误",
                "sort_order": 2,
            },
            {
                "description": "检查归档文件大小",
                "check_type": "db_query",
                "check_target": "/var/local/sc/rw_arch_file.sql",
                "expected_value": "128",
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "归档文件大小错误",
                "sort_order": 3,
            },
            {
                "description": "检查备份目录",
                "check_type": "file_exists",
                "check_target": "/dm/backup",
                "expected_value": None,
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "备份指定路径不存在",
                "sort_order": 4,
            },
            {
                "description": "检查整库备份",
                "check_type": "command_output",
                "check_target": "find /dm/backup -name '*.meta' | wc -l",
                "expected_value": "1",
                "compare_operator": "eq",
                "deduction_points": 3,
                "fail_message": "整库备份不存在",
                "sort_order": 5,
            },
            {
                "description": "检查逻辑备份文件",
                "check_type": "file_exists",
                "check_target": "/dm/backup/dmexam.dmp",
                "expected_value": None,
                "compare_operator": "eq",
                "deduction_points": 2,
                "fail_message": "逻辑备份文件不存在",
                "sort_order": 6,
            },
            {
                "description": "检查逻辑备份日志",
                "check_type": "file_exists",
                "check_target": "/dm/backup/dmexam.log",
                "expected_value": None,
                "compare_operator": "eq",
                "deduction_points": 1,
                "fail_message": "逻辑备份日志不存在",
                "sort_order": 7,
            },
        ],
    },
]


async def import_rules():
    """导入评分规则到数据库"""
    print("╔══════════════════════════════════════════════════════════╗")
    print("║     达梦数据库考试 - 评分规则导入工具                     ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    # 连接数据库
    print(f"[INFO] 连接数据库 {DB_CONFIG['database']}@{DB_CONFIG['host']}...")
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        print("[OK]   数据库连接成功")
    except Exception as e:
        print(f"[ERROR] 数据库连接失败：{e}")
        print("[TIP]   请确认：")
        print("        1. 数据库服务已启动")
        print("        2. .env 文件中配置了正确的数据库密码")
        return 1

    try:
        # 1. 创建或查找分类
        print("\n[INFO] 处理分类...")
        category_name = "达梦数据库操作"
        cursor.execute("SELECT id FROM categories WHERE name = %s", (category_name,))
        category = cursor.fetchone()

        if not category:
            cursor.execute(
                "INSERT INTO categories (name, description) VALUES (%s, %s)",
                (category_name, "达梦数据库管理操作考试题目"),
            )
            category_id = cursor.lastrowid
            print(f"       创建分类：{category_name} (ID={category_id})")
        else:
            category_id = category["id"]
            print(f"       使用现有分类：{category_name} (ID={category_id})")
        conn.commit()

        # 2. 遍历 9 道题目
        for idx, rule_config in enumerate(SCORE_RULES, 1):
            print(f"\n[INFO] 处理第 {idx} 题：{rule_config['question_title']}")

            # 2.1 创建或查找题目
            cursor.execute(
                "SELECT id FROM questions WHERE title = %s AND category_id = %s",
                (rule_config["question_title"], category_id),
            )
            question = cursor.fetchone()

            if question:
                question_id = question["id"]
                print(f"       题目已存在 (ID={question_id})")
                # 删除旧的评分规则
                cursor.execute(
                    "SELECT id FROM scoring_rules WHERE question_id = %s", (question_id,)
                )
                old_rules = cursor.fetchall()
                for old_rule in old_rules:
                    cursor.execute(
                        "DELETE FROM check_items WHERE rule_id = %s", (old_rule["id"],)
                    )
                    cursor.execute("DELETE FROM scoring_rules WHERE id = %s", (old_rule["id"],))
                print(f"       已清理旧的评分规则")
            else:
                # 创建题目
                cursor.execute(
                    """INSERT INTO questions 
                       (title, content, category_id, difficulty, max_score, sort_order, is_active) 
                       VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                    (
                        rule_config["question_title"],
                        rule_config["question_content"],
                        category_id,
                        rule_config["difficulty"],
                        rule_config["max_score"],
                        idx,
                        True,
                    ),
                )
                question_id = cursor.lastrowid
                print(f"       创建题目 (ID={question_id}, 分值={rule_config['max_score']})")

            # 2.2 创建评分规则
            cursor.execute(
                """INSERT INTO scoring_rules 
                   (question_id, name, description, initial_score) 
                   VALUES (%s, %s, %s, %s)""",
                (
                    question_id,
                    rule_config["rule_name"],
                    f"第{idx}题评分规则",
                    rule_config["initial_score"],
                ),
            )
            rule_id = cursor.lastrowid
            print(f"       创建评分规则 (ID={rule_id})")

            # 2.3 创建检查项
            for item in rule_config["check_items"]:
                cursor.execute(
                    """INSERT INTO check_items 
                       (rule_id, description, check_type, check_target, expected_value, 
                        compare_operator, deduction_points, fail_message, sort_order, is_active) 
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (
                        rule_id,
                        item["description"],
                        item["check_type"],
                        item["check_target"],
                        item.get("expected_value"),
                        item.get("compare_operator", "eq"),
                        item["deduction_points"],
                        item.get("fail_message"),
                        item["sort_order"],
                        True,
                    ),
                )
            print(f"       创建 {len(rule_config['check_items'])} 个检查项")

        conn.commit()

        print("\n" + "=" * 60)
        print("[SUCCESS] 评分规则导入完成！")
        print("=" * 60)
        print(f"分类：{category_name}")
        print(f"题目数量：{len(SCORE_RULES)}")
        total_score = sum(r["max_score"] for r in SCORE_RULES)
        print(f"总分：{total_score}")
        print()
        print("题目列表:")
        for idx, rule in enumerate(SCORE_RULES, 1):
            print(f"  {idx}. {rule['question_title']} ({rule['max_score']}分)")

        print("\n[下一步]")
        print("1. 创建考试场次：")
        print("   访问 http://localhost:3000/exams 创建新考试")
        print("   选择分类：达梦数据库操作")
        print("   题目数量：9")
        print()
        print("2. 启动考试后，客户端可获取题目并执行评分")

        return 0

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] 导入失败：{e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    exit_code = asyncio.run(import_rules())
    sys.exit(exit_code)
