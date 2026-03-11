import { useAuth } from "@/_core/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { getLoginUrl } from "@/const";
import { ShieldCheck, BookOpen, BarChart3, Terminal, ArrowRight, Server } from "lucide-react";
import { useLocation } from "wouter";

export default function Home() {
  const { user, loading } = useAuth();
  const [, setLocation] = useLocation();

  if (!loading && user) {
    setLocation("/dashboard");
    return null;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-[oklch(0.20_0.04_255)] via-[oklch(0.16_0.05_255)] to-[oklch(0.12_0.06_260)] text-white flex flex-col">
      {/* Header */}
      <header className="flex items-center justify-between px-8 py-5 border-b border-white/10">
        <div className="flex items-center gap-3">
          <div className="h-9 w-9 rounded-lg bg-[oklch(0.72_0.15_55)] flex items-center justify-center">
            <Terminal className="h-5 w-5 text-[oklch(0.15_0.03_55)]" />
          </div>
          <span className="text-lg font-semibold tracking-tight">Linux 考试系统</span>
        </div>
        <Button
          onClick={() => window.location.href = getLoginUrl()}
          className="bg-[oklch(0.72_0.15_55)] text-[oklch(0.15_0.03_55)] hover:bg-[oklch(0.68_0.16_55)] font-medium"
        >
          管理员登录
        </Button>
      </header>

      {/* Hero */}
      <main className="flex-1 flex flex-col items-center justify-center px-8 py-20 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/10 text-sm text-white/80 mb-8 border border-white/20">
          <Server className="h-3.5 w-3.5" />
          <span>适配麒麟操作系统 · 达梦数据库 DM8</span>
        </div>

        <h1 className="text-5xl md:text-6xl font-bold tracking-tight mb-6 leading-tight">
          Linux 技能考试<br />
          <span className="text-[oklch(0.72_0.15_55)]">智能评测平台</span>
        </h1>

        <p className="text-lg text-white/70 max-w-2xl mb-10 leading-relaxed">
          基于 C/S 架构的专业 Linux 考试系统，支持随机抽题、自动评分、实时成绩汇总，
          全面适配麒麟操作系统与达梦数据库 DM8 环境。
        </p>

        <div className="flex gap-4 flex-wrap justify-center">
          <Button
            size="lg"
            onClick={() => window.location.href = getLoginUrl()}
            className="bg-[oklch(0.72_0.15_55)] text-[oklch(0.15_0.03_55)] hover:bg-[oklch(0.68_0.16_55)] font-semibold px-8 h-12"
          >
            进入管理后台
            <ArrowRight className="ml-2 h-4 w-4" />
          </Button>
        </div>

        {/* Feature cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5 mt-20 max-w-5xl w-full">
          {[
            {
              icon: BookOpen,
              title: "智能题库管理",
              desc: "支持多分类题目管理，用户名占位符自动替换，随机抽题算法",
            },
            {
              icon: ShieldCheck,
              title: "灵活评分规则",
              desc: "可视化配置评分标准，支持文件检查、命令验证、数据库查询等多种规则",
            },
            {
              icon: Terminal,
              title: "客户端 Agent",
              desc: "Python 编写的考试客户端，支持 PyInstaller 打包为麒麟系统可执行文件",
            },
            {
              icon: BarChart3,
              title: "数据可视化",
              desc: "成绩分布图表、趋势分析、错题率统计，支持 CSV/Excel 导出",
            },
          ].map((f) => (
            <div
              key={f.title}
              className="bg-white/5 border border-white/10 rounded-xl p-6 text-left hover:bg-white/8 transition-colors"
            >
              <div className="h-10 w-10 rounded-lg bg-[oklch(0.72_0.15_55)]/20 flex items-center justify-center mb-4">
                <f.icon className="h-5 w-5 text-[oklch(0.72_0.15_55)]" />
              </div>
              <h3 className="font-semibold mb-2">{f.title}</h3>
              <p className="text-sm text-white/60 leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </main>

      <footer className="text-center py-6 text-white/40 text-sm border-t border-white/10">
        Linux 考试系统 · 适配麒麟 OS + 达梦数据库 DM8
      </footer>
    </div>
  );
}
