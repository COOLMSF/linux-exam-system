import DashboardLayout from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { trpc } from "@/lib/trpc";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { Activity, Users, TrendingUp, Download, RefreshCw, Clock, BarChart2 } from "lucide-react";

const STATUS_LABELS: Record<string, string> = {
  draft: "草稿", active: "进行中", paused: "已暂停", ended: "已结束",
};

export default function ExamOpsCenter() {
  const { data: exams, isLoading: examsLoading } = trpc.exams.list.useQuery(undefined, { refetchInterval: 10000 });
  const [selectedExamId, setSelectedExamId] = useState<number | null>(null);

  const { data: records } = trpc.exams.records.useQuery(
    { examId: selectedExamId ?? undefined },
    { enabled: selectedExamId !== null, refetchInterval: 5000 },
  );
  const { data: stats } = trpc.exams.stats.useQuery(
    { examId: selectedExamId! },
    { enabled: selectedExamId !== null, refetchInterval: 5000 },
  );

  const gradedRecords = useMemo(
    () => (records ?? []).filter(r => r.totalScore != null).sort((a, b) => {
      const ta = a.submittedAt ? new Date(a.submittedAt).getTime() : 0;
      const tb = b.submittedAt ? new Date(b.submittedAt).getTime() : 0;
      return tb - ta;
    }),
    [records],
  );

  const liveStats = useMemo(() => {
    const total = gradedRecords.length;
    const avg = total > 0 ? (gradedRecords.reduce((s, r) => s + (r.totalScore ?? 0), 0) / total).toFixed(1) : "0.0";
    const max = total > 0 ? Math.max(...gradedRecords.map(r => r.totalScore ?? 0)) : 0;
    const inProgress = (records ?? []).filter(r => r.status === "in_progress").length;
    return { total, avg, max, inProgress };
  }, [gradedRecords, records]);

  function exportCsv() {
    if (!gradedRecords.length) { toast.error("暂无已评分记录"); return; }
    const header = ["学生ID", "学生姓名", "分数", "状态", "提交时间"];
    const rows = gradedRecords.map(r => [
      r.studentId, `"${(r.studentName ?? "").replaceAll('"', '""')}"`,
      r.totalScore ?? 0, r.status,
      r.submittedAt ? new Date(r.submittedAt).toLocaleString("zh-CN") : "",
    ]);
    const csv = [header.join(","), ...rows.map(r => r.join(","))].join("\n");
    const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `exam-${selectedExamId}-scores-${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  // Auto-select the first active exam
  if (exams && exams.length > 0 && selectedExamId === null) {
    const active = exams.find(e => e.status === "active");
    if (active) setSelectedExamId(active.id);
    else setSelectedExamId(exams[0].id);
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <PageHeader title="考试运营中心" description="实时监控考试进度、学生提交状态与成绩分布" />

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          {/* 考试选择 */}
          <Card className="border-0 shadow-sm lg:col-span-1">
            <CardHeader className="pb-3">
              <CardTitle className="text-base flex items-center gap-2">
                <Activity className="h-4 w-4" /> 考试列表
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 max-h-80 overflow-auto">
              {examsLoading ? (
                <p className="text-sm text-muted-foreground">加载中...</p>
              ) : (exams ?? []).length === 0 ? (
                <p className="text-sm text-muted-foreground">暂无考试</p>
              ) : (exams ?? []).map(exam => (
                <button
                  key={exam.id}
                  onClick={() => setSelectedExamId(exam.id)}
                  className={`w-full text-left rounded border p-3 transition-all ${selectedExamId === exam.id ? "border-primary ring-1 ring-primary/30 bg-primary/5" : "border-border hover:border-primary/40"}`}
                >
                  <div className="flex items-center justify-between">
                    <p className="font-medium text-sm truncate">{exam.name}</p>
                    <Badge variant="outline" className="text-xs shrink-0 ml-2">
                      {STATUS_LABELS[exam.status] ?? exam.status}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-3 mt-1 text-xs text-muted-foreground">
                    <span className="font-mono">ID: {exam.id}</span>
                    <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{exam.durationMinutes}分钟</span>
                    <span>{exam.questionCount}题</span>
                  </div>
                </button>
              ))}
            </CardContent>
          </Card>

          {/* 统计卡片 */}
          <Card className="border-0 shadow-sm lg:col-span-2">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-base flex items-center gap-2">
                  <BarChart2 className="h-4 w-4" /> 实时统计
                  {selectedExamId && <span className="text-xs font-normal text-muted-foreground ml-2">考试 #{selectedExamId}</span>}
                </CardTitle>
                <div className="flex gap-2">
                  <Button size="sm" variant="outline" className="h-7 text-xs" onClick={exportCsv}>
                    <Download className="h-3 w-3 mr-1" /> 导出 CSV
                  </Button>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
                <div className="rounded-lg border p-3 bg-blue-50/50">
                  <p className="text-xs text-muted-foreground flex items-center gap-1"><Users className="h-3 w-3" />已交卷</p>
                  <p className="text-2xl font-bold text-blue-600">{liveStats.total}</p>
                </div>
                <div className="rounded-lg border p-3 bg-amber-50/50">
                  <p className="text-xs text-muted-foreground flex items-center gap-1"><RefreshCw className="h-3 w-3" />答题中</p>
                  <p className="text-2xl font-bold text-amber-600">{liveStats.inProgress}</p>
                </div>
                <div className="rounded-lg border p-3 bg-green-50/50">
                  <p className="text-xs text-muted-foreground flex items-center gap-1"><TrendingUp className="h-3 w-3" />平均分</p>
                  <p className="text-2xl font-bold text-green-600">{liveStats.avg}</p>
                </div>
                <div className="rounded-lg border p-3 bg-purple-50/50">
                  <p className="text-xs text-muted-foreground flex items-center gap-1"><BarChart2 className="h-3 w-3" />最高分</p>
                  <p className="text-2xl font-bold text-purple-600">{liveStats.max}</p>
                </div>
              </div>

              {stats && (
                <div className="text-xs text-muted-foreground">
                  分数分布：{stats.distribution ? Object.entries(stats.distribution as Record<string, number>).map(([range, count]) =>
                    `${range}: ${count}人`
                  ).join("  ") : "暂无数据"}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* 实时提交记录 */}
        <Card className="border-0 shadow-sm">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <Activity className="h-4 w-4" />
              学生提交记录
              <span className="text-xs font-normal text-muted-foreground">（每 5 秒自动刷新）</span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2 px-2">学生 ID</th>
                    <th className="text-left py-2 px-2">姓名</th>
                    <th className="text-left py-2 px-2">分数</th>
                    <th className="text-left py-2 px-2">状态</th>
                    <th className="text-left py-2 px-2">提交时间</th>
                  </tr>
                </thead>
                <tbody>
                  {(records ?? []).length === 0 ? (
                    <tr><td className="py-8 text-center text-muted-foreground" colSpan={5}>
                      {selectedExamId ? "等待学生提交..." : "请先选择一场考试"}
                    </td></tr>
                  ) : (records ?? []).sort((a, b) => {
                    const ta = a.submittedAt ? new Date(a.submittedAt).getTime() : 0;
                    const tb = b.submittedAt ? new Date(b.submittedAt).getTime() : 0;
                    return tb - ta;
                  }).map(r => (
                    <tr key={r.id} className="border-b last:border-0 hover:bg-muted/30">
                      <td className="py-2 px-2 font-mono text-xs">{r.studentId}</td>
                      <td className="py-2 px-2">{r.studentName ?? "-"}</td>
                      <td className="py-2 px-2">
                        {r.totalScore != null ? (
                          <span className={`font-semibold ${r.totalScore >= 60 ? "text-green-600" : "text-red-500"}`}>
                            {r.totalScore}
                          </span>
                        ) : <span className="text-muted-foreground">-</span>}
                      </td>
                      <td className="py-2 px-2">
                        <Badge variant="outline" className={`text-xs ${
                          r.status === "graded" ? "text-green-600 border-green-200" :
                          r.status === "in_progress" ? "text-amber-600 border-amber-200" :
                          "text-muted-foreground"
                        }`}>
                          {r.status === "graded" ? "已评分" : r.status === "in_progress" ? "答题中" : r.status === "submitted" ? "已提交" : r.status}
                        </Badge>
                      </td>
                      <td className="py-2 px-2 text-xs text-muted-foreground">
                        {r.submittedAt ? new Date(r.submittedAt).toLocaleString("zh-CN") : "-"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
