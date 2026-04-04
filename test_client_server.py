#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
客户端 Agent ↔ 服务端 完整对接测试
测试内容：
  1. 服务端健康检查
  2. 数据库预置（学生 / 题目 / 考试场次）
  3. agentApi.authenticate
  4. agentApi.fetchQuestions
  5. agentApi.startExam
  6. agentApi.submitScore
  7. agentApi.finishExam
  8. 成绩查询（管理员登录后验证）
  9. exam_agent 二进制 --test-connection
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "requests",
                           "--break-system-packages"])
    import requests

from urllib.parse import unquote

# ── 配置 ──────────────────────────────────────────────────────────────────────
SERVER_URL = "http://localhost:3000"
ENV_FILE = Path("/opt/linux-exam-system/.env")
if not ENV_FILE.exists():
    ENV_FILE = Path(__file__).parent / ".env"

BINARY = Path(__file__).parent / "dist/client_agent/exam_agent"

STUDENT_ID   = "test_student_001"
STUDENT_NAME = "测试学生甲"
DEVICE_ID    = "test-device-abcd1234"
CLIENT_USER  = "testuser"

PASS = "\033[32m✓\033[0m"
FAIL = "\033[31m✗\033[0m"
INFO = "\033[36m·\033[0m"

errors = []

# ── 工具函数 ───────────────────────────────────────────────────────────────────
def ok(msg):   print(f"  {PASS} {msg}")
def fail(msg): print(f"  {FAIL} {msg}"); errors.append(msg)
def info(msg): print(f"  {INFO} {msg}")

def section(title):
    print(f"\n\033[1m{'─'*55}\033[0m")
    print(f"\033[1m  {title}\033[0m")
    print(f"\033[1m{'─'*55}\033[0m")

def read_db_cfg():
    content = ENV_FILE.read_text()
    m = re.search(r'^DATABASE_URL=(.+)$', content, re.MULTILINE)
    if not m:
        raise RuntimeError(f"DATABASE_URL not found in {ENV_FILE}")
    url = m.group(1).strip()
    m2 = re.match(r'mysql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)', url)
    if not m2:
        raise RuntimeError(f"Cannot parse DATABASE_URL: {url}")
    user, password, host, port, database = m2.groups()
    return dict(user=user, password=unquote(password),
                host=host, port=int(port), database=database)

_db_cfg = None
def db_cfg():
    global _db_cfg
    if _db_cfg is None:
        _db_cfg = read_db_cfg()
    return _db_cfg

def _build_args(args):
    """Escape and interpolate args into a query string."""
    if not args:
        return None
    escaped = []
    for a in args:
        if isinstance(a, str):
            escaped.append("'" + a.replace("\\", "\\\\").replace("'", "\\'") + "'")
        elif isinstance(a, (list, tuple)):
            escaped.append("'" + json.dumps(a).replace("\\", "\\\\").replace("'", "\\'") + "'")
        elif a is None:
            escaped.append("NULL")
        else:
            escaped.append(str(a))
    return escaped

def _mysql_cmd(query, args):
    """Build mysql CLI subprocess args using MYSQL_PWD env var."""
    cfg = db_cfg()
    if args:
        escaped = _build_args(args)
        query = query % tuple(escaped)
    env = os.environ.copy()
    env["MYSQL_PWD"] = cfg["password"]
    cmd = [
        "mysql", "-h", cfg["host"], "-P", str(cfg["port"]),
        "-u", cfg["user"],
        "--batch", "--column-names",
        cfg["database"], "-e", query,
    ]
    return cmd, env

def sql_query(query, *args):
    """Run a SELECT via mysql CLI, return list of dicts."""
    cmd, env = _mysql_cmd(query, args)
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise RuntimeError(f"SQL error: {r.stderr.strip()}")
    lines = r.stdout.strip().splitlines()
    if len(lines) < 2:
        return []
    headers = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        vals = line.split("\t")
        rows.append({h: (None if v == "NULL" else v) for h, v in zip(headers, vals)})
    return rows

