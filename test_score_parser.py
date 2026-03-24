#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试 score.sh 输出格式解析
"""

import sys
from pathlib import Path

# 添加 client_agent 到路径
sys.path.insert(0, str(Path(__file__).parent / "client_agent"))

from exam_agent import ScriptExecutor

# 模拟 score.sh 的输出
SCORE_SH_OUTPUT = """
数据库软件未成功卸载:-4
第 1 题：数据库卸载
第 2 题：重新安装部署数据库
数据库名:-1
实例名:-1
端口号:-1
原有数据库的数据未恢复:-8
第 3 题：表空间及用户规划
表空间初始大小:-1
表空间扩展值:-1
账户不存在:-1
第 4 题：表管理及数据导出
部门表未能导入:-4
员工表未能导入:-4
TAB_EMP 表没有导出:-8
第 5 题：创建视图
视图 V_EMPNUM 创建失败:-4
第 6 题：数据库开发
函数建失败:-10
记录触发器信息的表不存在:-2
第 7 题：定时作业
FULLBAK 不正确:-4
第 8 题：性能优化
索引 IX_EMP_EMPNAME 未创建:-3
未搜集 TAB_EMP 表的统计信息:-4
第 9 题：数据库安全
未打开归档:-1
归档路径错误:-1
整库备份不存在:-3
***第 1 题数据库卸载得分***:0
***第 2 题重新安装部署数据库得分***:6
***第 3 题表空间及用户规划得分***:5
***第 4 题表管理及数据导出得分***:2
***第 5 题创建视图得分***:4
***第 6 题数据库开发得分***:8
***第 7 题定时作业得分***:4
***第 8 题性能优化得分***:3
***第 9 题数据库安全得分***:5
总得分：37
"""

# 测试完美成绩输出
PERFECT_OUTPUT = """
第 1 题：数据库卸载
第 2 题：重新安装部署数据库
第 3 题：表空间及用户规划
第 4 题：表管理及数据导出
第 5 题：创建视图
第 6 题：数据库开发
第 7 题：定时作业
第 8 题：性能优化
第 9 题：数据库安全
***第 1 题数据库卸载得分***:4
***第 2 题重新安装部署数据库得分***:14
***第 3 题表空间及用户规划得分***:8
***第 4 题表管理及数据导出得分***:18
***第 5 题创建视图得分***:8
***第 6 题数据库开发得分***:20
***第 7 题定时作业得分***:8
***第 8 题性能优化得分***:10
***第 9 题数据库安全得分***:10
总得分：100
"""

# 测试 JSON 格式输出
JSON_OUTPUT = """{"totalScore": 85, "details": [{"description": "数据库未安装", "deduction": 5, "passed": false}]}"""


def test_parse_output():
    """测试输出解析功能"""
    executor = ScriptExecutor()
    
    print("=" * 60)
    print("测试 score.sh 输出解析")
    print("=" * 60)
    
    # 测试 1: score.sh 格式
    print("\n[测试 1] score.sh 格式（扣分场景）")
    print("-" * 40)
    result = executor._parse_output(SCORE_SH_OUTPUT, 0)
    print(f"总分：{result['totalScore']}")
    print(f"题目得分：{result['questionScores']}")
    print(f"扣分项数量：{len(result['details'])}")
    print(f"原始输出长度：{len(result['rawOutput'])}")
    
    assert result['totalScore'] == 37, f"期望 37 分，实际{result['totalScore']}分"
    assert result['questionScores'] == {
        1: 0, 2: 6, 3: 5, 4: 2, 5: 4, 6: 8, 7: 4, 8: 3, 9: 5
    }, "题目得分不匹配"
    print("✓ 测试通过")
    
    # 测试 2: 完美成绩
    print("\n[测试 2] 完美成绩（100 分）")
    print("-" * 40)
    result = executor._parse_output(PERFECT_OUTPUT, 0)
    print(f"总分：{result['totalScore']}")
    print(f"题目得分：{result['questionScores']}")
    print(f"扣分项数量：{len(result['details'])}")
    
    assert result['totalScore'] == 100, f"期望 100 分，实际{result['totalScore']}分"
    assert result['questionScores'] == {
        1: 4, 2: 14, 3: 8, 4: 18, 5: 8, 6: 20, 7: 8, 8: 10, 9: 10
    }, "题目得分不匹配"
    print("✓ 测试通过")
    
    # 测试 3: JSON 格式
    print("\n[测试 3] JSON 格式")
    print("-" * 40)
    result = executor._parse_output(JSON_OUTPUT, 0)
    print(f"总分：{result['totalScore']}")
    print(f"详情：{result['details']}")
    
    assert result['totalScore'] == 85, f"期望 85 分，实际{result['totalScore']}分"
    print("✓ 测试通过")
    
    # 测试 4: 空输出
    print("\n[测试 4] 空输出")
    print("-" * 40)
    result = executor._parse_output("", 0)
    print(f"总分：{result['totalScore']}")
    print(f"题目得分：{result['questionScores']}")
    
    assert result['totalScore'] == 0, f"期望 0 分，实际{result['totalScore']}分"
    print("✓ 测试通过")
    
    print("\n" + "=" * 60)
    print("所有测试通过！")
    print("=" * 60)
    
    return True


if __name__ == "__main__":
    try:
        success = test_parse_output()
        sys.exit(0 if success else 1)
    except AssertionError as e:
        print(f"\n✗ 测试失败：{e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ 测试异常：{e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
