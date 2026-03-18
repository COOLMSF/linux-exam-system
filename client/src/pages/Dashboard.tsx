import DashboardLayout from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { trpc } from "@/lib/trpc";
import { Users, BookOpen, ClipboardList, TrendingUp, Activity, CheckCircle2, Clock, AlertCircle } from "lucide-react";
import { useLocation } from "wouter";

function StatCard({ title, value, icon: Icon, color, sub }: {
  title: string; value: string | number; icon: React.ElementType; color: string; sub?: string;
}) {
  return (
    <Card className="border-0 shadow-sm bg-card">
      <CardContent className="p-4">
        <div className="flex items-center justify-between">
          <div className="min-w-0">
            <p className="text-xs text-muted-foreground mb-0.5">{title}</p>
            <p className="text-2xl font-bold text-foreground truncate">{value}</p>
            {sub && <p className="text-xs text-muted-foreground mt-0.5 truncate">{sub}</p>}
          </div>
          <div className={`h-10 w-10 rounded-lg flex items-center justify-center shrink-0 ${color}`}>
            <Icon className="h-5 w-5" />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function Dashboard() {
  const { data: exams } = trpc.exams.list.useQuery();
  const { data: questions } = trpc.questions.list.useQuery({});
  const { data: students } = trpc.students.list.useQuery({});
  const { data: records } = trpc.exams.records.useQuery({ examId: undefined });
  const [, setLocation] = useLocation();

  const activeExams = exams?.filter(e => e.status === "active") ?? [];
  const gradedCount = records?.filter(r => r.status === "graded").length ?? 0;
  const avgScore = records && records.length > 0
    ? (records.filter(r => r.totalScore != null).reduce((s, r) => s + (r.totalScore ?? 0), 0) /
       Math.max(1, records.filter(r => r.totalScore != null).length)).toFixed(1)
    : "—";

  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Header */}
        <PageHeader
          title="控制台"
          description="Linux 考试系统管理概览"
          showDashboardLink={false}
        />

        {/* Stats - Compact Grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <StatCard title="题库总量" value={questions?.length ?? 0} icon={BookOpen}
            color="bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400" sub="道题目" />
          <StatCard title="学生总数" value={students?.length ?? 0} icon={Users}
            color="bg-emerald-50 text-emerald-600 dark:bg-emerald-900/20 dark:text-emerald-400" sub="名学生" />
          <StatCard title="考试场次" value={exams?.length ?? 0} icon={ClipboardList}
            color="bg-violet-50 text-violet-600 dark:bg-violet-900/20 dark:text-violet-400"
            sub={`${activeExams.length} 场进行中`} />
          <StatCard title="平均分" value={avgScore} icon={TrendingUp}
            color="bg-amber-50 text-amber-600 dark:bg-amber-900/20 dark:text-amber-400"
            sub={`${gradedCount} 份已评分`} />
        </div>

        {/* Recent Exams */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card className="border-0 shadow-sm">
            <CardHeader className="pb-3">
              <CardTitle className="text-base font-semibold flex items-center gap-2">
                <Activity className="h-4 w-4 text-primary" />
                近期考试
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {(exams ?? []).slice(0, 5).map(exam => (
                <div key={exam.id}
                  className="flex items-center justify-between p-3 rounded-lg bg-muted/40 hover:bg-muted/60 cursor-pointer transition-colors"
                  onClick={() => setLocation("/exams")}
                >
                  <div className="min-w-0">
                    <p className="font-medium text-sm truncate">{exam.name}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {exam.durationMinutes} 分钟 · {exam.questionCount} 道题
                    </p>
                  </div>
                  <Badge variant="outline" className={
                    exam.status === "active" ? "badge-active border-emerald-200" :
                    exam.status === "paused" ? "badge-paused border-amber-200" :
                    exam.status === "ended" ? "badge-ended border-red-200" :
                    "badge-draft border-slate-200"
                  }>
                    {exam.status === "active" ? "进行中" :
                     exam.status === "paused" ? "已暂停" :
                     exam.status === "ended" ? "已结束" : "草稿"}
                  </Badge>
                </div>
              ))}
              {(exams ?? []).length === 0 && (
                <p className="text-sm text-muted-foreground text-center py-6">暂无考试场次</p>
              )}
            </CardContent>
          </Card>

          <Card className="border-0 shadow-sm">
            <CardHeader className="pb-3">
              <CardTitle className="text-base font-semibold flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-primary" />
                最近提交
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {(records ?? []).slice(0, 5).map(r => (
                <div key={r.id} className="flex items-center justify-between p-3 rounded-lg bg-muted/40">
                  <div className="min-w-0">
                    <p className="font-medium text-sm truncate">{r.studentName ?? "未知学生"}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {r.clientUsername} · {r.studentClass}
                    </p>
                  </div>
                  <div className="text-right shrink-0">
                    <p className="font-bold text-sm text-foreground">
                      {r.totalScore != null ? `${r.totalScore}` : "—"}
                      {r.maxPossibleScore != null ? ` / ${r.maxPossibleScore}` : ""}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {r.status === "graded" ? "已评分" : r.status === "submitted" ? "待评分" : "进行中"}
                    </p>
                  </div>
                </div>
              ))}
              {(records ?? []).length === 0 && (
                <p className="text-sm text-muted-foreground text-center py-6">暂无提交记录</p>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Quick actions */}
        <Card className="border-0 shadow-sm">
          <CardHeader className="pb-3">
            <CardTitle className="text-base font-semibold flex items-center gap-2">
              <Clock className="h-4 w-4 text-primary" />
              快速操作
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {[
                { label: "添加题目", path: "/questions", icon: BookOpen, color: "bg-blue-50 text-blue-700 hover:bg-blue-100 dark:bg-blue-900/20 dark:text-blue-300" },
                { label: "添加学生", path: "/students", icon: Users, color: "bg-emerald-50 text-emerald-700 hover:bg-emerald-100 dark:bg-emerald-900/20 dark:text-emerald-300" },
                { label: "创建考试", path: "/exams", icon: ClipboardList, color: "bg-violet-50 text-violet-700 hover:bg-violet-100 dark:bg-violet-900/20 dark:text-violet-300" },
                { label: "查看报表", path: "/reports", icon: TrendingUp, color: "bg-amber-50 text-amber-700 hover:bg-amber-100 dark:bg-amber-900/20 dark:text-amber-300" },
              ].map(a => (
                <button key={a.path}
                  onClick={() => setLocation(a.path)}
                  className={`flex flex-col items-center gap-2 p-4 rounded-xl transition-colors ${a.color}`}
                >
                  <a.icon className="h-5 w-5" />
                  <span className="text-sm font-medium">{a.label}</span>
                </button>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
