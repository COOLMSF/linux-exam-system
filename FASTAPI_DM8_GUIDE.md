# 国产化考试系统落地指南（FastAPI + DM8 + MySQL + Agent）

## 1) 数据库设计

- DM8 表结构脚本：`backend_fastapi/sql/dm8_schema.sql`
- MySQL 表结构脚本：`backend_fastapi/sql/mysql_schema.sql`
- 核心表：`exams`、`students`、`agents`、`results`

> 建议：考试核心写入 DM8，MySQL 用于统计分析或兼容历史系统。

## 2) dmPython 连接配置

FastAPI 配置文件：`backend_fastapi/app/config.py`

环境变量约定（可写入项目根目录 `.env`）：

```env
EXAM_DM8_DSN=dm+dmPython://SYSDBA:Dameng123@127.0.0.1:5236
EXAM_MYSQL_DSN=mysql+pymysql://root:root@127.0.0.1:3306/exam_system
EXAM_UPLOAD_SHARED_KEY=please-use-a-strong-key
EXAM_JWT_SECRET=please-use-a-strong-jwt-secret
EXAM_CORS_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

## 3) 后端 API（FastAPI）

入口文件：`backend_fastapi/app/main.py`

已提供接口：

- `POST /api/v1/agent/auth`：Agent 认证
- `POST /api/v1/exams`：创建考试
- `GET /api/v1/exams`：考试列表
- `POST /api/v1/results/upload`：成绩加密上传
- `WS /ws/status/{exam_id}`：实时状态推送

启动方式：

```bash
cd backend_fastapi
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 4) 学生 Agent（麒麟系统）

- 加密上传 + 断网续传：`client_agent/secure_uploader.py`
  - 使用 AES-GCM 加密上传载荷
  - 上传失败写入 `~/.exam_agent/pending_uploads.jsonl`
  - 网络恢复后自动 `flush_queue()`

- systemd 服务：
  - 模板服务文件：`client_agent/systemd/exam-agent.service`
  - 一键安装脚本：`client_agent/systemd/install_service.sh`

安装示例：

```bash
cd client_agent/systemd
chmod +x install_service.sh
./install_service.sh student1
```

## 5) 前端页面（React）

新增页面：`client/src/pages/ExamOpsCenter.tsx`

能力包括：
- 考试创建/列表刷新
- WebSocket 实时状态监控（成绩上传事件）
- CSV 导出

路由：
- `client/src/App.tsx` 新增 `/exam-ops`
- `client/src/components/DashboardLayout.tsx` 新增“实时监控”菜单
