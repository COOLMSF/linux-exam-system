#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Linux 考试系统 - 客户端 Agent
适配麒麟操作系统 (KylinOS)
版本: 1.0.0
"""

import os
import sys
import json
import time
import getpass
import subprocess
import tempfile
import hashlib
import platform
import socket
import logging
import argparse
import threading
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any, List

# 第三方依赖（需要 pip 安装）
try:
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry
except ImportError:
    print("[错误] 缺少依赖库 requests，请运行: pip3 install requests")
    sys.exit(1)

# ─────────────────────────────────────────────
# 配置区域（可通过命令行参数或配置文件覆盖）
# ─────────────────────────────────────────────
DEFAULT_SERVER_URL = "http://localhost:3000"
CONFIG_FILE = Path.home() / ".exam_agent" / "config.json"
LOG_DIR = Path.home() / ".exam_agent" / "logs"
TOKEN_FILE = Path.home() / ".exam_agent" / "token.json"
SCRIPT_DIR = Path.home() / ".exam_agent" / "scripts"

# ─────────────────────────────────────────────
# 日志配置
# ─────────────────────────────────────────────
LOG_DIR.mkdir(parents=True, exist_ok=True)
SCRIPT_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / f"agent_{datetime.now().strftime('%Y%m%d')}.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger("ExamAgent")


# ─────────────────────────────────────────────
# HTTP 客户端（带重试机制）
# ─────────────────────────────────────────────
def create_session(server_url: str, token: Optional[str] = None) -> requests.Session:
    """创建带重试机制的 HTTP Session"""
    session = requests.Session()
    retry = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[500, 502, 503, 504],
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    session.headers.update({
        "Content-Type": "application/json",
        "User-Agent": f"ExamAgent/1.0 ({platform.system()}; {platform.machine()})",
    })
    if token:
        session.headers.update({"Authorization": f"Bearer {token}"})
    return session


# ─────────────────────────────────────────────
# 设备信息采集
# ─────────────────────────────────────────────
def get_system_username() -> str:
    """获取当前系统登录用户名"""
    try:
        return getpass.getuser()
    except Exception:
        return os.environ.get("USER", os.environ.get("USERNAME", "unknown"))


def get_device_id() -> str:
    """生成唯一设备标识（基于主机名和 MAC 地址）"""
    try:
        hostname = socket.gethostname()
        mac = hex(uuid_getnode())[2:].upper()
        raw = f"{hostname}-{mac}"
        return hashlib.sha256(raw.encode()).hexdigest()[:32]
    except Exception:
        return hashlib.sha256(platform.node().encode()).hexdigest()[:32]


def uuid_getnode() -> int:
    """获取 MAC 地址数字"""
    import uuid
    return uuid.getnode()


def get_system_info() -> Dict[str, str]:
    """采集系统信息"""
    return {
        "username": get_system_username(),
        "hostname": socket.gethostname(),
        "os": platform.system(),
        "os_version": platform.version(),
        "arch": platform.machine(),
        "device_id": get_device_id(),
    }


# ─────────────────────────────────────────────
# Token 管理
# ─────────────────────────────────────────────
def save_token(token: str, expires_at: str) -> None:
    """持久化保存 Token"""
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(TOKEN_FILE, "w", encoding="utf-8") as f:
        json.dump({"token": token, "expires_at": expires_at}, f)
    logger.info(f"Token 已保存，过期时间: {expires_at}")


def load_token() -> Optional[str]:
    """加载本地 Token（检查是否过期）"""
    if not TOKEN_FILE.exists():
        return None
    try:
        with open(TOKEN_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        expires_at = datetime.fromisoformat(data["expires_at"].replace("Z", "+00:00"))
        if datetime.now().astimezone() < expires_at:
            return data["token"]
        logger.info("本地 Token 已过期，需要重新认证")
        return None
    except Exception as e:
        logger.warning(f"加载 Token 失败: {e}")
        return None


# ─────────────────────────────────────────────
# API 调用层
# ─────────────────────────────────────────────
class ExamAPIClient:
    """考试系统 API 客户端"""

    def __init__(self, server_url: str):
        self.server_url = server_url.rstrip("/")
        self.token: Optional[str] = None
        self.session: Optional[requests.Session] = None

    def _api_url(self, path: str) -> str:
        return f"{self.server_url}/api/trpc/{path}"

    def _call(self, procedure: str, input_data: Any = None, method: str = "GET") -> Any:
        """调用 tRPC 接口（带错误处理和重试）"""
        if not self.session:
            self.session = create_session(self.server_url, self.token)

        url = self._api_url(procedure)
        max_retries = 3

        for attempt in range(max_retries):
            try:
                if method == "GET":
                    params = {}
                    if input_data is not None:
                        params["input"] = json.dumps(input_data)
                    resp = self.session.get(url, params=params, timeout=30)
                else:
                    resp = self.session.post(url, json={"json": input_data}, timeout=30)

                if resp.status_code == 401:
                    raise AuthenticationError("认证失败，Token 无效或已过期")
                if resp.status_code == 403:
                    raise PermissionError("权限不足")
                if resp.status_code == 404:
                    raise APIError(f"接口不存在: {procedure}")

                resp.raise_for_status()
                result = resp.json()

                # tRPC 响应格式解析
                if isinstance(result, list) and len(result) > 0:
                    item = result[0]
                    if "error" in item:
                        raise APIError(f"服务端错误: {item['error'].get('message', '未知错误')}")
                    return item.get("result", {}).get("data", {})
                elif isinstance(result, dict):
                    if "error" in result:
                        raise APIError(f"服务端错误: {result['error'].get('message', '未知错误')}")
                    return result.get("result", {}).get("data", result)
                return result

            except (AuthenticationError, PermissionError, APIError):
                raise
            except requests.exceptions.ConnectionError as e:
                if attempt < max_retries - 1:
                    wait = 2 ** attempt
                    logger.warning(f"连接失败，{wait}秒后重试 ({attempt+1}/{max_retries}): {e}")
                    time.sleep(wait)
                else:
                    raise NetworkError(f"无法连接到服务器 {self.server_url}: {e}")
            except requests.exceptions.Timeout:
                if attempt < max_retries - 1:
                    logger.warning(f"请求超时，重试中 ({attempt+1}/{max_retries})")
                    time.sleep(2)
                else:
                    raise NetworkError("请求超时，请检查网络连接")
            except Exception as e:
                raise APIError(f"API 调用失败: {e}")

    def authenticate(self, username: str, device_id: str) -> Dict[str, Any]:
        """客户端身份认证，获取 Token"""
        logger.info(f"正在认证用户: {username}")
        result = self._call(
            "agentApi.authenticate",
            {"username": username, "deviceId": device_id},
            method="POST"
        )
        if result.get("token"):
            self.token = result["token"]
            self.session = create_session(self.server_url, self.token)
            save_token(result["token"], result.get("expiresAt", ""))
            logger.info("认证成功")
        return result

    def get_exam(self) -> Optional[Dict[str, Any]]:
        """获取当前进行中的考试信息"""
        return self._call("agentApi.getActiveExam", method="GET")

    def get_questions(self, exam_id: int) -> List[Dict[str, Any]]:
        """从服务端抽取题目（用户名已替换）"""
        logger.info(f"正在抽取考试题目 (examId={exam_id})")
        result = self._call("agentApi.getQuestions", {"examId": exam_id}, method="POST")
        questions = result.get("questions", [])
        logger.info(f"获取到 {len(questions)} 道题目")
        return questions

    def start_exam(self, exam_id: int) -> Dict[str, Any]:
        """开始考试，创建考试记录"""
        return self._call("agentApi.startExam", {"examId": exam_id}, method="POST")

    def submit_score(self, record_id: int, score_data: Dict[str, Any]) -> Dict[str, Any]:
        """上传评分结果到服务端"""
        logger.info(f"正在上传成绩 (recordId={record_id}, score={score_data.get('totalScore')})")
        return self._call(
            "agentApi.submitScore",
            {"recordId": record_id, "scoreData": score_data},
            method="POST"
        )


# ─────────────────────────────────────────────
# 自定义异常
# ─────────────────────────────────────────────
class AuthenticationError(Exception): pass
class NetworkError(Exception): pass
class APIError(Exception): pass


# ─────────────────────────────────────────────
# 评分脚本执行器
# ─────────────────────────────────────────────
class ScriptExecutor:
    """执行评分脚本并解析结果"""

    def __init__(self, timeout: int = 300):
        self.timeout = timeout

    def execute_script(self, script_content: str, username: str) -> Dict[str, Any]:
        """
        执行 Shell 评分脚本
        返回: {"totalScore": int, "details": [...], "rawOutput": str}
        """
        # 将脚本写入临时文件
        script_file = SCRIPT_DIR / f"score_{int(time.time())}.sh"
        try:
            # 替换用户名占位符
            script_content = script_content.replace("{{username}}", username)

            with open(script_file, "w", encoding="utf-8", newline="\n") as f:
                f.write(script_content)
            os.chmod(script_file, 0o755)

            logger.info(f"执行评分脚本: {script_file}")
            start_time = time.time()

            result = subprocess.run(
                ["/bin/bash", str(script_file)],
                capture_output=True,
                text=True,
                timeout=self.timeout,
                env={**os.environ, "EXAM_USERNAME": username},
            )

            elapsed = time.time() - start_time
            logger.info(f"脚本执行完成，耗时 {elapsed:.1f}s，返回码: {result.returncode}")

            output = result.stdout + result.stderr
            return self._parse_output(output, result.returncode)

        except subprocess.TimeoutExpired:
            logger.error(f"评分脚本执行超时 ({self.timeout}s)")
            return {"totalScore": 0, "details": [], "rawOutput": "脚本执行超时", "error": "timeout"}
        except Exception as e:
            logger.error(f"脚本执行失败: {e}")
            return {"totalScore": 0, "details": [], "rawOutput": str(e), "error": str(e)}
        finally:
            # 清理临时脚本文件
            try:
                script_file.unlink(missing_ok=True)
            except Exception:
                pass

    def _parse_output(self, output: str, returncode: int) -> Dict[str, Any]:
        """
        解析脚本输出，提取分数和详情
        支持两种输出格式：
        1. JSON 格式: {"totalScore": 85, "details": [...]}
        2. 文本格式: 最后一行为总分数字，或包含 "总分:" 关键字
        """
        output = output.strip()
        details = []
        total_score = 0

        # 尝试 JSON 格式解析
        try:
            # 查找 JSON 块
            json_start = output.rfind("{")
            json_end = output.rfind("}") + 1
            if json_start >= 0 and json_end > json_start:
                json_str = output[json_start:json_end]
                data = json.loads(json_str)
                if "totalScore" in data:
                    return {
                        "totalScore": int(data["totalScore"]),
                        "details": data.get("details", []),
                        "rawOutput": output,
                        "returnCode": returncode,
                    }
        except (json.JSONDecodeError, ValueError):
            pass

        # 文本格式解析
        lines = output.split("\n")
        for line in lines:
            line = line.strip()
            # 解析扣分信息（格式: "描述:-分值"）
            if ":-" in line:
                parts = line.rsplit(":-", 1)
                if len(parts) == 2:
                    try:
                        deduction = abs(int(parts[1].strip()))
                        details.append({
                            "description": parts[0].strip(),
                            "deduction": deduction,
                            "passed": False,
                        })
                    except ValueError:
                        pass

        # 提取总分（查找 "总分:" 或最后一个纯数字行）
        for line in reversed(lines):
            line = line.strip()
            if "总分" in line or "score" in line.lower():
                import re
                nums = re.findall(r'\d+', line)
                if nums:
                    total_score = int(nums[-1])
                    break
            try:
                val = int(line)
                if 0 <= val <= 200:
                    total_score = val
                    break
            except ValueError:
                continue

        return {
            "totalScore": total_score,
            "details": details,
            "rawOutput": output,
            "returnCode": returncode,
        }


# ─────────────────────────────────────────────
# 考试流程控制器
# ─────────────────────────────────────────────
class ExamController:
    """控制完整考试流程"""

    def __init__(self, server_url: str):
        self.api = ExamAPIClient(server_url)
        self.executor = ScriptExecutor()
        self.sys_info = get_system_info()

    def print_banner(self):
        """打印系统横幅"""
        banner = """
