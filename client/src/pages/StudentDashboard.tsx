import { useAuth } from "@/_core/hooks/useAuth";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { trpc } from "@/lib/trpc";
import {
  BookOpen, ClipboardList, Eye, EyeOff, GraduationCap, KeyRound, Loader2, LogOut,
  Trophy, User, Clock, BarChart2, ChevronRight,
} from "lucide-react";
import { useMemo, useState } from "react";
import { useLocation } from "wouter";
import { toast } from "sonner";

const STATUS_MAP: Record<string, { label: string; color: string }> = {
  active: { label: "进行中", color: "text-green-600 border-green-200 bg-green-50" },
  ended: { label: "已结束", color: "text-gray-500 border-gray-200 bg-gray-50" },
  graded: { label: "已评分", color: "text-blue-600 border-blue-200 bg-blue-50" },
  in_progress: { label: "答题中", color: "text-amber-600 border-amber-200 bg-amber-50" },
  submitted: { label: "已提交", color: "text-purple-600 border-purple-200 bg-purple-50" },
};

function StatusBadge({ status }: { status: string }) {
  const s = STATUS_MAP[status] ?? { label: status, color: "" };
  return <Badge variant="outline" className={`text-xs ${s.color}`}>{s.label}</Badge>;
}

export default function StudentDashboard() {
  const { user, logout } = useAuth();
  const [, setLocation] = useLocation();
  const [tab, setTab] = useState<"exams" | "records" | "profile">("exams");
  const [showChangePwd, setShowChangePwd] = useState(false);
  const [selectedRecord, setSelectedRecord] = useState<number | null>(null);

  const { data: profile } = trpc.studentPortal.profile.useQuery(undefined, { retry: false });
  const { data: exams } = trpc.studentPortal.exams.useQuery(undefined, { refetchInterval: 15000 });
  const { data: records } = trpc.studentPortal.myRecords.useQuery(undefined, { refetchInterval: 10000 });
  const { data: scoreDetail } = trpc.studentPortal.scoreDetail.useQuery(
    { recordId: selectedRecord! },
    { enabled: selectedRecord !== null },
  );

  const stats = useMemo(() => {
    if (!records?.length) return { total: 0, graded: 0, avg: "0", best: 0 };
    const graded = records.filter(r => r.totalScore != null);
    return {
      total: records.length,
      graded: graded.length,
      avg: graded.length > 0 ? (graded.reduce((s, r) => s + (r.totalScore ?? 0), 0) / graded.length).toFixed(1) : "0",
      best: graded.length > 0 ? Math.max(...graded.map(r => r.totalScore ?? 0)) : 0,
    };
  }, [records]);

  if (!user || user.role !== "student") {
    setLocation("/");
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Top nav */}
      <header className="bg-white border-b sticky top-0 z-40">
        <div className="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <GraduationCap className="h-5 w-5 text-primary" />
            <span className="font-semibold">学生中心</span>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-sm text-muted-foreground">{profile?.name ?? user.name}</span>
            <Button size="sm" variant="ghost" className="h-8 text-xs" onClick={() => setShowChangePwd(true)}>
              <KeyRound className="h-3.5 w-3.5 mr-1" />修改密码
            </Button>
            <Button size="sm" variant="ghost" className="h-8 text-xs text-destructive" onClick={() => { logout(); setLocation("/"); }}>
              <LogOut className="h-3.5 w-3.5 mr-1" />退出
            </Button>
          </div>
        </div>
      </header>

      <div className="max-w-5xl mx-auto px-4 py-6 space-y-6">
        {/* Stats cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card className="border-0 shadow-sm">
            <CardContent className="pt-4 pb-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-lg bg-blue-50 flex items-center justify-center">
                  <ClipboardList className="h-5 w-5 text-blue-600" />
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">参加考试</p>
                  <p className="text-xl font-bold">{stats.total}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="border-0 shadow-sm">
            <CardContent className="pt-4 pb-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-lg bg-green-50 flex items-center justify-center">
                  <BarChart2 className="h-5 w-5 text-green-600" />
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">已评分</p>
                  <p className="text-xl font-bold">{stats.graded}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="border-0 shadow-sm">
            <CardContent className="pt-4 pb-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-lg bg-amber-50 flex items-center justify-center">
                  <BarChart2 className="h-5 w-5 text-amber-600" />
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">平均分</p>
                  <p className="text-xl font-bold">{stats.avg}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="border-0 shadow-sm">
            <CardContent className="pt-4 pb-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-lg bg-purple-50 flex items-center justify-center">
                  <Trophy className="h-5 w-5 text-purple-600" />
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">最高分</p>
                  <p className="text-xl font-bold">{stats.best}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Tab navigation */}
        <div className="flex gap-1 bg-white rounded-lg p-1 shadow-sm border">
          {([
            { key: "exams" as const, label: "考试列表", icon: BookOpen },
            { key: "records" as const, label: "我的成绩", icon: Trophy },
            { key: "profile" as const, label: "个人信息", icon: User },
          ]).map(t => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-md text-sm font-medium transition-all ${tab === t.key ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:text-foreground"}`}
            >
              <t.icon className="h-4 w-4" />{t.label}
            </button>
          ))}
        </div>

        {/* Tab content */}
        {tab === "exams" && (
          <div className="space-y-3">
            {!exams?.length ? (
              <Card className="border-0 shadow-sm"><CardContent className="py-12 text-center text-muted-foreground"><BookOpen className="h-8 w-8 mx-auto mb-2 opacity-30" />暂无可查看的考试</CardContent></Card>
            ) : exams.map(exam => (
              <Card key={exam.id} className="border-0 shadow-sm hover:shadow transition-shadow">
                <CardContent className="py-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-medium">{exam.name}</h3>
                        <StatusBadge status={exam.status} />
                      </div>
                      {exam.description && <p className="text-xs text-muted-foreground mb-2">{exam.description}</p>}
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{exam.durationMinutes} 分钟</span>
                        <span className="flex items-center gap-1"><BookOpen className="h-3 w-3" />{exam.questionCount} 题</span>
                        <span className="font-mono">ID: {exam.id}</span>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        {tab === "records" && (
          <div className="space-y-3">
            {!records?.length ? (
              <Card className="border-0 shadow-sm"><CardContent className="py-12 text-center text-muted-foreground"><Trophy className="h-8 w-8 mx-auto mb-2 opacity-30" />暂无考试记录</CardContent></Card>
            ) : records.map(r => (
              <Card key={r.id} className="border-0 shadow-sm hover:shadow transition-shadow cursor-pointer" onClick={() => setSelectedRecord(r.id)}>
                <CardContent className="py-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-medium">{r.examName ?? `考试 #${r.examId}`}</h3>
                        <StatusBadge status={r.status} />
                      </div>
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        {r.startedAt && <span>开始: {new Date(r.startedAt).toLocaleString("zh-CN")}</span>}
                        {r.submittedAt && <span>提交: {new Date(r.submittedAt).toLocaleString("zh-CN")}</span>}
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {r.totalScore != null && (
                        <div className="text-right">
                          <p className={`text-2xl font-bold ${r.totalScore >= 60 ? "text-green-600" : "text-red-500"}`}>
                            {r.totalScore}
                          </p>
                          {r.maxPossibleScore && <p className="text-xs text-muted-foreground">/ {r.maxPossibleScore}</p>}
                        </div>
                      )}
                      <ChevronRight className="h-4 w-4 text-muted-foreground" />
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        {tab === "profile" && profile && (
          <Card className="border-0 shadow-sm">
            <CardHeader><CardTitle className="text-base flex items-center gap-2"><User className="h-4 w-4" />个人信息</CardTitle></CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {[
                  { label: "学号", value: profile.studentId },
                  { label: "姓名", value: profile.name },
                  { label: "班级", value: profile.className || "-" },
                  { label: "院系", value: profile.department || "-" },
                ].map(item => (
                  <div key={item.label} className="rounded-lg border p-3">
                    <p className="text-xs text-muted-foreground mb-1">{item.label}</p>
                    <p className="font-medium">{item.value}</p>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Score detail dialog */}
      <Dialog open={selectedRecord !== null} onOpenChange={(v) => { if (!v) setSelectedRecord(null); }}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>成绩详情</DialogTitle>
          </DialogHeader>
          {scoreDetail ? (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <StatusBadge status={scoreDetail.record.status} />
                  {scoreDetail.record.submittedAt && (
                    <p className="text-xs text-muted-foreground mt-1">
                      提交于 {new Date(scoreDetail.record.submittedAt).toLocaleString("zh-CN")}
                    </p>
                  )}
                </div>
                <div className="text-right">
                  <p className={`text-3xl font-bold ${(scoreDetail.record.totalScore ?? 0) >= 60 ? "text-green-600" : "text-red-500"}`}>
                    {scoreDetail.record.totalScore ?? 0}
                  </p>
                  <p className="text-xs text-muted-foreground">/ {scoreDetail.record.maxPossibleScore ?? 100}</p>
                </div>
              </div>
              {scoreDetail.details?.length > 0 && (
                <div className="space-y-2">
                  <p className="text-sm font-medium">各题得分</p>
                  {scoreDetail.details.map((d: any, i: number) => (
                    <div key={d.id ?? i} className="flex items-center justify-between rounded border p-2 text-sm">
                      <span>第 {i + 1} 题</span>
                      <span className={`font-semibold ${d.earnedScore >= d.maxScore * 0.6 ? "text-green-600" : "text-red-500"}`}>
                        {d.earnedScore} / {d.maxScore}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <div className="py-8 text-center"><Loader2 className="h-6 w-6 animate-spin mx-auto text-muted-foreground" /></div>
          )}
        </DialogContent>
      </Dialog>

      {/* Change password dialog */}
      <ChangePasswordDialog open={showChangePwd} onOpenChange={setShowChangePwd} />
    </div>
  );
}

function ChangePasswordDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const [oldPwd, setOldPwd] = useState("");
  const [newPwd, setNewPwd] = useState("");
  const [confirmPwd, setConfirmPwd] = useState("");
  const [showOld, setShowOld] = useState(false);
  const [showNew, setShowNew] = useState(false);

  const changePwd = trpc.auth.studentChangePassword.useMutation({
    onSuccess: () => {
      toast.success("密码修改成功");
      onOpenChange(false);
      setOldPwd(""); setNewPwd(""); setConfirmPwd("");
    },
    onError: (err) => toast.error(err.message || "修改失败"),
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (newPwd.length < 6) { toast.error("新密码至少 6 位"); return; }
    if (newPwd !== confirmPwd) { toast.error("两次输入的新密码不一致"); return; }
    changePwd.mutate({ oldPassword: oldPwd, newPassword: newPwd });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2"><KeyRound className="h-4 w-4" />修改密码</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label>原密码</Label>
            <div className="relative">
              <Input type={showOld ? "text" : "password"} value={oldPwd} onChange={e => setOldPwd(e.target.value)} placeholder="请输入当前密码" required />
              <button type="button" tabIndex={-1} className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground" onClick={() => setShowOld(!showOld)}>
                {showOld ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>
          <div className="space-y-1.5">
            <Label>新密码 <span className="text-muted-foreground font-normal">（至少 6 位）</span></Label>
            <div className="relative">
              <Input type={showNew ? "text" : "password"} value={newPwd} onChange={e => setNewPwd(e.target.value)} placeholder="请输入新密码" required minLength={6} />
              <button type="button" tabIndex={-1} className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground" onClick={() => setShowNew(!showNew)}>
                {showNew ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>
          <div className="space-y-1.5">
            <Label>确认新密码</Label>
            <Input type="password" value={confirmPwd} onChange={e => setConfirmPwd(e.target.value)} placeholder="再次输入新密码" required />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>取消</Button>
            <Button type="submit" disabled={changePwd.isPending}>
              {changePwd.isPending ? <><Loader2 className="h-4 w-4 animate-spin mr-2" />提交中...</> : "确认修改"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