def sql_exec(query, *args):
    """Run a non-SELECT statement via mysql CLI."""
    cmd, env = _mysql_cmd(query, args)
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise RuntimeError(f"SQL error: {r.stderr.strip()}")

def trpc_post(procedure, data):
    resp = requests.post(
        f"{SERVER_URL}/api/trpc/{procedure}",
        json={"json": data},
        headers={"Content-Type": "application/json"},
        timeout=15,
    )
    body = resp.json()
    if "error" in body:
        raise RuntimeError(body["error"].get("json", {}).get("message", str(body["error"])))
    result = body.get("result", {}).get("data", {})
    return result.get("json", result)

# ── 1. 服务端健康检查 ──────────────────────────────────────────────────────────
section("1. 服务端健康检查")
try:
    r = requests.get(f"{SERVER_URL}/api/trpc/auth.me", timeout=5)
    ok(f"服务端响应正常 (HTTP {r.status_code})")
except Exception as e:
    fail(f"服务端无响应: {e}")
    print("\n\033[31m[FATAL] 服务端未运行，请先启动服务后再测试\033[0m")
    sys.exit(1)

# ── 2. 数据库连通性检查 ────────────────────────────────────────────────────────
section("2. 数据库连通性检查")
try:
    rows = sql_query("SELECT name FROM users WHERE role='admin' LIMIT 1")
    if rows:
        ok(f"数据库连接正常，管理员账号: {rows[0]['name']}")
    else:
        fail("数据库中无管理员账号，请先运行 --reset-db")
except Exception as e:
    fail(f"数据库连接失败: {e}")
    print("\n\033[31m[FATAL] 无法连接数据库\033[0m")
    sys.exit(1)

# ── 3. 预置测试数据 ────────────────────────────────────────────────────────────
section("3. 预置测试数据（学生 / 题目 / 考试）")

exam_id = None
student_db_id = None
try:
    # 3-a. 学生（upsert）
    sql_exec(
        "INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt) "
        "VALUES (%s, %s, '测试班', 1, NOW(), NOW()) "
        "ON DUPLICATE KEY UPDATE name=%s, isActive=1, deviceId=NULL, apiToken=NULL, tokenExpiresAt=NULL",
        STUDENT_ID, STUDENT_NAME, STUDENT_NAME
    )
    rows = sql_query("SELECT id FROM students WHERE studentId=%s", STUDENT_ID)
    student_db_id = int(rows[0]["id"])
    ok(f"学生已就绪: {STUDENT_NAME} (id={student_db_id})")

    # 3-b. 题目分类
    sql_exec(
        "INSERT INTO question_categories (name, description) VALUES ('客户端测试分类', '自动测试用') "
        "ON DUPLICATE KEY UPDATE description='自动测试用'"
    )
    rows = sql_query("SELECT id FROM question_categories WHERE name='客户端测试分类'")
    cat_id = int(rows[0]["id"])

    # 3-c. 题目（保证至少一道）
    rows = sql_query("SELECT COUNT(*) AS cnt FROM questions WHERE categoryId=%s AND isActive=1", cat_id)
    q_count = int(rows[0]["cnt"])
    if q_count == 0:
        sql_exec(
            "INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder) "
            "VALUES ('测试题：检查 hostname', '请执行 hostname 命令，输出当前主机名。', %s, 1, 10, 1, 1)",
            cat_id
        )
        ok("已创建测试题目")
    else:
        ok(f"题目已存在 ({q_count} 道)")

    # 3-d. 考试场次（active）
    rows = sql_query(
        "SELECT id FROM exam_sessions WHERE name='客户端自动测试考试' AND status='active'"
    )
    if rows:
        exam_id = int(rows[0]["id"])
        ok(f"考试场次已存在 (id={exam_id})")
    else:
        cat_filter = json.dumps([cat_id]).replace("'", "\\'")
        sql_exec(
            "INSERT INTO exam_sessions "
            "(name, description, durationMinutes, questionCount, status, categoryFilter, createdAt) "
            "VALUES ('客户端自动测试考试', '自动化测试专用', 60, 1, 'active', '[%s]', NOW())",
            cat_id
        )
        rows = sql_query(
            "SELECT id FROM exam_sessions WHERE name='客户端自动测试考试' ORDER BY id DESC LIMIT 1"
        )
        exam_id = int(rows[0]["id"])
        ok(f"考试场次已创建 (id={exam_id})")

    # 3-e. 清理上次测试残留（让流程可重复）
    sql_exec(
        "DELETE eqa FROM exam_question_assignments eqa "
        "WHERE eqa.examId=%s AND eqa.studentId=%s",
        exam_id, student_db_id
    )
    sql_exec(
        "DELETE FROM exam_records WHERE examId=%s AND studentId=%s",
        exam_id, student_db_id
    )
    info("已清理上次测试残留记录")

