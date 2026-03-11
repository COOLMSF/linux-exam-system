import DashboardLayout from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { trpc } from "@/lib/trpc";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend, LineChart, Line, AreaChart, Area
} from "recharts";
import { Download, BarChart3, TrendingUp, Users, Award } from "lucide-react";
import { useState, useMemo } from "react";
import { toast } from "sonner";

const COLORS = ["#3b5bdb", "#10b981", "#f59e0b", "#8b5cf6", "#ef4444"];

function ScoreDistributionChart({ records }: { records: { totalScore: number | null }[] }) {
  const buckets = [
    { range: "0-59", count: 0 },
    { range: "60-69", count: 0 },
    { range: "70-79", count: 0 },
    { range: "80-89", count: 0 },
    { range: "90-100", count: 0 },
  ];
  records.forEach(r => {
    if (r.totalScore == null) return;
    const s = r.totalScore;
    if (s < 60) buckets[0].count++;
    else if (s < 70) buckets[1].count++;
    else if (s < 80) buckets[2].count++;
    else if (s < 90) buckets[3].count++;
    else buckets[4].count++;
  });
  return (
    <ResponsiveContainer width="100%" height={220}>
      <BarChart data={buckets} margin={{ top: 5, right: 10, left: -10, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
        <XAxis dataKey="range" tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))" }} />
        <YAxis tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))" }} />
        <Tooltip contentStyle={{ background: "hsl(var(--card))", border: "1px solid hsl(var(--border))", borderRadius: 8 }} />
        <Bar dataKey="count" name="人数" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}

