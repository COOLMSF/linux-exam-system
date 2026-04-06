import { useAuth } from "@/_core/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { trpc } from "@/lib/trpc";
import { BookOpen, BarChart3, Terminal, ArrowRight, Server, ShieldCheck, Eye, EyeOff, Loader2, Settings, KeyRound } from "lucide-react";
import { useState, useEffect } from "react";
import { useLocation } from "wouter";
import { toast } from "sonner";

// oklch(0.20_0.04_255) ≈ hsl(240, 18%, 18%)
// oklch(0.16_0.05_255) ≈ hsl(240, 22%, 14%)
// oklch(0.12_0.06_260) ≈ hsl(245, 28%, 10%)
// oklch(0.72_0.15_55)  ≈ hsl(42, 80%, 58%)   (golden amber)
// oklch(0.15_0.03_55)  ≈ hsl(42, 30%, 14%)   (dark amber)
// oklch(0.68_0.16_55)  ≈ hsl(42, 82%, 52%)   (darker amber hover)
// oklch(0.85_0.12_55)  ≈ hsl(42, 55%, 78%)   (light amber text)

export default function Home() {
  const { user, loading } = useAuth();
  const [, setLocation] = useLocation();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [mode, setMode] = useState<"login" | "setup" | "changepwd">("login");
  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showNewPassword, setShowNewPassword] = useState(false);

  // Check if setup is needed
  const needsSetupQuery = trpc.auth.needsSetup.useQuery(undefined, { retry: false });
  const utils = trpc.useUtils();

  const localLoginMutation = trpc.auth.localLogin.useMutation({
    onError: (err) => {
      toast.error(err.message || "登录失败，请检查用户名和密码");
    },
  });

  const setupAdminMutation = trpc.auth.setupAdmin.useMutation({
    onSuccess: (data) => {
      toast.success(data.message || "管理员账号创建成功");
      setMode("login");
      utils.auth.needsSetup.invalidate();
    },
    onError: (err) => {
      toast.error(err.message || "创建失败");
    },
  });

  const changePasswordMutation = trpc.auth.changePassword.useMutation({
    onSuccess: () => {
      toast.success("密码修改成功，请使用新密码登录");
      setMode("login");
      setPassword("");
      setOldPassword("");
      setNewPassword("");
      setConfirmPassword("");
    },
    onError: (err) => {
      toast.error(err.message || "密码修改失败");
    },
  });

  useEffect(() => {
    if (!loading && user) {
      setLocation("/dashboard");
    }
  }, [user, loading, setLocation]);

  useEffect(() => {
    if (needsSetupQuery.data?.needsSetup) {
      setMode("setup");
    }
  }, [needsSetupQuery.data]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (mode === "changepwd") {
      if (!username.trim() || !oldPassword.trim() || !newPassword.trim()) {
        toast.error("请填写所有字段");
        return;
      }
      if (newPassword.length < 6) {
        toast.error("新密码至少需要 6 位");
        return;
      }
      if (newPassword !== confirmPassword) {
        toast.error("两次输入的新密码不一致");
        return;
      }
      // Login first to get session, then change password (don't redirect)
      localLoginMutation.mutate({ username: username.trim(), password: oldPassword }, {
        onSuccess: () => {
          utils.auth.me.invalidate();
          changePasswordMutation.mutate({ oldPassword, newPassword });
        },
      });
      return;
    }
    if (!username.trim() || !password.trim()) {
      toast.error("请输入用户名和密码");
      return;
    }
    if (mode === "setup") {
      if (password.length < 6) {
        toast.error("密码至少需要 6 位");
        return;
      }
      setupAdminMutation.mutate({ username: username.trim(), password });
    } else {
      localLoginMutation.mutate({ username: username.trim(), password }, {
        onSuccess: () => {
          toast.success("登录成功");
          utils.auth.me.invalidate();
          setLocation("/dashboard");
        },
      });
    }
  };

  const isPending = localLoginMutation.isPending || setupAdminMutation.isPending || changePasswordMutation.isPending;

  if (loading || needsSetupQuery.isLoading) {
    return (
      <div style={{ background: "linear-gradient(135deg, hsl(240,18%,18%) 0%, hsl(240,22%,14%) 50%, hsl(245,28%,10%) 100%)" }}
        className="min-h-screen flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-white/60" />
      </div>
    );
  }

  return (
    <div style={{ background: "linear-gradient(135deg, hsl(240,18%,18%) 0%, hsl(240,22%,14%) 50%, hsl(245,28%,10%) 100%)" }}
      className="min-h-screen text-white flex flex-col">
      {/* Header */}
      <header className="flex items-center justify-between px-8 py-5 border-b border-white/10">
        <div className="flex items-center gap-3">
          <div style={{ background: "hsl(42,80%,58%)" }} className="h-9 w-9 rounded-lg flex items-center justify-center">
            <Terminal style={{ color: "hsl(42,30%,14%)" }} className="h-5 w-5" />
          </div>
          <span className="text-lg font-semibold tracking-tight">Linux 考试系统</span>
        </div>
        <div className="flex items-center gap-2 text-sm text-white/50">
          <Server className="h-4 w-4" />
          <span>适配麒麟 OS · 达梦 DM8</span>
        </div>
      </header>

      {/* Main */}
      <main className="flex-1 flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-5xl grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          {/* Left: Intro */}
          <div className="hidden lg:block">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/10 text-xs text-white/70 mb-6 border border-white/20">
              <Server className="h-3 w-3" />
              <span>C/S 架构 · 自动评分 · 实时汇总</span>
            </div>
            <h1 className="text-4xl font-bold tracking-tight mb-4 leading-tight">
              Linux 技能考试<br />
              <span style={{ color: "hsl(42,80%,58%)" }}>智能评测平台</span>
            </h1>
            <p className="text-white/60 leading-relaxed mb-8 text-sm">
              基于 C/S 架构的专业 Linux 考试系统，支持随机抽题、本地自动评分、
              实时成绩汇总，全面适配麒麟操作系统与达梦数据库 DM8 环境。
            </p>
            <div className="grid grid-cols-2 gap-3">
              {[
                { icon: BookOpen, title: "智能题库", desc: "多分类题目，随机抽题" },
                { icon: ShieldCheck, title: "灵活评分", desc: "可视化规则配置" },
                { icon: Terminal, title: "客户端 Agent", desc: "PyInstaller 打包" },
                { icon: BarChart3, title: "数据可视化", desc: "成绩图表与导出" },
              ].map((f) => (
                <div key={f.title} className="bg-white/5 border border-white/10 rounded-lg p-4 hover:bg-white/8 transition-colors">
                  <div style={{ background: "hsla(42,80%,58%,0.2)" }} className="h-8 w-8 rounded-md flex items-center justify-center mb-2">
                    <f.icon style={{ color: "hsl(42,80%,58%)" }} className="h-4 w-4" />
                  </div>
                  <div className="font-medium text-sm">{f.title}</div>
                  <div className="text-xs text-white/50 mt-0.5">{f.desc}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Right: Login / Setup Form */}
          <div className="w-full max-w-sm mx-auto lg:mx-0">
            <div className="bg-white/8 border border-white/15 rounded-2xl p-8 backdrop-blur-sm shadow-2xl">
              {/* Form header */}
              <div className="flex items-center gap-3 mb-6">
                <div style={{ background: "hsl(42,80%,58%)" }} className="h-10 w-10 rounded-xl flex items-center justify-center">
                  {mode === "setup" ? (
                    <Settings style={{ color: "hsl(42,30%,14%)" }} className="h-5 w-5" />
                  ) : mode === "changepwd" ? (
                    <KeyRound style={{ color: "hsl(42,30%,14%)" }} className="h-5 w-5" />
                  ) : (
                    <ShieldCheck style={{ color: "hsl(42,30%,14%)" }} className="h-5 w-5" />
                  )}
                </div>
                <div>
                  <h2 className="font-semibold text-lg">
                    {mode === "setup" ? "初始化管理员" : mode === "changepwd" ? "修改密码" : "管理员登录"}
                  </h2>
                  <p className="text-xs text-white/50">
                    {mode === "setup"
                      ? "首次使用，请创建管理员账号"
                      : mode === "changepwd"
                      ? "输入用户名和原密码验证身份后修改"
                      : "请输入账号密码登录管理后台"}
                  </p>
                </div>
              </div>

              {mode === "setup" && (
                <div style={{ background: "hsla(42,80%,58%,0.15)", borderColor: "hsla(42,80%,58%,0.3)", color: "hsl(42,55%,78%)" }}
                  className="mb-5 p-3 rounded-lg border text-xs">
                  系统检测到尚未创建管理员账号，请先完成初始化设置。
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="space-y-1.5">
                  <Label className="text-white/80 text-sm">用户名</Label>
                  <Input
                    type="text"
                    placeholder="请输入用户名"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    disabled={isPending}
                    className="bg-white/10 border-white/20 text-white placeholder:text-white/30 h-11"
                    autoComplete="username"
                    autoFocus
                  />
                </div>

                {mode === "changepwd" ? (
                  <>
                    <div className="space-y-1.5">
                      <Label className="text-white/80 text-sm">原密码</Label>
                      <div className="relative">
                        <Input
                          type={showPassword ? "text" : "password"}
                          placeholder="请输入当前密码"
                          value={oldPassword}
                          onChange={(e) => setOldPassword(e.target.value)}
                          disabled={isPending}
                          className="bg-white/10 border-white/20 text-white placeholder:text-white/30 h-11 pr-10"
                          autoComplete="current-password"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword(!showPassword)}
                          className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/70 transition-colors"
                        >
                          {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                        </button>
                      </div>
                    </div>
                    <div className="space-y-1.5">
                      <Label className="text-white/80 text-sm">新密码 <span className="text-white/40 font-normal">（至少 6 位）</span></Label>
                      <div className="relative">
                        <Input
                          type={showNewPassword ? "text" : "password"}
                          placeholder="请输入新密码"
                          value={newPassword}
                          onChange={(e) => setNewPassword(e.target.value)}
                          disabled={isPending}
                          className="bg-white/10 border-white/20 text-white placeholder:text-white/30 h-11 pr-10"
                          autoComplete="new-password"
                          minLength={6}
                        />
                        <button
                          type="button"
                          onClick={() => setShowNewPassword(!showNewPassword)}
                          className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/70 transition-colors"
                        >
                          {showNewPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                        </button>
                      </div>
                    </div>
                    <div className="space-y-1.5">
                      <Label className="text-white/80 text-sm">确认新密码</Label>
                      <Input
                        type="password"
                        placeholder="再次输入新密码"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        disabled={isPending}
                        className="bg-white/10 border-white/20 text-white placeholder:text-white/30 h-11"
                        autoComplete="new-password"
                      />
                    </div>
                  </>
                ) : (
                  <div className="space-y-1.5">
                    <Label className="text-white/80 text-sm">
                      密码{mode === "setup" && <span className="text-white/40 ml-1 font-normal">（至少 6 位）</span>}
                    </Label>
                    <div className="relative">
                      <Input
                        type={showPassword ? "text" : "password"}
                        placeholder={mode === "setup" ? "设置登录密码" : "请输入密码"}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        disabled={isPending}
                        className="bg-white/10 border-white/20 text-white placeholder:text-white/30 h-11 pr-10"
                        autoComplete={mode === "setup" ? "new-password" : "current-password"}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/70 transition-colors"
                      >
                        {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                      </button>
                    </div>
                  </div>
                )}

                <Button
                  type="submit"
                  disabled={isPending}
                  style={{ background: "hsl(42,80%,58%)", color: "hsl(42,30%,14%)" }}
                  className="w-full h-11 font-semibold mt-2 hover:opacity-90"
                >
                  {isPending ? (
                    <><Loader2 className="h-4 w-4 animate-spin mr-2" />处理中...</>
                  ) : mode === "setup" ? (
                    <><Settings className="h-4 w-4 mr-2" />创建管理员账号</>
                  ) : mode === "changepwd" ? (
                    <><KeyRound className="h-4 w-4 mr-2" />确认修改密码</>
                  ) : (
                    <><ArrowRight className="h-4 w-4 mr-2" />登录管理后台</>
                  )}
                </Button>
              </form>

              <div className="mt-4 pt-4 border-t border-white/10 flex items-center justify-center gap-4">
                {mode === "changepwd" ? (
                  <button
                    onClick={() => setMode("login")}
                    className="text-xs text-white/40 hover:text-white/60 transition-colors"
                  >
                    ← 返回登录
                  </button>
                ) : (
                  <>
                    <button
                      onClick={() => setMode("changepwd")}
                      className="text-xs text-white/40 hover:text-white/60 transition-colors flex items-center gap-1"
                    >
                      <KeyRound className="h-3 w-3" />修改密码
                    </button>
                    {mode === "login" && needsSetupQuery.data && !needsSetupQuery.data.needsSetup && (
                      <span className="text-white/20">|</span>
                    )}
                    {mode === "login" && needsSetupQuery.data && !needsSetupQuery.data.needsSetup && (
                      <button
                        onClick={() => setMode("setup")}
                        className="text-xs text-white/40 hover:text-white/60 transition-colors"
                      >
                        首次使用？创建管理员
                      </button>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Mobile feature list */}
            <div className="lg:hidden mt-6 grid grid-cols-2 gap-2">
              {[
                { icon: BookOpen, title: "智能题库管理" },
                { icon: ShieldCheck, title: "灵活评分规则" },
                { icon: Terminal, title: "客户端 Agent" },
                { icon: BarChart3, title: "数据可视化" },
              ].map((f) => (
                <div key={f.title} className="flex items-center gap-2 text-xs text-white/50">
                  <f.icon style={{ color: "hsl(42,80%,58%)" }} className="h-3.5 w-3.5" />
                  <span>{f.title}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>

      <footer className="text-center py-5 text-white/30 text-xs border-t border-white/10">
        Linux 考试系统 · 适配麒麟 OS + 达梦数据库 DM8 · C/S 架构
      </footer>
    </div>
  );
}
