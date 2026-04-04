#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Linux 考试系统 — 完整端到端演示测试
#  内容：从建库数据 → 客户端认证 → 学生答题 → 评分脚本运行 → 提交成绩 → 结果核验
#  全程暴露：API 请求/响应 JSON、评分脚本输出、最终成绩单
#  用法: bash exam_e2e_demo.sh
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── 颜色定义 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── 配置 ──────────────────────────────────────────────────────────────────────
SERVER_URL="http://localhost:3000"
ENV_FILE="/opt/linux-exam-system/.env"
[[ ! -f "$ENV_FILE" ]] && ENV_FILE="$(dirname "$0")/.env"

STUDENT_ID="e2e_demo_student"
STUDENT_NAME="演示学生"
DEVICE_ID="e2e-demo-device-$(hostname | md5sum | cut -c1-8)"
CLIENT_USER="$(whoami)"
WORKDIR="/tmp/examdemo_${CLIENT_USER}"

TMPDIR_SCRIPT="$(mktemp -d)"
SCORE_SCRIPT="$TMPDIR_SCRIPT/scoring.sh"
trap "rm -rf '$TMPDIR_SCRIPT'" EXIT

# ── 工具函数 ──────────────────────────────────────────────────────────────────
banner() {
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════${NC}"
}

step() { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${DIM}·${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }

show_req() {
    echo -e "\n  ${DIM}┌── 请求 ────────────────────────────────────${NC}"
    echo -e "  ${DIM}│${NC} ${MAGENTA}POST${NC} $1"
    echo "$2" | python3 -c "import sys,json; print('\n'.join('  │ '+l for l in json.dumps(json.loads(sys.stdin.read()),ensure_ascii=False,indent=2).splitlines()))" 2>/dev/null || true
    echo -e "  ${DIM}└────────────────────────────────────────────${NC}"
}

show_resp() {
    echo -e "  ${DIM}┌── 响应 ────────────────────────────────────${NC}"
    echo "$1" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); r=d.get('result',{}).get('data',{}); print('\n'.join('  │ '+l for l in json.dumps(r,ensure_ascii=False,indent=2).splitlines()))" 2>/dev/null || \
        echo "$1" | sed 's/^/  │ /'
    echo -e "  ${DIM}└────────────────────────────────────────────${NC}"
}