╔══════════════════════════════════════════════════════════╗
║           Linux 考试系统 - 客户端 Agent v1.0.0            ║
║           适配麒麟操作系统 (KylinOS)                       ║
╚══════════════════════════════════════════════════════════╝
"""
        print(banner)

    def authenticate(self) -> bool:
        """执行身份认证流程"""
        username = self.sys_info["username"]
        device_id = self.sys_info["device_id"]

        print(f"\n[系统信息]")
        print(f"  当前用户: {username}")
        print(f"  主机名:   {self.sys_info['hostname']}")
        print(f"  操作系统: {self.sys_info['os']} {self.sys_info['os_version']}")
        print(f"  设备ID:   {device_id[:16]}...")

        # 尝试使用本地缓存 Token
        cached_token = load_token()
        if cached_token:
            self.api.token = cached_token
            self.api.session = create_session(self.api.server_url, cached_token)
            logger.info("使用本地缓存 Token")
            return True

        # 向服务端认证
        print(f"\n[认证] 正在向服务端认证 ({self.api.server_url})...")
        try:
            result = self.api.authenticate(username, device_id)
            if result.get("token"):
                print(f"[认证] 认证成功！欢迎, {result.get('studentName', username)}")
                return True
            else:
                print(f"[认证] 认证失败: {result.get('message', '未知错误')}")
                return False
        except AuthenticationError as e:
            print(f"[认证] 认证失败: {e}")
            print("[提示] 请联系监考老师确认您的账号已在系统中注册")
            return False
        except NetworkError as e:
            print(f"[网络] 连接失败: {e}")
            print(f"[提示] 请确认服务器地址 {self.api.server_url} 是否正确，以及网络是否畅通")
            return False

    def wait_for_exam(self) -> Optional[Dict[str, Any]]:
        """等待考试开始"""
        print("\n[等待] 正在等待考试开始...")
        check_interval = 10  # 每10秒检查一次
        max_wait = 3600  # 最长等待1小时
        elapsed = 0

        while elapsed < max_wait:
            try:
                exam = self.api.get_exam()
                if exam and exam.get("id"):
                    print(f"\n[考试] 发现考试: {exam.get('name', '未命名考试')}")
                    print(f"       时长: {exam.get('durationMinutes', 0)} 分钟")
                    print(f"       题目数: {exam.get('questionCount', 0)} 道")
                    return exam
            except NetworkError as e:
                logger.warning(f"检查考试状态失败: {e}")

            # 显示等待进度
            dots = "." * (elapsed // check_interval % 4 + 1)
            print(f"\r[等待] 考试尚未开始{dots:<4} ({elapsed}s)", end="", flush=True)
            time.sleep(check_interval)
            elapsed += check_interval

        print("\n[超时] 等待超时，请联系监考老师")
        return None

    def display_questions(self, questions: List[Dict[str, Any]]) -> None:
        """在终端显示题目内容"""
        print("\n" + "=" * 60)
        print("                    考试题目")
        print("=" * 60)
        for i, q in enumerate(questions, 1):
            print(f"\n【第 {i} 题】{q.get('title', '')}  ({q.get('maxScore', 0)} 分)")
            print("-" * 40)
            print(q.get("content", ""))
            print()
        print("=" * 60)
        print("[提示] 请在本机完成以上操作，完成后按 Enter 键开始评分")

    def run_scoring(self, questions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """执行评分流程"""
        username = self.sys_info["username"]
        all_results = []
        total_score = 0
        total_max = 0

        print("\n[评分] 开始执行评分脚本...")

        for i, q in enumerate(questions, 1):
            script = q.get("scoringScript")
            if not script:
                logger.warning(f"题目 {q.get('title')} 没有评分脚本，跳过")
                continue

            print(f"\n[评分] 正在评分第 {i} 题: {q.get('title', '')}...")
            result = self.executor.execute_script(script, username)

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
                "rawOutput": result.get("rawOutput", ""),
            })

            print(f"       得分: {q_score} / {q_max}")
            for detail in result.get("details", []):
                if not detail.get("passed", True):
                    print(f"       ✗ {detail.get('description', '')} (-{detail.get('deduction', 0)}分)")

        print(f"\n[评分] 评分完成！总分: {total_score} / {total_max}")
        return {
            "totalScore": total_score,
            "maxPossibleScore": total_max,
            "questionResults": all_results,
            "completedAt": datetime.now().isoformat(),
        }

    def run(self) -> int:
        """主流程入口"""
        self.print_banner()

        # Step 1: 身份认证
        if not self.authenticate():
            return 1

        # Step 2: 等待考试开始
        exam = self.wait_for_exam()
        if not exam:
            return 1

        # Step 3: 获取题目
        print("\n[抽题] 正在从服务端获取题目...")
        try:
            questions = self.api.get_questions(exam["id"])
        except Exception as e:
            print(f"[错误] 获取题目失败: {e}")
            return 1

        if not questions:
            print("[错误] 未获取到题目，请联系监考老师")
            return 1

        # Step 4: 开始考试记录
        try:
            record = self.api.start_exam(exam["id"])
            record_id = record.get("recordId")
        except Exception as e:
            print(f"[错误] 开始考试失败: {e}")
            return 1

        # Step 5: 显示题目
        self.display_questions(questions)

        # 等待学生确认完成操作
        print("\n完成所有操作后，请按 Enter 键开始评分...")
        try:
            input()
        except KeyboardInterrupt:
            print("\n[中断] 考试被中断")
            return 1

        # Step 6: 执行评分
        score_data = self.run_scoring(questions)

        # Step 7: 上传成绩
        print("\n[上传] 正在上传成绩到服务端...")
        max_upload_retries = 5
        for attempt in range(max_upload_retries):
            try:
                result = self.api.submit_score(record_id, score_data)
                print(f"[完成] 成绩已成功上传！")
                print(f"       最终得分: {score_data['totalScore']} / {score_data['maxPossibleScore']}")
                print(f"       提交时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                return 0
            except NetworkError as e:
                if attempt < max_upload_retries - 1:
                    wait = 5 * (attempt + 1)
                    print(f"[重试] 上传失败，{wait}秒后重试 ({attempt+1}/{max_upload_retries}): {e}")
                    time.sleep(wait)
                else:
                    print(f"[错误] 成绩上传失败，请联系监考老师手动记录成绩")
                    print(f"       本地成绩: {score_data['totalScore']} / {score_data['maxPossibleScore']}")
                    # 保存本地备份
                    backup_file = LOG_DIR / f"score_backup_{int(time.time())}.json"
                    with open(backup_file, "w", encoding="utf-8") as f:
                        json.dump({"recordId": record_id, "scoreData": score_data}, f, ensure_ascii=False, indent=2)
                    print(f"       成绩已备份至: {backup_file}")
                    return 1
            except Exception as e:
                print(f"[错误] 上传异常: {e}")
                return 1

        return 0


# ─────────────────────────────────────────────
# 配置文件管理
# ─────────────────────────────────────────────
def load_config() -> Dict[str, Any]:
    """加载配置文件"""
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def save_config(config: Dict[str, Any]) -> None:
    """保存配置文件"""
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)


# ─────────────────────────────────────────────
# 命令行入口
# ─────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Linux 考试系统客户端 Agent",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s                          # 使用默认配置启动
  %(prog)s --server http://192.168.1.100:3000  # 指定服务器地址
  %(prog)s --config                 # 配置服务器地址
  %(prog)s --test-connection        # 测试服务器连接
        """
    )
    parser.add_argument("--server", "-s", help="服务器地址 (默认: http://localhost:3000)")
    parser.add_argument("--config", "-c", action="store_true", help="进入配置模式")
    parser.add_argument("--test-connection", "-t", action="store_true", help="测试服务器连接")
    parser.add_argument("--version", "-v", action="version", version="ExamAgent 1.0.0")
    args = parser.parse_args()

    # 加载配置
    config = load_config()

    # 配置模式
    if args.config:
        print("=== 配置向导 ===")
        current = config.get("server_url", DEFAULT_SERVER_URL)
        new_url = input(f"服务器地址 [{current}]: ").strip()
        if new_url:
            config["server_url"] = new_url
        save_config(config)
        print(f"配置已保存: {CONFIG_FILE}")
        return 0

    # 确定服务器地址（优先级：命令行 > 配置文件 > 默认值）
    server_url = args.server or config.get("server_url", DEFAULT_SERVER_URL)

    # 测试连接
    if args.test_connection:
        print(f"正在测试连接: {server_url}")
        try:
            session = create_session(server_url)
            resp = session.get(f"{server_url}/api/trpc/auth.me", timeout=10)
            if resp.status_code in (200, 401):
                print(f"[成功] 服务器连接正常 (HTTP {resp.status_code})")
                return 0
            else:
                print(f"[警告] 服务器响应异常: HTTP {resp.status_code}")
                return 1
        except Exception as e:
            print(f"[失败] 无法连接到服务器: {e}")
            return 1

    # 运行考试
    controller = ExamController(server_url)
    return controller.run()


if __name__ == "__main__":
    sys.exit(main())
