import DashboardLayout from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";

type Exam = {
  id: number;
  name: string;
  description?: string | null;
  status: string;
  created_at: string;
};

type LiveEvent = {
  result_id: number;
  student_no: string;
  score: number;
  uploaded_at: string;
};

function toCsv(exams: Exam[]) {
  const header = ["id", "name", "status", "created_at"];
  const rows = exams.map(e => [e.id, `"${e.name.replaceAll('"', '""')}"`, e.status, e.created_at]);
  return [header.join(","), ...rows.map(r => r.join(","))].join("\n");
}

export default function ExamOpsCenter() {
  const [formName, setFormName] = useState("");
  const [formDescription, setFormDescription] = useState("");
  const [exams, setExams] = useState<Exam[]>([]);
  const [selectedExamId, setSelectedExamId] = useState<number | null>(null);
  const [events, setEvents] = useState<LiveEvent[]>([]);

  async function loadExams() {
    const resp = await fetch("/api/v1/exams");
    if (!resp.ok) {
      throw new Error("加载考试列表失败");
    }
    const data = (await resp.json()) as Exam[];
    setExams(data);
    if (data.length > 0 && selectedExamId === null) {
      setSelectedExamId(data[0].id);
    }
  }

  async function createExam() {
    if (!formName.trim()) {
      toast.error("考试名称不能为空");
      return;
    }
    const resp = await fetch("/api/v1/exams", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: formName, description: formDescription || undefined }),
    });
    if (!resp.ok) {
      toast.error("创建考试失败");
      return;
    }
    setFormName("");
    setFormDescription("");
    toast.success("考试已创建");
    await loadExams();
  }

  useEffect(() => {
    loadExams().catch(() => toast.error("无法连接 FastAPI 服务"));
  }, []);

  useEffect(() => {
    if (!selectedExamId) return;
    const wsProtocol = window.location.protocol === "https:" ? "wss" : "ws";
    const ws = new WebSocket(`${wsProtocol}://${window.location.host}/ws/status/${selectedExamId}`);
    ws.onmessage = event => {
      try {
        const parsed = JSON.parse(event.data) as LiveEvent;
        setEvents(prev => [parsed, ...prev].slice(0, 100));
      } catch {
        // ignore malformed payload
      }
    };
    return () => ws.close();
  }, [selectedExamId]);

  const stats = useMemo(() => {
    const total = events.length;
    const avg = total > 0 ? (events.reduce((sum, e) => sum + e.score, 0) / total).toFixed(1) : "0.0";
    return { total, avg };
  }, [events]);

  function exportCsv() {
    const csv = toCsv(exams);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `exam-summary-${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <PageHeader title="考试运营中心" description="FastAPI 考试管理、学生状态实时监控、成绩导出" />

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <Card className="border-0 shadow-sm lg:col-span-1">
            <CardHeader>
              <CardTitle className="text-base">创建考试</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-1.5">
                <Label>考试名称</Label>
                <Input value={formName} onChange={e => setFormName(e.target.value)} placeholder="达梦DM8实操考试" />
              </div>
              <div className="space-y-1.5">
                <Label>考试说明</Label>
                <Input value={formDescription} onChange={e => setFormDescription(e.target.value)} placeholder="可选" />
              </div>
              <Button onClick={createExam} className="w-full">创建并发布</Button>
            </CardContent>
          </Card>

          <Card className="border-0 shadow-sm lg:col-span-2">
            <CardHeader>
              <CardTitle className="text-base">考试列表与导出</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex gap-2">
                <Button variant="outline" onClick={() => loadExams().catch(() => toast.error("刷新失败"))}>刷新</Button>
                <Button variant="outline" onClick={exportCsv}>导出 CSV</Button>
              </div>
              <div className="space-y-2 max-h-64 overflow-auto">
                {exams.map(exam => (
                  <button
                    key={exam.id}
                    onClick={() => setSelectedExamId(exam.id)}
                    className={`w-full text-left rounded border p-3 ${selectedExamId === exam.id ? "border-primary" : "border-border"}`}
                  >
                    <p className="font-medium text-sm">{exam.name}</p>
                    <p className="text-xs text-muted-foreground">{exam.status} · {new Date(exam.created_at).toLocaleString("zh-CN")}</p>
                  </button>
                ))}
                {exams.length === 0 && <p className="text-sm text-muted-foreground">暂无考试</p>}
              </div>
            </CardContent>
          </Card>
        </div>

        <Card className="border-0 shadow-sm">
          <CardHeader>
            <CardTitle className="text-base">学生实时状态（WebSocket）</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div className="rounded border p-3">
                <p className="text-xs text-muted-foreground">当前考试</p>
                <p className="text-xl font-semibold">{selectedExamId ?? "-"}</p>
              </div>
              <div className="rounded border p-3">
                <p className="text-xs text-muted-foreground">上传次数</p>
                <p className="text-xl font-semibold">{stats.total}</p>
              </div>
              <div className="rounded border p-3">
                <p className="text-xs text-muted-foreground">平均分</p>
                <p className="text-xl font-semibold">{stats.avg}</p>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2">学生学号</th>
                    <th className="text-left py-2">分数</th>
                    <th className="text-left py-2">上传时间</th>
                  </tr>
                </thead>
                <tbody>
                  {events.length === 0 ? (
                    <tr><td className="py-4 text-muted-foreground" colSpan={3}>等待实时上报...</td></tr>
                  ) : events.map(item => (
                    <tr key={item.result_id} className="border-b last:border-0">
                      <td className="py-2">{item.student_no}</td>
                      <td className="py-2">{item.score}</td>
                      <td className="py-2">{new Date(item.uploaded_at).toLocaleString("zh-CN")}</td>
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