function PassRatePieChart({ records }: { records: { totalScore: number | null; maxPossibleScore: number | null }[] }) {
  const graded = records.filter(r => r.totalScore != null);
  const passed = graded.filter(r => r.totalScore != null && r.maxPossibleScore != null && (r.totalScore / r.maxPossibleScore) >= 0.6).length;
  const failed = graded.length - passed;
  const data = [
    { name: "及格", value: passed },
    { name: "不及格", value: failed },
  ];
  return (
    <ResponsiveContainer width="100%" height={220}>
      <PieChart>
        <Pie data={data} cx="50%" cy="50%" innerRadius={55} outerRadius={85} paddingAngle={4} dataKey="value" label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`} labelLine={false}>
          {data.map((_, i) => <Cell key={i} fill={i === 0 ? "#10b981" : "#ef4444"} />)}
        </Pie>
        <Tooltip contentStyle={{ background: "hsl(var(--card))", border: "1px solid hsl(var(--border))", borderRadius: 8 }} />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
}

function ScoreTrendChart({ records }: { records: { submittedAt: Date | null; totalScore: number | null; studentName: string | null }[] }) {
  const sorted = [...records]
    .filter(r => r.submittedAt && r.totalScore != null)
    .sort((a, b) => new Date(a.submittedAt!).getTime() - new Date(b.submittedAt!).getTime())
    .map((r, i) => ({
      idx: i + 1,
      score: r.totalScore,
      name: r.studentName ?? "—",
    }));
  return (
    <ResponsiveContainer width="100%" height={220}>
      <AreaChart data={sorted} margin={{ top: 5, right: 10, left: -10, bottom: 5 }}>
        <defs>
          <linearGradient id="scoreGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="hsl(var(--primary))" stopOpacity={0.3} />
            <stop offset="95%" stopColor="hsl(var(--primary))" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
        <XAxis dataKey="idx" tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))" }} label={{ value: "提交顺序", position: "insideBottom", offset: -2, fontSize: 11 }} />
        <YAxis tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))" }} domain={[0, 100]} />
        <Tooltip contentStyle={{ background: "hsl(var(--card))", border: "1px solid hsl(var(--border))", borderRadius: 8 }}
          formatter={(v, _, p) => [`${v} 分`, p.payload.name]} />
        <Area type="monotone" dataKey="score" stroke="hsl(var(--primary))" fill="url(#scoreGrad)" strokeWidth={2} dot={{ r: 3 }} />
      </AreaChart>
    </ResponsiveContainer>
  );
}

export default function Reports() {
  const { data: exams } = trpc.exams.list.useQuery();
  const [selectedExam, setSelectedExam] = useState<string>("all");

  const examId = selectedExam === "all" ? undefined : Number(selectedExam);
  const { data: records } = trpc.exams.records.useQuery({ examId });
  const { data: stats } = trpc.exams.stats.useQuery({ examId: examId! }, { enabled: examId !== undefined });

  const gradedRecords = useMemo(() => (records ?? []).filter(r => r.totalScore != null), [records]);

  const avgScore = gradedRecords.length > 0
    ? (gradedRecords.reduce((s, r) => s + (r.totalScore ?? 0), 0) / gradedRecords.length).toFixed(1)
    : "—";

  const passRate = gradedRecords.length > 0
    ? ((gradedRecords.filter(r => r.totalScore != null && r.maxPossibleScore != null && r.totalScore / r.maxPossibleScore >= 0.6).length / gradedRecords.length) * 100).toFixed(1)
    : "—";

  function exportCSV() {
    if (!records || records.length === 0) { toast.error("暂无数据可导出"); return; }
    const header = ["学号", "姓名", "班级", "客户端用户名", "得分", "满分", "得分率", "用时(秒)", "状态", "提交时间"];
    const rows = records.map(r => [
      r.studentId ?? "",
      r.studentName ?? "",
      r.studentClass ?? "",
      r.clientUsername ?? "",
      r.totalScore ?? "",
      r.maxPossibleScore ?? "",
      r.totalScore != null && r.maxPossibleScore != null ? ((r.totalScore / r.maxPossibleScore) * 100).toFixed(1) + "%" : "",
      r.durationSeconds ?? "",
      r.status === "graded" ? "已评分" : r.status === "submitted" ? "待评分" : "进行中",
      r.submittedAt ? new Date(r.submittedAt).toLocaleString("zh-CN") : "",
    ]);
    const csv = [header, ...rows].map(row => row.map(v => `"${v}"`).join(",")).join("\n");
    const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url; a.download = `成绩报表_${new Date().toLocaleDateString("zh-CN")}.csv`; a.click();
    URL.revokeObjectURL(url);
    toast.success("CSV 文件已导出");
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-bold">成绩报表</h1>
            <p className="text-muted-foreground mt-1">可视化成绩分析，支持 CSV 导出</p>
          </div>
          <div className="flex items-center gap-3">
            <Select value={selectedExam} onValueChange={setSelectedExam}>
              <SelectTrigger className="w-52">
                <SelectValue placeholder="选择考试场次" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">全部考试</SelectItem>
                {(exams ?? []).map(e => <SelectItem key={e.id} value={String(e.id)}>{e.name}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button variant="outline" size="sm" onClick={exportCSV}>
              <Download className="h-4 w-4 mr-1.5" /> 导出 CSV
            </Button>
          </div>
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[
            { icon: Users, label: "参考人数", value: gradedRecords.length, color: "text-blue-600 bg-blue-50" },
            { icon: TrendingUp, label: "平均分", value: avgScore, color: "text-emerald-600 bg-emerald-50" },
            { icon: Award, label: "及格率", value: passRate !== "—" ? `${passRate}%` : "—", color: "text-amber-600 bg-amber-50" },
            { icon: BarChart3, label: "最高分", value: stats?.maxScore ?? (gradedRecords.length > 0 ? Math.max(...gradedRecords.map(r => r.totalScore!)) : "—"), color: "text-violet-600 bg-violet-50" },
          ].map(s => (
            <Card key={s.label} className="border-0 shadow-sm">
              <CardContent className="p-5">
                <div className="flex items-center gap-3">
                  <div className={`h-10 w-10 rounded-xl flex items-center justify-center ${s.color}`}>
                    <s.icon className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{s.label}</p>
                    <p className="text-2xl font-bold">{s.value}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          <Card className="border-0 shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">分数段分布</CardTitle>
            </CardHeader>
            <CardContent>
              {gradedRecords.length > 0 ? <ScoreDistributionChart records={gradedRecords} /> : (
                <div className="h-[220px] flex items-center justify-center text-muted-foreground text-sm">暂无数据</div>
              )}
            </CardContent>
          </Card>

          <Card className="border-0 shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">及格率分析</CardTitle>
            </CardHeader>
            <CardContent>
              {gradedRecords.length > 0 ? <PassRatePieChart records={gradedRecords} /> : (
                <div className="h-[220px] flex items-center justify-center text-muted-foreground text-sm">暂无数据</div>
              )}
            </CardContent>
          </Card>

          <Card className="border-0 shadow-sm md:col-span-2 xl:col-span-1">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">成绩提交趋势</CardTitle>
            </CardHeader>
            <CardContent>
              {gradedRecords.length > 0 ? <ScoreTrendChart records={gradedRecords} /> : (
                <div className="h-[220px] flex items-center justify-center text-muted-foreground text-sm">暂无数据</div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Detail Table */}
        <Card className="border-0 shadow-sm">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              成绩明细
              <Badge variant="secondary" className="ml-auto">{records?.length ?? 0} 条记录</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b bg-muted/30">
                    {["学号", "姓名", "班级", "客户端用户名", "得分", "得分率", "用时", "状态", "提交时间"].map(h => (
                      <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {(records ?? []).length === 0 ? (
                    <tr><td colSpan={9} className="text-center py-12 text-muted-foreground text-sm">暂无成绩记录</td></tr>
                  ) : (records ?? []).map(r => {
                    const rate = r.totalScore != null && r.maxPossibleScore != null
                      ? ((r.totalScore / r.maxPossibleScore) * 100).toFixed(1)
                      : null;
                    const isPassing = rate != null && Number(rate) >= 60;
                    return (
                      <tr key={r.id} className="border-b last:border-0 hover:bg-muted/20 transition-colors">
                        <td className="px-4 py-3 font-mono text-sm">{r.studentId ?? "—"}</td>
                        <td className="px-4 py-3 font-medium text-sm">{r.studentName ?? "—"}</td>
                        <td className="px-4 py-3 text-sm text-muted-foreground">{r.studentClass ?? "—"}</td>
                        <td className="px-4 py-3"><code className="text-xs bg-muted px-1 rounded">{r.clientUsername ?? "—"}</code></td>
                        <td className="px-4 py-3">
                          <span className="font-bold text-sm">
                            {r.totalScore ?? "—"}{r.maxPossibleScore != null ? ` / ${r.maxPossibleScore}` : ""}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          {rate != null ? (
                            <div className="flex items-center gap-2">
                              <div className="w-16 h-1.5 bg-muted rounded-full overflow-hidden">
                                <div className={`h-full rounded-full ${isPassing ? "bg-emerald-500" : "bg-red-400"}`} style={{ width: `${rate}%` }} />
                              </div>
                              <span className={`text-xs font-medium ${isPassing ? "text-emerald-600" : "text-red-500"}`}>{rate}%</span>
                            </div>
                          ) : "—"}
                        </td>
                        <td className="px-4 py-3 text-sm text-muted-foreground">
                          {r.durationSeconds ? `${Math.floor(r.durationSeconds / 60)}′${r.durationSeconds % 60}″` : "—"}
                        </td>
                        <td className="px-4 py-3">
                          <Badge variant="outline" className={
                            r.status === "graded" ? "badge-active border-emerald-200" :
                            r.status === "submitted" ? "badge-paused border-amber-200" :
                            "badge-draft border-slate-200"
                          }>
                            {r.status === "graded" ? "已评分" : r.status === "submitted" ? "待评分" : "进行中"}
                          </Badge>
                        </td>
                        <td className="px-4 py-3 text-xs text-muted-foreground">
                          {r.submittedAt ? new Date(r.submittedAt).toLocaleString("zh-CN") : "—"}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
