import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { trpc } from "@/lib/trpc";
import { Plus, Play, Pause, Square, Eye, Clock, Users, BookOpen, BarChart2 } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

const STATUS_CONFIG = {
  draft:  { label: "草稿",   color: "badge-draft",  icon: Clock },
  active: { label: "进行中", color: "badge-active", icon: Play },
  paused: { label: "已暂停", color: "badge-paused", icon: Pause },
  ended:  { label: "已结束", color: "badge-ended",  icon: Square },
};

export default function Exams() {
  const utils = trpc.useUtils();
  const { data: exams, isLoading } = trpc.exams.list.useQuery();
  const createE = trpc.exams.create.useMutation({ onSuccess: () => { utils.exams.list.invalidate(); toast.success("考试已创建"); setShowForm(false); } });
  const updateE = trpc.exams.update.useMutation({ onSuccess: () => { utils.exams.list.invalidate(); toast.success("考试状态已更新"); } });

  const [showForm, setShowForm] = useState(false);
  const [selectedExam, setSelectedExam] = useState<number | null>(null);
  const [form, setForm] = useState({ name: "", description: "", durationMinutes: "120", questionCount: "9" });

  const { data: records } = trpc.exams.records.useQuery({ examId: selectedExam ?? undefined }, { enabled: selectedExam !== null });
  const { data: stats } = trpc.exams.stats.useQuery({ examId: selectedExam! }, { enabled: selectedExam !== null });

  function handleCreate() {
    if (!form.name.trim()) { toast.error("请填写考试名称"); return; }
    createE.mutate({ name: form.name, description: form.description || undefined, durationMinutes: Number(form.durationMinutes), questionCount: Number(form.questionCount) });
  }

  function changeStatus(id: number, status: "active" | "paused" | "ended") {
    updateE.mutate({ id, status });
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">考试管理</h1>
            <p className="text-muted-foreground mt-1">创建考试场次，控制考试状态，监控考试进度</p>
          </div>
          <Button size="sm" onClick={() => { setForm({ name: "", description: "", durationMinutes: "120", questionCount: "9" }); setShowForm(true); }}>
            <Plus className="h-4 w-4 mr-1.5" /> 创建考试
          </Button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Exam List */}
          <div className="lg:col-span-1 space-y-3">
            <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">考试列表</h2>
            {isLoading ? (
              <p className="text-sm text-muted-foreground">加载中...</p>
            ) : (exams ?? []).length === 0 ? (
              <Card className="border-0 shadow-sm">
                <CardContent className="py-10 text-center text-muted-foreground text-sm">暂无考试场次</CardContent>
              </Card>
            ) : (exams ?? []).map(exam => {
              const sc = STATUS_CONFIG[exam.status];
              const isSelected = selectedExam === exam.id;
              return (
                <Card key={exam.id}
                  className={`border-0 shadow-sm cursor-pointer transition-all ${isSelected ? "ring-2 ring-primary" : "hover:shadow-md"}`}
                  onClick={() => setSelectedExam(exam.id)}
                >
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="font-semibold text-sm truncate">{exam.name}</p>
                        <div className="flex items-center gap-3 mt-1.5 text-xs text-muted-foreground">
                          <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{exam.durationMinutes}分钟</span>
                          <span className="flex items-center gap-1"><BookOpen className="h-3 w-3" />{exam.questionCount}题</span>
                        </div>
                      </div>
                      <Badge variant="outline" className={`${sc.color} border-current/20 shrink-0`}>{sc.label}</Badge>
                    </div>
                    <div className="flex gap-1.5 mt-3">
                      {exam.status === "draft" && (
                        <Button size="sm" variant="outline" className="h-7 text-xs flex-1"
                          onClick={e => { e.stopPropagation(); changeStatus(exam.id, "active"); }}>
                          <Play className="h-3 w-3 mr-1" /> 开始
                        </Button>
                      )}
                      {exam.status === "active" && (
                        <>
                          <Button size="sm" variant="outline" className="h-7 text-xs flex-1"
                            onClick={e => { e.stopPropagation(); changeStatus(exam.id, "paused"); }}>
                            <Pause className="h-3 w-3 mr-1" /> 暂停
                          </Button>
                          <Button size="sm" variant="outline" className="h-7 text-xs flex-1 text-destructive hover:text-destructive"
                            onClick={e => { e.stopPropagation(); changeStatus(exam.id, "ended"); }}>
                            <Square className="h-3 w-3 mr-1" /> 结束
                          </Button>
                        </>
                      )}
                      {exam.status === "paused" && (
                        <>
                          <Button size="sm" variant="outline" className="h-7 text-xs flex-1"
                            onClick={e => { e.stopPropagation(); changeStatus(exam.id, "active"); }}>
                            <Play className="h-3 w-3 mr-1" /> 继续
                          </Button>
                          <Button size="sm" variant="outline" className="h-7 text-xs flex-1 text-destructive hover:text-destructive"
                            onClick={e => { e.stopPropagation(); changeStatus(exam.id, "ended"); }}>
                            <Square className="h-3 w-3 mr-1" /> 结束
                          </Button>
                        </>
                      )}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>

          {/* Exam Detail */}
          <div className="lg:col-span-2">
            {selectedExam === null ? (
              <Card className="border-0 shadow-sm h-full flex items-center justify-center">
                <CardContent className="text-center text-muted-foreground py-20">
                  <Eye className="h-10 w-10 mx-auto mb-3 opacity-20" />
                  <p>选择左侧考试场次查看详情</p>
                </CardContent>
              </Card>
            ) : (
              <div className="space-y-4">
                {/* Stats */}
                {stats && (
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {[
                      { label: "参考人数", value: stats.count ?? 0 },
                      { label: "平均分", value: stats.avgScore ? Number(stats.avgScore).toFixed(1) : "—" },
                      { label: "最高分", value: stats.maxScore ?? "—" },
                      { label: "及格人数", value: stats.passCount ?? 0 },
                    ].map(s => (
                      <Card key={s.label} className="border-0 shadow-sm">
                        <CardContent className="p-4 text-center">
                          <p className="text-2xl font-bold">{s.value}</p>
                          <p className="text-xs text-muted-foreground mt-1">{s.label}</p>
                        </CardContent>
                      </Card>
                    ))}
                  </div>
                )}

                {/* Records Table */}
                <Card className="border-0 shadow-sm">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-base flex items-center gap-2">
                      <Users className="h-4 w-4 text-primary" />
                      考试记录
                      <Badge variant="secondary" className="ml-auto">{records?.length ?? 0} 条</Badge>
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="p-0">
                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead>
                          <tr className="border-b bg-muted/30">
                            {["学生", "用户名", "得分", "用时", "状态", "提交时间"].map(h => (
                              <th key={h} className="text-left px-4 py-2.5 text-xs font-semibold text-muted-foreground">{h}</th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {(records ?? []).length === 0 ? (
                            <tr><td colSpan={6} className="text-center py-8 text-muted-foreground text-sm">暂无记录</td></tr>
                          ) : (records ?? []).map(r => (
                            <tr key={r.id} className="border-b last:border-0 hover:bg-muted/20">
                              <td className="px-4 py-3">
                                <p className="font-medium text-sm">{r.studentName}</p>
                                <p className="text-xs text-muted-foreground">{r.studentClass}</p>
                              </td>
                              <td className="px-4 py-3"><code className="text-xs bg-muted px-1 rounded">{r.clientUsername}</code></td>
                              <td className="px-4 py-3">
                                <span className="font-bold text-sm">
                                  {r.totalScore != null ? `${r.totalScore}` : "—"}
                                  {r.maxPossibleScore != null ? ` / ${r.maxPossibleScore}` : ""}
                                </span>
                              </td>
                              <td className="px-4 py-3 text-sm text-muted-foreground">
                                {r.durationSeconds ? `${Math.floor(r.durationSeconds / 60)}分${r.durationSeconds % 60}秒` : "—"}
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
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}
          </div>
        </div>
      </div>

      <Dialog open={showForm} onOpenChange={setShowForm}>
        <DialogContent className="max-w-md">
          <DialogHeader><DialogTitle>创建考试场次</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label>考试名称 *</Label>
              <Input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="2024年达梦数据库技能考试" />
            </div>
            <div className="space-y-1.5">
              <Label>考试说明</Label>
              <Textarea value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} placeholder="考试说明..." />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label>考试时长（分钟）</Label>
                <Input type="number" value={form.durationMinutes} onChange={e => setForm(f => ({ ...f, durationMinutes: e.target.value }))} min={1} />
              </div>
              <div className="space-y-1.5">
                <Label>抽题数量</Label>
                <Input type="number" value={form.questionCount} onChange={e => setForm(f => ({ ...f, questionCount: e.target.value }))} min={1} />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowForm(false)}>取消</Button>
            <Button onClick={handleCreate} disabled={createE.isPending}>创建考试</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