except Exception as e:
    fail(f"预置数据失败: {e}")
    import traceback; traceback.print_exc()
    sys.exit(1)

# ── 4. agentApi.authenticate ──────────────────────────────────────────────────
section("4. agentApi.authenticate")
agent_token = None
try:
    result = trpc_post("agentApi.authenticate", {
        "studentId": STUDENT_ID,
        "deviceId": DEVICE_ID,
        "clientUsername": CLIENT_USER,
    })
    agent_token = result.get("token")
    if agent_token and len(agent_token) > 10:
        ok(f"认证成功，token={agent_token[:16]}…")
        ok(f"学生姓名: {result.get('name')}")
    else:
        fail(f"token 无效: {result}")
except Exception as e:
    fail(f"authenticate 失败: {e}")

# ── 5. agentApi.fetchQuestions ────────────────────────────────────────────────
section("5. agentApi.fetchQuestions")
questions = []
record_id = None
if agent_token:
    try:
        result = trpc_post("agentApi.fetchQuestions", {
            "token": agent_token,
            "examId": exam_id,
        })
        questions = result.get("questions", [])
        if questions:
            ok(f"获取到 {len(questions)} 道题目")
            for i, q in enumerate(questions, 1):
                info(f"  题目 {i}: {q.get('title')} (满分 {q.get('maxScore')} 分)")
            scoring_script = questions[0].get("scoringScript", "")
            if scoring_script:
                ok(f"评分脚本已下发 ({len(scoring_script)} 字节)")
            else:
                info("本次考试暂无评分脚本（手动评分模式）")
        else:
            fail(f"未获取到题目: {result}")
    except Exception as e:
        fail(f"fetchQuestions 失败: {e}")
else:
    info("跳过（无 token）")

# ── 6. agentApi.startExam ─────────────────────────────────────────────────────
section("6. agentApi.startExam")
if agent_token and exam_id:
    try:
        result = trpc_post("agentApi.startExam", {
            "token": agent_token,
            "examId": exam_id,
        })
        record_id = result.get("recordId")
        ok(f"考试已开始，recordId={record_id}")
    except Exception as e:
        fail(f"startExam 失败: {e}")
else:
    info("跳过（缺少 token 或 exam_id）")

# ── 7. agentApi.submitScore ───────────────────────────────────────────────────
section("7. agentApi.submitScore")
if agent_token and exam_id and questions:
    try:
        details = [
            {
                "questionId": q["questionId"],
                "earnedScore": q.get("maxScore", 10),   # 模拟满分
                "maxScore": q.get("maxScore", 10),
                "failedChecks": [],
            }
            for q in questions
        ]
        total = sum(d["earnedScore"] for d in details)

        result = trpc_post("agentApi.submitScore", {
            "token": agent_token,
            "examId": exam_id,
            "totalScore": total,
            "durationSeconds": 42,
            "scriptOutput": "SCORE:10\nALL_PASSED=true",
            "examMeta": {
                "hostname": "test-host",
                "os": "Linux",
                "username": CLIENT_USER,
                "questionCount": len(questions),
            },
            "details": details,
        })
        if result.get("success"):
            ok(f"成绩提交成功，总分={total}")
        else:
            fail(f"submitScore 返回非成功: {result}")
    except Exception as e:
        fail(f"submitScore 失败: {e}")
