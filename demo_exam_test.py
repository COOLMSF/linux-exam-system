#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Linux 考试系统 - 演示考试测试脚本
一键测试：创建测试数据 + 学生答题 + 自动评分

用法:
    python3 demo_exam_test.py

说明:
    此脚本会自动完成以下操作:
    1. 检查服务是否运行，未运行则启动开发服务器
    2. 创建管理员账号 (demo-admin / Admin123456)
    3. 创建学生账号 (demo_student)
    4. 创建考试题目 (2 道数据库操作题)
    5. 创建考试场次并启动
    6. 模拟学生参加考试
    7. 执行评分脚本
    8. 提交成绩
    9. 显示测试结果
"""

import sys
import os
import json
import time
import subprocess
import signal
import atexit
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse, unquote

# 添加 client_agent 到路径
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(script_dir, 'client_agent'))

from exam_agent import (
    ExamAPIClient, ScriptExecutor, get_system_info, get_system_username,
    create_session, save_token, load_token
)

# 颜色输出
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'

def log_info(msg):
    print(f"{BLUE}[INFO]{NC}  {msg}")

def log_ok(msg):
    print(f"{GREEN}[OK]{NC}    {msg}")

def log_warn(msg):
    print(f"{YELLOW}[WARN]{NC}  {msg}")

def log_error(msg):
    print(f"{RED}[ERROR]{NC} {msg}")

def log_section(title):
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}  {title}{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

# 全局变量
dev_server_pid = None

def cleanup():
    """清理后台进程"""
    global dev_server_pid
    if dev_server_pid:
        log_info(f"停止开发服务器 (PID: {dev_server_pid})...")
        try:
            os.kill(dev_server_pid, signal.SIGTERM)
            log_ok("开发服务器已停止")
        except:
            pass

atexit.register(cleanup)

def check_service():
    """检查服务是否运行"""
    import requests
    try:
        resp = requests.get("http://localhost:3000/api/trpc/auth.me", timeout=5)
        return resp.status_code in (200, 401)
    except:
        return False

def start_dev_server():
    """启动开发服务器"""
    global dev_server_pid
    
    log_warn("服务未运行，正在启动开发服务器...")
    
    # 后台启动
    dev_server_pid = subprocess.Popen(
        ["pnpm", "dev"],
        cwd=script_dir,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        preexec_fn=os.setpgrp
    ).pid
    
    log_info(f"开发服务器已启动 (PID: {dev_server_pid})")
    
    # 等待服务就绪
    log_info("等待服务启动...")
    for i in range(30):
        time.sleep(1)
        if check_service():
            log_ok("服务已就绪")
            return True
    
    log_error("服务启动失败")
    return False

def create_test_data():
    """创建测试数据并返回考试 ID"""
    log_section("创建测试数据")
    
    # 读取数据库配置
    env_file = os.path.join(script_dir, '.env')
    if not os.path.exists(env_file):
        log_error(".env 文件不存在")
        return None
    
    with open(env_file, 'r', encoding='utf-8') as f:
        env_content = f.read()
    
    import re
    match = re.search(r'^DATABASE_URL=(.+)$', env_content, re.MULTILINE)
    if not match:
        log_error("未找到 DATABASE_URL 配置")
        return None
    
    db_url = match.group(1)
    
    # 解析数据库连接（兼容 URL 编码密码）
    parsed = urlparse(db_url)
    if parsed.scheme != "mysql" or not parsed.hostname or not parsed.username or not parsed.path:
        log_error("无法解析 DATABASE_URL")
        return None
    user = parsed.username
    password = unquote(parsed.password or "")
    host = parsed.hostname
    port = parsed.port or 3306
    database = parsed.path.lstrip("/")
    
    db_cfg = json.dumps({
        "host": host,
        "port": int(port),
        "user": user,
        "password": password,
        "database": database,
    }, ensure_ascii=False)

    # 创建 Node.js 脚本（与当前 schema 保持一致）
    node_script = f'''
const mysql = require('mysql2/promise');
const crypto = require('crypto');
const dbCfg = {db_cfg};

async function createTestData() {{
  let connection;
  try {{
    connection = await mysql.createConnection(dbCfg);
    
    console.log('数据库连接成功');
    
    // 1. 创建管理员
    await connection.execute(`
      INSERT INTO users (openId, name, loginMethod, role, createdAt, lastSignedIn)
      VALUES ('demo-admin', 'Demo Admin', 'local', 'admin', NOW(), NOW())
      ON DUPLICATE KEY UPDATE name='Demo Admin'
    `);
    
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = crypto.createHash('sha256').update(salt + 'Admin123456' + salt).digest('hex');
    const passwordHash = salt + ':' + hash;
    
    await connection.execute(`UPDATE users SET passwordHash = ? WHERE openId = 'demo-admin'`, [passwordHash]);
    
    console.log('✓ 管理员账号创建成功 (demo-admin / Admin123456)');
    
    // 2. 创建学生
    await connection.execute(`
      INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt)
      VALUES ('demo_student', '演示学生', 'Demo Class', 1, NOW(), NOW())
      ON DUPLICATE KEY UPDATE name='演示学生', deviceId=NULL, apiToken=NULL, tokenExpiresAt=NULL, updatedAt=NOW()
    `);
    console.log('✓ 学生账号创建成功 (demo_student)');
    
    // 3. 创建分类
    await connection.execute(`
      INSERT INTO question_categories (name, description)
      VALUES ('DM8 数据库', '达梦数据库操作题目')
      ON DUPLICATE KEY UPDATE description='达梦数据库操作题目'
    `);
    
    const [catRows] = await connection.execute('SELECT id FROM question_categories WHERE name = "DM8 数据库"');
    const categoryId = catRows[0].id;
    
    // 删除旧题目
    await connection.execute('DELETE FROM questions WHERE categoryId = ?', [categoryId]);
    
    // 创建题目 1
    await connection.execute(`
      INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
      VALUES (
        '数据库软件卸载',
        '请完成以下操作：\\\\n1. 停止数据库服务\\\\n2. 卸载数据库软件\\\\n3. 清理数据库进程',
        ?,
        2,
        10,
        1,
        1
      )
    `, [categoryId]);
    
    // 创建题目 2
    await connection.execute(`
      INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
      VALUES (
        '数据库软件安装',
        '请完成以下操作：\\\\n1. 安装数据库软件\\\\n2. 创建 dmdba 用户\\\\n3. 注册数据库服务',
        ?,
        2,
        10,
        1,
        2
      )
    `, [categoryId]);
    
    console.log('✓ 考试题目创建成功 (2 道题目)');
    
    // 4. 创建考试场次
    await connection.execute('DELETE FROM exam_sessions WHERE name = "DM8 数据库操作考试"');
    await connection.execute(`
      INSERT INTO exam_sessions (name, description, durationMinutes, questionCount, status, categoryFilter, createdAt)
      VALUES (
        'DM8 数据库操作考试',
        '达梦数据库安装与配置实操考试',
        60,
        2,
        'active',
        CAST(? AS JSON),
        NOW()
      )
    `, [JSON.stringify([categoryId])]);
    
    const [examRows] = await connection.execute('SELECT id FROM exam_sessions WHERE name = "DM8 数据库操作考试" ORDER BY id DESC LIMIT 1');
    const examId = examRows[0].id;
    console.log(`✓ 考试场次创建成功 (ID: ${{examId}})`);
    
    console.log('');
    console.log('测试数据创建完成！');
    console.log('========================================');
    console.log('  管理员账号：demo-admin / Admin123456');
    console.log('  学生账号：demo_student');
    console.log(`  考试 ID: ${{examId}}`);
    console.log('========================================');
    
    await connection.end();
    return true;
  }} catch (error) {{
    console.error('创建测试数据失败:', error);
    if (connection) await connection.end();
    return false;
  }}
}}

createTestData().then(() => process.exit(0)).catch(() => process.exit(1));
'''
    
    # 执行 Node.js 脚本
    result = subprocess.run(
        ["node", "-e", node_script],
        cwd=script_dir,
        capture_output=True,
        text=True
    )
    
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    
    if result.returncode != 0:
        return None

    exam_id_match = None
    for line in result.stdout.splitlines():
        if "考试 ID:" in line:
            try:
                exam_id_match = int(line.split("考试 ID:")[1].strip())
            except Exception:
                pass
    return exam_id_match

def run_demo_exam(exam_id: int):
    """运行演示考试（自动评分模式）"""
    log_section("运行演示考试（自动评分）")

    server_url = "http://localhost:3000"
    print("\n[演示] 开始考试流程测试（自动模式）\n")

    # 1. 获取系统信息
    sys_info = get_system_info()
    username = sys_info["username"]
    device_id = sys_info["device_id"]

    print(f"  当前用户：{username}")
    print(f"  设备 ID: {device_id[:16]}...")

    # 2. 清除旧 token
    token_file = os.path.expanduser("~/.exam_agent/token.json")
    if os.path.exists(token_file):
        os.remove(token_file)
        log_info("已清除旧 token")

    # 3. 认证（使用 demo_student 账号）
    student_id = "demo_student"
    print("\n[演示] 正在认证...")
    print(f"  学生 ID: {student_id}")
    api = ExamAPIClient(server_url)

    try:
        result = api.authenticate(student_id, device_id, username)
        token_data = result.get("json", result)
        if token_data.get("token"):
            log_ok("认证成功")
        else:
            log_error(f"认证失败：{result}")
            return False, None
    except Exception as e:
        log_error(f"认证异常：{e}")
        return False, None

    # 4. 获取考试题目
    print(f"\n[演示] 获取考试题目 (examId={exam_id})...")
    try:
        questions_raw = api._call("agentApi.fetchQuestions", {
            "token": api.token,
            "examId": exam_id
        }, method="POST")
        # tRPC superjson wraps result under 'json' key
        questions_data = questions_raw.get("json", questions_raw)
        questions = questions_data.get("questions", [])
        log_ok(f"获取到 {len(questions)} 道题目")

        for i, q in enumerate(questions, 1):
            print(f"    题目 {i}: {q.get('title', 'Unknown')} ({q.get('maxScore', 0)}分)")

    except Exception as e:
        log_error(f"获取题目失败：{e}")
        print(f"  提示：请确保考试场次已创建并处于 active 状态")
        return False, None

    # 5. 开始考试
    print(f"\n[演示] 开始考试...")
    try:
        record_raw = api._call("agentApi.startExam", {
            "token": api.token,
            "examId": exam_id
        }, method="POST")
        record = record_raw.get("json", record_raw)
        record_id = record.get("recordId")
        log_ok(f"考试记录已创建 (recordId={record_id})")
    except Exception as e:
        log_error(f"开始考试失败：{e}")
        return False, None

    # 6. 执行评分（自动模式，一次执行整套 score.sh）
    print(f"\n[演示] 执行自动评分...")
    executor = ScriptExecutor(timeout=60)
    script = questions[0].get("scoringScript")
    if not script:
        log_warn("题目缺少 scoringScript，跳过评分步骤")
        script = ""

    result = executor.execute_script(script, username)
    question_scores = result.get("questionScores", {}) or {}

    all_results = []
    total_score = 0
    total_max = 0
    for i, q in enumerate(questions, 1):
        q_score = int(question_scores.get(i, 0))
        q_max = int(q.get("maxScore", 10))
        total_score += q_score
        total_max += q_max
        all_results.append({
            "questionId": q.get("questionId"),
            "questionTitle": q.get("personalizedContent", "")[:40],
            "score": q_score,
            "maxScore": q_max,
            "details": result.get("details", []),
        })
        print(f"    题目 {i} 得分：{q_score} / {q_max}")

    print(f"\n[演示] 评分完成！总分：{total_score} / {total_max}")

    # 7. 提交成绩
    print(f"\n[演示] 提交成绩...")
    try:
        submit_data = {
            "token": api.token,
            "examId": exam_id,
            "totalScore": total_score,
            "durationSeconds": 60,
            "scriptOutput": json.dumps({
                "summary": {
                    "totalScore": total_score,
                    "maxPossibleScore": total_max,
                },
                "questionResults": all_results,
                "rawOutput": result.get("rawOutput", ""),
            }, ensure_ascii=False),
            "examMeta": {
                "examStartedAt": datetime.now().isoformat(),
                "examCompletedAt": datetime.now().isoformat(),
                "clientStartedAt": datetime.now().isoformat(),
                "hostname": sys_info.get("hostname"),
                "os": sys_info.get("os"),
                "osVersion": sys_info.get("os_version"),
                "arch": sys_info.get("arch"),
                "deviceId": sys_info.get("device_id"),
                "username": username,
                "questionSet": questions[0].get("questionSet"),
                "questionCount": len(questions),
            },
            "details": [{
                "questionId": q.get("questionId"),
                "earnedScore": q.get("score", 0),
                "maxScore": q.get("maxScore", 10),
                "failedChecks": []
            } for q in all_results]
        }

        result = api._call("agentApi.submitScore", submit_data, method="POST")
        log_ok("成绩已提交")
    except Exception as e:
        log_error(f"提交成绩失败：{e}")
        return False, None

    # 8. 结束考试
    print(f"\n[演示] 结束考试...")
    try:
        result = api._call("agentApi.finishExam", {
            "token": api.token,
            "recordId": record_id
        }, method="POST")
        log_ok("考试已结束")
    except Exception as e:
        log_warn(f"结束考试失败：{e}")

    print(f"\n{'='*60}")
    print(f"  考试完成！")
    print(f"  最终得分：{total_score} / {total_max}")
    print(f"  考试记录 ID: {record_id}")
    print(f"{'='*60}")

    report = {
        "timestamp": datetime.now().isoformat(),
        "server": server_url,
        "examId": exam_id,
        "recordId": record_id,
        "questionCount": len(questions),
        "score": {
            "total": total_score,
            "max": total_max,
        },
        "questionSet": questions[0].get("questionSet") if questions else None,
        "status": "success",
    }
    return True, report

def main():
    """主函数"""
    log_section("Linux 考试系统 - 演示考试测试")
    
    print("本测试将模拟完整的考试流程：")
    print("  1. 检查/启动服务")
    print("  2. 创建管理员账号")
    print("  3. 创建学生账号")
    print("  4. 创建考试题目")
    print("  5. 创建考试场次")
    print("  6. 学生端参加考试")
    print("  7. 提交成绩")
    print("  8. 查看成绩报表")
    print()
    
    # 1. 检查服务
    log_info("检查服务状态...")
    if not check_service():
        if not start_dev_server():
            return 1
    else:
        log_ok("服务已运行")
    
    # 2. 创建测试数据
    exam_id = create_test_data()
    if not exam_id:
        return 1
    
    # 3. 运行演示考试
    ok, report = run_demo_exam(exam_id)
    if not ok:
        return 1

    report_dir = Path(script_dir) / "test-reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / f"demo_exam_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    # 4. 显示结果
    log_section("测试完成")
    
    print()
    print("访问管理后台查看成绩：")
    print(f"  {CYAN}http://localhost:3000{NC}")
    print()
    print("管理员账号：demo-admin / Admin123456")
    print()
    print("查看成绩报表：")
    print("  1. 登录管理后台")
    print("  2. 进入'考试管理'页面")
    print("  3. 查看'DM8 数据库操作考试'的成绩")
    print()
    print(f"测试报告：{report_file}")
    print()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
