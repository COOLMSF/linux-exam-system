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
    """创建测试数据"""
    log_section("创建测试数据")
    
    # 读取数据库配置
    env_file = os.path.join(script_dir, '.env')
    if not os.path.exists(env_file):
        log_error(".env 文件不存在")
        return False
    
    with open(env_file, 'r', encoding='utf-8') as f:
        env_content = f.read()
    
    import re
    match = re.search(r'^DATABASE_URL=(.+)$', env_content, re.MULTILINE)
    if not match:
        log_error("未找到 DATABASE_URL 配置")
        return False
    
    db_url = match.group(1)
    
    # 解析数据库连接
    db_match = re.match(r'mysql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)', db_url)
    if not db_match:
        log_error("无法解析 DATABASE_URL")
        return False
    
    user, password, host, port, database = db_match.groups()
    
    # 创建 Node.js 脚本
    node_script = f'''
const mysql = require('mysql2/promise');
const crypto = require('crypto');

async function createTestData() {{
  let connection;
  try {{
    connection = await mysql.createConnection({{
      host: '{host}',
      port: {port},
      user: '{user}',
      password: '{password}',
      database: '{database}'
    }});
    
    console.log('数据库连接成功');
    
    // 1. 创建管理员
    await connection.execute(`
      INSERT INTO users (open_id, name, login_method, role, created_at, last_signed_in)
      VALUES ('demo-admin', 'Demo Admin', 'local', 'admin', NOW(), NOW())
      ON DUPLICATE KEY UPDATE name='Demo Admin'
    `);
    
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = crypto.createHash('sha256').update(salt + 'Admin123456' + salt).digest('hex');
    const passwordHash = salt + ':' + hash;
    
    await connection.execute(`
      INSERT INTO user_passwords (user_id, password_hash)
      SELECT id, ? FROM users WHERE open_id = 'demo-admin'
      ON DUPLICATE KEY UPDATE password_hash = ?
    `, [passwordHash, passwordHash]);
    
    console.log('✓ 管理员账号创建成功 (demo-admin / Admin123456)');
    
    // 2. 创建学生
    await connection.execute(`
      INSERT INTO students (student_id, name, class_name, is_active, created_at, updated_at)
      VALUES ('demo_student', '演示学生', 'Demo Class', 1, NOW(), NOW())
      ON DUPLICATE KEY UPDATE name='演示学生'
    `);
    console.log('✓ 学生账号创建成功 (demo_student)');
    
    // 3. 创建分类
    await connection.execute(`
      INSERT INTO categories (name, description)
      VALUES ('DM8 数据库', '达梦数据库操作题目')
      ON DUPLICATE KEY UPDATE description='达梦数据库操作题目'
    `);
    
    const [catRows] = await connection.execute('SELECT id FROM categories WHERE name = "DM8 数据库"');
    const categoryId = catRows[0].id;
    
    // 删除旧题目
    await connection.execute('DELETE FROM questions WHERE category_id = ?', [categoryId]);
    
    // 创建题目 1
    await connection.execute(`
      INSERT INTO questions (title, content, category_id, difficulty, max_score, scoring_script, is_active, sort_order)
      VALUES (
        '数据库软件卸载',
        '请完成以下操作：\\\\n1. 停止数据库服务\\\\n2. 卸载数据库软件\\\\n3. 清理数据库进程',
        ?,
        2,
        10,
        '#!/bin/bash\\\\nscore=10\\\\nif [ -d "/home/dmdba/dmdbms/jar" ]; then\\\\n  score=$((score - 4))\\\\n  echo "数据库软件目录仍存在:-4"\\\\nfi\\\\necho "总分：$score"',
        1,
        1
      )
    `, [categoryId]);
    
    // 创建题目 2
    await connection.execute(`
      INSERT INTO questions (title, content, category_id, difficulty, max_score, scoring_script, is_active, sort_order)
      VALUES (
        '数据库软件安装',
        '请完成以下操作：\\\\n1. 安装数据库软件\\\\n2. 创建 dmdba 用户\\\\n3. 注册数据库服务',
        ?,
        2,
        10,
        '#!/bin/bash\\\\nscore=10\\\\nif [ ! -f "/home/dmdba/dmdbms/bin/dmserver" ]; then\\\\n  score=$((score - 5))\\\\n  echo "数据库未安装:-5"\\\\nfi\\\\necho "总分：$score"',
        1,
        2
      )
    `, [categoryId]);
    
    console.log('✓ 考试题目创建成功 (2 道题目)');
    
    // 4. 创建考试场次
    await connection.execute(`
      INSERT INTO exam_sessions (name, description, duration_minutes, question_count, status, category_filter, created_at)
      VALUES (
        'DM8 数据库操作考试',
        '达梦数据库安装与配置实操考试',
        60,
        2,
        'active',
        ?,
        NOW()
      )
    `, [categoryId]);
    
    const [examRows] = await connection.execute('SELECT id FROM exam_sessions WHERE name = "DM8 数据库操作考试"');
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

createTestData();
process.exit(0);
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
    
    return result.returncode == 0

def run_demo_exam():
    """运行演示考试（自动评分模式）"""
    log_section("运行演示考试（自动评分）")

    server_url = "http://localhost:3000"
    exam_id = 1

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

    # 3. 认证
    print("\n[演示] 正在认证...")
    api = ExamAPIClient(server_url)

    try:
        result = api.authenticate(username, device_id, username)
        token_data = result.get("json", result)
        if token_data.get("token"):
            log_ok("认证成功")
        else:
            log_error(f"认证失败：{result}")
            return False
    except Exception as e:
        log_error(f"认证异常：{e}")
        return False

    # 4. 获取考试题目
    print(f"\n[演示] 获取考试题目 (examId={exam_id})...")
    try:
        questions_data = api._call("agentApi.fetchQuestions", {
            "token": api.token,
            "examId": exam_id
        }, method="POST")

        questions = questions_data.get("questions", [])
        log_ok(f"获取到 {len(questions)} 道题目")

        for i, q in enumerate(questions, 1):
            print(f"    题目 {i}: {q.get('title', 'Unknown')} ({q.get('maxScore', 0)}分)")

    except Exception as e:
        log_error(f"获取题目失败：{e}")
        print(f"  提示：请确保考试场次已创建并处于 active 状态")
        return False

    # 5. 开始考试
    print(f"\n[演示] 开始考试...")
    try:
        record = api._call("agentApi.startExam", {
            "examId": exam_id
        }, method="POST")
        record_id = record.get("recordId")
        log_ok(f"考试记录已创建 (recordId={record_id})")
    except Exception as e:
        log_error(f"开始考试失败：{e}")
        return False

    # 6. 执行评分（自动模式）
    print(f"\n[演示] 执行自动评分...")
    executor = ScriptExecutor(timeout=60)
    all_results = []
    total_score = 0
    total_max = 0

    for i, q in enumerate(questions, 1):
        script = q.get("scoringScript")
        if not script:
            print(f"  题目 {i}: 无评分脚本，跳过")
            continue

        print(f"  评分题目 {i}: {q.get('title')}...")
        result = executor.execute_script(script, username)

        q_score = result.get("totalScore", 0)
        q_max = q.get("maxScore", 10)
        total_score += q_score
        total_max += q_max

        all_results.append({
            "questionId": q.get("id"),
            "questionTitle": q.get("title"),
            "score": q_score,
            "maxScore": q_max,
            "details": result.get("details", []),
        })

        print(f"    得分：{q_score} / {q_max}")

    print(f"\n[演示] 评分完成！总分：{total_score} / {total_max}")

    # 7. 提交成绩
    print(f"\n[演示] 提交成绩...")
    try:
        submit_data = {
            "token": api.token,
            "examId": exam_id,
            "totalScore": total_score,
            "durationSeconds": 60,
            "scriptOutput": json.dumps(all_results, ensure_ascii=False),
            "details": [{
                "questionId": q.get("id"),
                "earnedScore": q.get("totalScore", 0),
                "maxScore": q.get("maxScore", 10),
                "failedChecks": []
            } for q in all_results]
        }

        result = api._call("agentApi.submitScore", submit_data, method="POST")
        log_ok("成绩已提交")
    except Exception as e:
        log_error(f"提交成绩失败：{e}")
        return False

    # 8. 结束考试
    print(f"\n[演示] 结束考试...")
    try:
        result = api._call("agentApi.finishExam", {
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

    return True

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
    if not create_test_data():
        return 1
    
    # 3. 运行演示考试
    if not run_demo_exam():
        return 1
    
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
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