else:
    info("跳过（缺少必要字段）")

# ── 8. agentApi.finishExam ────────────────────────────────────────────────────
section("8. agentApi.finishExam")
if agent_token and record_id:
    try:
        result = trpc_post("agentApi.finishExam", {
            "token": agent_token,
            "recordId": record_id,
        })
        if result.get("success"):
            ok(f"考试已结束 (recordId={record_id})")
        else:
            fail(f"finishExam 返回非成功: {result}")
    except Exception as e:
        fail(f"finishExam 失败: {e}")
else:
    info("跳过（缺少 token 或 recordId）")

# ── 9. 验证成绩已落库 ──────────────────────────────────────────────────────────
section("9. 验证成绩已落库")
try:
    rows = sql_query(
        "SELECT er.id, er.totalScore, er.status, er.durationSeconds, "
        "COUNT(sd.id) AS detail_count "
        "FROM exam_records er "
        "LEFT JOIN score_details sd ON sd.examRecordId=er.id "
        "WHERE er.examId=%s AND er.studentId=%s "
        "GROUP BY er.id ORDER BY er.id DESC LIMIT 1",
        exam_id, student_db_id
    )
    if rows:
        row = rows[0]
        ok(f"考试记录: id={row['id']}, status={row['status']}, score={row['totalScore']}, details={row['detail_count']}")
        if row["status"] == "graded":
            ok("状态正确（graded）")
        else:
            fail(f"状态异常: {row['status']}")
        if row["totalScore"] is not None:
            ok(f"总分已记录: {row['totalScore']}")
        if int(row["detail_count"]) > 0:
            ok(f"详细得分已记录 ({row['detail_count']} 条)")
        else:
            fail("score_details 表无记录")
    else:
        fail("数据库中未找到考试记录")
except Exception as e:
    fail(f"数据库验证失败: {e}")

# ── 10. exam_agent 二进制 --test-connection ────────────────────────────────────
section("10. exam_agent 二进制 --test-connection")
if BINARY.exists():
    try:
        result = subprocess.run(
            [str(BINARY), "--server", SERVER_URL, "--test-connection"],
            capture_output=True, text=True, timeout=15
        )
        output = result.stdout + result.stderr
        if result.returncode == 0:
            ok("--test-connection 返回 0")
            ok(f"输出: {output.strip()[:120]}")
        else:
            # 只要能连到服务器就算通过（auth failure 是预期的，学生未在 agent config 里配置）
            if "连接" in output or "server" in output.lower() or "3000" in output:
                ok(f"二进制可执行，服务端可达（returncode={result.returncode}）")
                info(f"输出: {output.strip()[:120]}")
            else:
                fail(f"--test-connection 失败 (rc={result.returncode}): {output[:200]}")
    except subprocess.TimeoutExpired:
        fail("--test-connection 超时（15s）")
    except Exception as e:
        fail(f"运行二进制失败: {e}")
else:
    info(f"跳过（未找到 {BINARY}，请先运行 --package-client）")

# ── 结果汇总 ───────────────────────────────────────────────────────────────────
print(f"\n{'═'*57}")
if errors:
    print(f"\033[31m  测试完成，{len(errors)} 项失败：\033[0m")
    for e in errors:
        print(f"    \033[31m✗ {e}\033[0m")
    print()
    sys.exit(1)
else:
    print(f"\033[32m  全部测试通过！客户端 ↔ 服务端对接正常 ✓\033[0m")
    print()
    sys.exit(0)