# ── 读取数据库配置 ─────────────────────────────────────────────────────────────
read_db() {
    local url; url=$(grep '^DATABASE_URL=' "$ENV_FILE" | cut -d= -f2-)
    DB_USER=$(echo "$url" | sed 's|mysql://\([^:]*\):.*|\1|')
    DB_PASS=$(python3 -c "from urllib.parse import unquote; print(unquote('$(echo "$url" | sed "s|mysql://[^:]*:\([^@]*\)@.*|\1|")'))")
    DB_HOST=$(echo "$url" | sed 's|.*@\([^:]*\):.*|\1|')
    DB_PORT=$(echo "$url" | sed 's|.*:\([0-9]*\)/.*|\1|')
    DB_NAME=$(echo "$url" | sed 's|.*/\(.*\)|\1|')
}

mysql_q() {
    MYSQL_PWD="$DB_PASS" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" \
        --batch --column-names "$DB_NAME" -e "$1" 2>/dev/null
}

mysql_exec() {
    MYSQL_PWD="$DB_PASS" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" \
        --batch "$DB_NAME" -e "$1" 2>/dev/null
}

mysql_val() {
    mysql_q "$1" | tail -1
}

# ── tRPC API 调用 ──────────────────────────────────────────────────────────────
api_post() {
    local proc="$1" body="$2"
    curl -s -X POST "${SERVER_URL}/api/trpc/${proc}" \
        -H "Content-Type: application/json" \
        -d "$body" \
        --max-time 15
}

extract() {
    # 从 tRPC 响应提取 .result.data.json.<field>
    echo "$1" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
r = d.get('result',{}).get('data',{})
val = r.get('json', r)
parts = '$2'.split('.')
for p in parts:
    if isinstance(val, dict): val = val.get(p)
    else: val = None
print('' if val is None else str(val))
" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════════════
banner "Linux 考试系统 — 完整端到端演示测试"
echo -e "  服务器: ${SERVER_URL}"
echo -e "  学生:   ${STUDENT_NAME} (${STUDENT_ID})"
echo -e "  设备:   ${DEVICE_ID}"
echo -e "  用户:   ${CLIENT_USER}"
echo -e "  工作区: ${WORKDIR}"
# ══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 1 ：环境检查"
# ─────────────────────────────────────────────────────────────────────────────

step "检查服务端"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${SERVER_URL}/api/trpc/auth.me" --max-time 5 || echo "000")
if [[ "$HTTP_STATUS" =~ ^[0-9]+$ ]] && [[ "$HTTP_STATUS" -ge 200 ]]; then
    ok "服务端响应正常 (HTTP $HTTP_STATUS)"
else
    fail "服务端无响应，请先启动服务"
    exit 1
fi

step "读取数据库配置"
read_db
ok "数据库: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
TEST=$(mysql_val "SELECT 'OK' AS t" 2>/dev/null || echo "")
if [[ "$TEST" == "OK" ]]; then
    ok "数据库连接正常"
else
    fail "数据库连接失败"
    exit 1
fi

step "检查评分脚本"
if [[ -f "/opt/linux-exam-system/score_a.sh" ]]; then
    ok "score_a.sh 已就绪 ($(wc -l < /opt/linux-exam-system/score_a.sh) 行)"
else
    fail "缺少 /opt/linux-exam-system/score_a.sh，请先运行安装脚本"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 2 ：从头建立测试数据"
# ─────────────────────────────────────────────────────────────────────────────

step "清理旧测试数据"
mysql_exec "
DELETE er FROM exam_records er
  JOIN students s ON s.id=er.studentId AND s.studentId='${STUDENT_ID}';
DELETE eqa FROM exam_question_assignments eqa
  JOIN students s ON s.id=eqa.studentId AND s.studentId='${STUDENT_ID}';
DELETE FROM exam_sessions WHERE name='E2E演示考试';
DELETE FROM questions WHERE title LIKE '[E2E]%';
DELETE FROM question_categories WHERE name='E2E演示分类';
DELETE FROM students WHERE studentId='${STUDENT_ID}';
"
ok "旧数据已清理"

step "创建学生账号"
mysql_exec "
INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt)
VALUES ('${STUDENT_ID}', '${STUDENT_NAME}', '演示班', 1, NOW(), NOW());
"
STUDENT_DB_ID=$(mysql_val "SELECT id FROM students WHERE studentId='${STUDENT_ID}'")
ok "学生创建成功 → id=${STUDENT_DB_ID}, 姓名=${STUDENT_NAME}"

step "创建题目分类"
mysql_exec "INSERT INTO question_categories (name, description) VALUES ('E2E演示分类', 'E2E自动化测试专用')"
CAT_ID=$(mysql_val "SELECT id FROM question_categories WHERE name='E2E演示分类' ORDER BY id DESC LIMIT 1")
ok "分类创建成功 → id=${CAT_ID}"

step "创建3道题目"
# 题目1
mysql_exec "INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
VALUES ('[E2E]题1：创建工作目录',
'在 /tmp/examdemo_\${USER}/ 目录下创建文件 answer.txt，内容首行必须包含 EXAM_READY。\n\n提示：\n  mkdir -p /tmp/examdemo_\${USER}\n  echo EXAM_READY > /tmp/examdemo_\${USER}/answer.txt',
${CAT_ID}, 1, 30, 1, 1)"
Q1_ID=$(mysql_val "SELECT id FROM questions WHERE title='[E2E]题1：创建工作目录'")

# 题目2
mysql_exec "INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
VALUES ('[E2E]题2：创建可执行脚本',
'在 /tmp/examdemo_\${USER}/scripts/ 下创建 run.sh，并赋予执行权限。\n\n提示：\n  mkdir -p /tmp/examdemo_\${USER}/scripts\n  echo \"#!/bin/bash\" > /tmp/examdemo_\${USER}/scripts/run.sh\n  chmod +x /tmp/examdemo_\${USER}/scripts/run.sh',
${CAT_ID}, 2, 40, 1, 2)"
Q2_ID=$(mysql_val "SELECT id FROM questions WHERE title='[E2E]题2：创建可执行脚本'")

# 题目3
mysql_exec "INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
VALUES ('[E2E]题3：创建配置文件',
'在 /tmp/examdemo_\${USER}/ 下创建 config.txt，包含两行：\n  host=localhost\n  port=8080\n\n提示：\n  printf \"host=localhost\\nport=8080\\n\" > /tmp/examdemo_\${USER}/config.txt',
${CAT_ID}, 2, 30, 1, 3)"
Q3_ID=$(mysql_val "SELECT id FROM questions WHERE title='[E2E]题3：创建配置文件'")

echo ""
echo -e "  ${BOLD}题目清单：${NC}"
mysql_q "SELECT id, title, maxScore FROM questions WHERE categoryId=${CAT_ID}" | \
    while IFS=$'\t' read -r id title score; do
        [[ "$id" == "id" ]] && continue
        echo -e "  │ ID=${id}  满分=${score}  ${title}"
    done

step "创建考试场次（状态：active）"
mysql_exec "INSERT INTO exam_sessions
  (name, description, durationMinutes, questionCount, status, categoryFilter, createdAt)
  VALUES ('E2E演示考试', '端到端自动化演示', 60, 3, 'active', '[${CAT_ID}]', NOW())"
EXAM_ID=$(mysql_val "SELECT id FROM exam_sessions WHERE name='E2E演示考试' ORDER BY id DESC LIMIT 1")
ok "考试场次创建成功 → id=${EXAM_ID}, 题数=3, 时长=60分钟"

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 3 ：客户端认证"
# ─────────────────────────────────────────────────────────────────────────────

step "调用 agentApi.authenticate"
REQ_AUTH=$(cat <<JSON
{"json":{"studentId":"${STUDENT_ID}","deviceId":"${DEVICE_ID}","clientUsername":"${CLIENT_USER}"}}
JSON
)
show_req "agentApi.authenticate" "$REQ_AUTH"

RESP_AUTH=$(api_post "agentApi.authenticate" "$REQ_AUTH")
show_resp "$RESP_AUTH"

AGENT_TOKEN=$(extract "$RESP_AUTH" "token")
STUDENT_NAME_RESP=$(extract "$RESP_AUTH" "name")

if [[ -z "$AGENT_TOKEN" ]]; then
    fail "认证失败，未获取 token"
    echo "$RESP_AUTH"
    exit 1
fi
ok "认证成功"
ok "Token: ${AGENT_TOKEN:0:20}… (共 ${#AGENT_TOKEN} 字符)"
ok "欢迎: ${STUDENT_NAME_RESP}"

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 4 ：获取题目（服务端下发评分脚本）"
# ─────────────────────────────────────────────────────────────────────────────

step "调用 agentApi.fetchQuestions"
REQ_FQ=$(cat <<JSON
{"json":{"token":"${AGENT_TOKEN}","examId":${EXAM_ID}}}
JSON
)
show_req "agentApi.fetchQuestions" "$REQ_FQ"

RESP_FQ=$(api_post "agentApi.fetchQuestions" "$REQ_FQ")

# 提取并显示（不打印评分脚本，太长）
RESP_FQ_BRIEF=$(echo "$RESP_FQ" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
r = d.get('result',{}).get('data',{})
q = r.get('json', r)
brief = {
    'examName': q.get('examName'),
    'durationMinutes': q.get('durationMinutes'),
    'questionCount': len(q.get('questions', [])),
    'questions': [{'id': x.get('id'), 'questionId': x.get('questionId'),
                   'maxScore': x.get('maxScore'), 'sortOrder': x.get('sortOrder'),
                   'title': (x.get('personalizedContent','')[:40]+'…') if x.get('personalizedContent') else ''
                   } for x in q.get('questions', [])],
    'scoringScriptSize': len(q.get('questions',[{}])[0].get('scoringScript','')) if q.get('questions') else 0,
}
print(json.dumps(brief, ensure_ascii=False, indent=2))
" 2>/dev/null || echo "$RESP_FQ")
show_resp "{\"result\":{\"data\":${RESP_FQ_BRIEF}}}"

# 提取评分脚本并保存
echo "$RESP_FQ" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
r = d.get('result',{}).get('data',{})
q = r.get('json', r)
qs = q.get('questions', [])
script = qs[0].get('scoringScript', '') if qs else ''
print(script)
" > "$SCORE_SCRIPT" 2>/dev/null
chmod +x "$SCORE_SCRIPT"

# 提取分配到的 questionIds（服务端真实 ID）
ASSIGNED_QS=$(echo "$RESP_FQ" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
r = d.get('result',{}).get('data',{})
q = r.get('json', r)
for x in q.get('questions', []):
    print(x.get('questionId',''), x.get('maxScore',0), x.get('sortOrder',0))
" 2>/dev/null)

ok "收到评分脚本 ($(wc -l < "$SCORE_SCRIPT") 行)"

echo ""
echo -e "${BOLD}  ── 题目内容展示 ──────────────────────────────────${NC}"
echo "$RESP_FQ" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
r = d.get('result',{}).get('data',{})
q = r.get('json', r)
for i, x in enumerate(q.get('questions', []), 1):
    content = x.get('personalizedContent', '')
    print(f'  [{i}] questionId={x.get(\"questionId\")}  maxScore={x.get(\"maxScore\")}')
    for line in content.splitlines()[:6]:
        print(f'      {line}')
    print()
" 2>/dev/null || true

step "调用 agentApi.startExam"
REQ_SE=$(cat <<JSON
{"json":{"token":"${AGENT_TOKEN}","examId":${EXAM_ID}}}
JSON
)
show_req "agentApi.startExam" "$REQ_SE"

RESP_SE=$(api_post "agentApi.startExam" "$REQ_SE")
show_resp "$RESP_SE"
RECORD_ID=$(extract "$RESP_SE" "recordId")
ok "考试已开始 → recordId=${RECORD_ID}"

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 5 ：学生答题（执行 Linux 操作）"
# ─────────────────────────────────────────────────────────────────────────────

echo -e "  ${DIM}工作目录: ${WORKDIR}${NC}"
echo ""

step "清理旧答题目录（模拟新考试）"
rm -rf "$WORKDIR"
ok "已清理 $WORKDIR"

step "【第1题】创建工作目录和 answer.txt"
echo -e "  ${DIM}执行命令：${NC}"
echo -e "  ${YELLOW}  \$ mkdir -p ${WORKDIR}${NC}"
mkdir -p "$WORKDIR"
echo -e "  ${YELLOW}  \$ echo 'EXAM_READY - 考试系统演示' > ${WORKDIR}/answer.txt${NC}"
echo "EXAM_READY - 考试系统演示" > "${WORKDIR}/answer.txt"
echo -e "  ${DIM}  文件内容：$(cat "${WORKDIR}/answer.txt")${NC}"
ok "第1题操作完成"

step "【第2题】创建 scripts/run.sh 并赋权"
echo -e "  ${YELLOW}  \$ mkdir -p ${WORKDIR}/scripts${NC}"
mkdir -p "${WORKDIR}/scripts"
echo -e "  ${YELLOW}  \$ echo '#!/bin/bash' > ${WORKDIR}/scripts/run.sh${NC}"
cat > "${WORKDIR}/scripts/run.sh" <<'RUNSH'
#!/bin/bash
echo "考试系统 run.sh 执行成功"
RUNSH
echo -e "  ${YELLOW}  \$ chmod +x ${WORKDIR}/scripts/run.sh${NC}"
chmod +x "${WORKDIR}/scripts/run.sh"
echo -e "  ${DIM}  权限：$(ls -la "${WORKDIR}/scripts/run.sh" | awk '{print $1,$9}')${NC}"
ok "第2题操作完成"

step "【第3题】创建 config.txt"
echo -e "  ${YELLOW}  \$ printf 'host=localhost\\nport=8080\\n' > ${WORKDIR}/config.txt${NC}"
printf "host=localhost\nport=8080\n" > "${WORKDIR}/config.txt"
echo -e "  ${DIM}  文件内容：${NC}"
cat "${WORKDIR}/config.txt" | sed 's/^/      /'
ok "第3题操作完成"

echo ""
echo -e "  ${BOLD}答题后目录结构：${NC}"
find "$WORKDIR" | sed 's|'"$WORKDIR"'|.|' | sort | sed 's/^/  │ /'

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 6 ：运行评分脚本（服务端下发的脚本在本机执行）"
# ─────────────────────────────────────────────────────────────────────────────

step "评分脚本路径: $SCORE_SCRIPT"
echo -e "\n  ${BOLD}── 评分脚本内容（前30行）─────────────────────${NC}"
head -30 "$SCORE_SCRIPT" | nl -ba | sed 's/^/  │ /'
echo -e "  ${DIM}  ... (共 $(wc -l < "$SCORE_SCRIPT") 行)${NC}"

echo ""
step "执行评分脚本..."
echo -e "${BOLD}${YELLOW}─────────────── 评分脚本输出 ───────────────────${NC}"
SCORE_OUTPUT=$(bash "$SCORE_SCRIPT" 2>&1 || true)
echo "$SCORE_OUTPUT" | sed 's/^/  /'
echo -e "${BOLD}${YELLOW}───────────────────────────────────────────────${NC}"

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 7 ：解析评分结果"
# ─────────────────────────────────────────────────────────────────────────────

step "解析评分脚本输出中的 Q1/Q2/Q3 得分"

Q1_SCORE=$(echo "$SCORE_OUTPUT" | grep -oP '第1题得分: \K[0-9]+' | head -1 || echo "0")
Q2_SCORE=$(echo "$SCORE_OUTPUT" | grep -oP '第2题得分: \K[0-9]+' | head -1 || echo "0")
Q3_SCORE=$(echo "$SCORE_OUTPUT" | grep -oP '第3题得分: \K[0-9]+' | head -1 || echo "0")
TOTAL_SCORE=$((Q1_SCORE + Q2_SCORE + Q3_SCORE))

info "第1题: ${Q1_SCORE}/30 分"
info "第2题: ${Q2_SCORE}/40 分"
info "第3题: ${Q3_SCORE}/30 分"
ok   "总分:  ${TOTAL_SCORE}/100 分"

# 将得分与服务端下发的 questionId 对应（按 sortOrder）
QIDS=()
while IFS=' ' read -r qid qmax qorder; do
    [[ -z "$qid" ]] && continue
    QIDS+=("$qid:$qmax")
done <<< "$ASSIGNED_QS"

AQS=($ASSIGNED_QS)
Q1_QID=$(echo "$ASSIGNED_QS" | awk 'NR==1{print $1}')
Q2_QID=$(echo "$ASSIGNED_QS" | awk 'NR==2{print $1}')
Q3_QID=$(echo "$ASSIGNED_QS" | awk 'NR==3{print $1}')

info "questionId 映射: 题1→${Q1_QID}, 题2→${Q2_QID}, 题3→${Q3_QID}"

DETAILS_JSON="[
    {\"questionId\":${Q1_QID},\"earnedScore\":${Q1_SCORE},\"maxScore\":30,\"failedChecks\":[]},
    {\"questionId\":${Q2_QID},\"earnedScore\":${Q2_SCORE},\"maxScore\":40,\"failedChecks\":[]},
    {\"questionId\":${Q3_QID},\"earnedScore\":${Q3_SCORE},\"maxScore\":30,\"failedChecks\":[]}
  ]"

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 8 ：提交成绩到服务端"
# ─────────────────────────────────────────────────────────────────────────────

step "调用 agentApi.submitScore"
EXAM_META=$(cat <<JSON
{
  "hostname": "$(hostname)",
  "os": "$(uname -s)",
  "osVersion": "$(uname -r)",
  "arch": "$(uname -m)",
  "username": "${CLIENT_USER}",
  "questionCount": 3,
  "questionSet": "a"
}
JSON
)
EXAM_META_ONE=$(echo "$EXAM_META" | tr -d '\n')

REQ_SS=$(python3 -c "
import json
body = {
    'json': {
        'token': '${AGENT_TOKEN}',
        'examId': ${EXAM_ID},
        'totalScore': ${TOTAL_SCORE},
        'durationSeconds': 60,
        'scriptOutput': '''${SCORE_OUTPUT}''',
        'examMeta': json.loads('''${EXAM_META_ONE}'''),
        'details': ${DETAILS_JSON}
    }
}
print(json.dumps(body, ensure_ascii=False))
" 2>/dev/null)

show_req "agentApi.submitScore" "$REQ_SS"

RESP_SS=$(api_post "agentApi.submitScore" "$REQ_SS")
show_resp "$RESP_SS"

SUCCESS=$(extract "$RESP_SS" "success")
if [[ "$SUCCESS" == "True" ]] || echo "$RESP_SS" | grep -q '"success":true'; then
    ok "成绩提交成功！"
else
    fail "成绩提交异常: $RESP_SS"
fi

step "调用 agentApi.finishExam"
REQ_FE=$(cat <<JSON
{"json":{"token":"${AGENT_TOKEN}","recordId":${RECORD_ID}}}
JSON
)
show_req "agentApi.finishExam" "$REQ_FE"

RESP_FE=$(api_post "agentApi.finishExam" "$REQ_FE")
show_resp "$RESP_FE"
ok "考试已结束"

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 9 ：服务端数据核验"
# ─────────────────────────────────────────────────────────────────────────────

step "从数据库查询考试记录"
echo ""
echo -e "  ${BOLD}── exam_records 记录 ─────────────────────────────${NC}"
mysql_q "
SELECT er.id, er.status, er.totalScore, er.durationSeconds,
       er.submittedAt, er.gradedAt
FROM exam_records er
WHERE er.id = ${RECORD_ID}
" | while IFS=$'\t' read -r id status score dur subat gradat; do
    [[ "$id" == "id" ]] && continue
    echo -e "  │ 记录ID:    $id"
    echo -e "  │ 状态:      $status"
    echo -e "  │ 总分:      $score / 100"
    echo -e "  │ 用时:      ${dur}秒"
    echo -e "  │ 提交时间:  $subat"
    echo -e "  │ 评分时间:  $gradat"
done

echo ""
echo -e "  ${BOLD}── score_details 明细 ────────────────────────────${NC}"
mysql_q "
SELECT sd.questionId, sd.earnedScore, sd.maxScore
FROM score_details sd
WHERE sd.examRecordId = ${RECORD_ID}
ORDER BY sd.questionId
" | while IFS=$'\t' read -r qid earned max; do
    [[ "$qid" == "questionId" ]] && continue
    BAR=""
    PCT=0
    [[ "$max" -gt 0 ]] && PCT=$((earned * 20 / max))
    for ((i=0; i<PCT; i++)); do BAR+="█"; done
    for ((i=PCT; i<20; i++)); do BAR+="░"; done
    echo -e "  │ questionId=${qid}  得分=${earned}/${max}  [${BAR}]"
done

# ─────────────────────────────────────────────────────────────────────────────
banner "阶段 10 ：最终成绩单"
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║              Linux 考试系统 — 成绩单              ║"
echo "  ╠══════════════════════════════════════════════════╣"
printf  "  ║  学生：%-40s║\n" "${STUDENT_NAME}（${CLIENT_USER}）"
printf  "  ║  考试：%-40s║\n" "E2E演示考试"
printf  "  ║  记录：%-40s║\n" "recordId=${RECORD_ID}"
echo "  ╠══════════════════════════════════════════════════╣"
printf  "  ║  第1题（创建工作目录）：%5s / 30 分         ║\n" "${Q1_SCORE}"
printf  "  ║  第2题（创建可执行脚本）：%5s / 40 分       ║\n" "${Q2_SCORE}"
printf  "  ║  第3题（创建配置文件）：%5s / 30 分         ║\n" "${Q3_SCORE}"
echo "  ╠══════════════════════════════════════════════════╣"
printf  "  ║  总  分：%5s / 100 分                        ║\n" "${TOTAL_SCORE}"

if [[ "$TOTAL_SCORE" -ge 90 ]]; then GRADE="优秀 A"
elif [[ "$TOTAL_SCORE" -ge 75 ]]; then GRADE="良好 B"
elif [[ "$TOTAL_SCORE" -ge 60 ]]; then GRADE="通过 C"
else GRADE="不通过 F"
fi
printf  "  ║  等  级：%-42s║\n" "${GRADE}"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "  ${DIM}可在管理后台 ${SERVER_URL} 查看完整报告${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}E2E 演示测试完成 ✓${NC}"
echo ""
