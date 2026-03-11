import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { trpc } from "@/lib/trpc";
import { Plus, Pencil, Trash2, Search, BookOpen, Tag, Info } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

const DIFFICULTY_LABELS: Record<number, { label: string; color: string }> = {
  1: { label: "简单", color: "bg-emerald-100 text-emerald-700" },
  2: { label: "中等", color: "bg-amber-100 text-amber-700" },
  3: { label: "困难", color: "bg-red-100 text-red-700" },
};

export default function Questions() {
  const utils = trpc.useUtils();
  const { data: categories } = trpc.categories.list.useQuery();
  const { data: questions, isLoading } = trpc.questions.list.useQuery({});

  const createQ = trpc.questions.create.useMutation({ onSuccess: () => { utils.questions.list.invalidate(); toast.success("题目已创建"); setShowForm(false); } });
  const updateQ = trpc.questions.update.useMutation({ onSuccess: () => { utils.questions.list.invalidate(); toast.success("题目已更新"); setShowForm(false); } });
  const deleteQ = trpc.questions.delete.useMutation({ onSuccess: () => { utils.questions.list.invalidate(); toast.success("题目已删除"); setDeleteId(null); } });
  const createCat = trpc.categories.create.useMutation({ onSuccess: () => { utils.categories.list.invalidate(); toast.success("分类已创建"); setShowCatForm(false); } });

  const [search, setSearch] = useState("");
  const [filterCat, setFilterCat] = useState<string>("all");
  const [showForm, setShowForm] = useState(false);
  const [showCatForm, setShowCatForm] = useState(false);
  const [deleteId, setDeleteId] = useState<number | null>(null);
  type Question = NonNullable<typeof questions>[number];
  const [editing, setEditing] = useState<Question | null>(null);
  const [form, setForm] = useState({ title: "", content: "", categoryId: "", difficulty: "2", maxScore: "10", sortOrder: "0" });
  const [catForm, setCatForm] = useState({ name: "", description: "" });

  const filtered = (questions ?? []).filter(q => {
    const matchSearch = !search || q.title.toLowerCase().includes(search.toLowerCase());
    const matchCat = filterCat === "all" || String(q.categoryId) === filterCat;
    return matchSearch && matchCat;
  });

  function openCreate() {
    setEditing(null);
    setForm({ title: "", content: "", categoryId: "", difficulty: "2", maxScore: "10", sortOrder: "0" });
    setShowForm(true);
  }

  function openEdit(q: NonNullable<typeof questions>[number]) {
    setEditing(q);
    setForm({ title: q.title, content: q.content, categoryId: String(q.categoryId ?? ""), difficulty: String(q.difficulty), maxScore: String(q.maxScore), sortOrder: String(q.sortOrder) });
    setShowForm(true);
  }

  function handleSubmit() {
    if (!form.title.trim() || !form.content.trim()) { toast.error("请填写题目标题和内容"); return; }
    const payload = { title: form.title, content: form.content, categoryId: form.categoryId ? Number(form.categoryId) : undefined, difficulty: Number(form.difficulty), maxScore: Number(form.maxScore), sortOrder: Number(form.sortOrder) };
    if (editing) updateQ.mutate({ id: editing.id, ...payload });
    else createQ.mutate(payload);
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">题库管理</h1>
            <p className="text-muted-foreground mt-1">管理考试题目，支持用户名占位符 <code className="bg-muted px-1 rounded text-xs">{"{{username}}"}</code></p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={() => setShowCatForm(true)}>
              <Tag className="h-4 w-4 mr-1.5" /> 管理分类
            </Button>
            <Button size="sm" onClick={openCreate}>
              <Plus className="h-4 w-4 mr-1.5" /> 添加题目
            </Button>
          </div>
        </div>

        {/* Filters */}
        <div className="flex gap-3 flex-wrap">
          <div className="relative flex-1 min-w-48">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input placeholder="搜索题目..." className="pl-9" value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <Select value={filterCat} onValueChange={setFilterCat}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="全部分类" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">全部分类</SelectItem>
              {(categories ?? []).map(c => <SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>

        {/* Table */}
        <Card className="border-0 shadow-sm">
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b bg-muted/30">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">题目标题</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">分类</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">难度</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">分值</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">状态</th>
                    <th className="text-right px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">操作</th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr><td colSpan={6} className="text-center py-12 text-muted-foreground">加载中...</td></tr>
                  ) : filtered.length === 0 ? (
                    <tr><td colSpan={6} className="text-center py-12 text-muted-foreground">
                      <BookOpen className="h-8 w-8 mx-auto mb-2 opacity-30" />
                      暂无题目
                    </td></tr>
                  ) : filtered.map(q => (
                    <tr key={q.id} className="border-b last:border-0 hover:bg-muted/20 transition-colors">
                      <td className="px-4 py-3">
                        <p className="font-medium text-sm">{q.title}</p>
                        <p className="text-xs text-muted-foreground mt-0.5 line-clamp-1">{q.content.substring(0, 60)}...</p>
                      </td>
                      <td className="px-4 py-3">
                        <span className="text-sm text-muted-foreground">{q.categoryName ?? "未分类"}</span>
                      </td>
                      <td className="px-4 py-3">
                        <Badge variant="secondary" className={DIFFICULTY_LABELS[q.difficulty]?.color}>
                          {DIFFICULTY_LABELS[q.difficulty]?.label}
                        </Badge>
                      </td>
                      <td className="px-4 py-3">
                        <span className="font-semibold text-sm">{q.maxScore} 分</span>
                      </td>
                      <td className="px-4 py-3">
                        <Badge variant={q.isActive ? "default" : "secondary"}>
                          {q.isActive ? "启用" : "禁用"}
                        </Badge>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex justify-end gap-1">
                          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openEdit(q)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8 text-destructive hover:text-destructive" onClick={() => setDeleteId(q.id)}>
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Question Form Dialog */}
      <Dialog open={showForm} onOpenChange={setShowForm}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{editing ? "编辑题目" : "添加题目"}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg flex gap-2 text-sm text-blue-700 dark:text-blue-300">
              <Info className="h-4 w-4 shrink-0 mt-0.5" />
              <span>题目内容中可使用 <code className="bg-blue-100 dark:bg-blue-800 px-1 rounded">{"{{username}}"}</code> 作为学生用户名占位符，系统会自动替换为客户端实际用户名。</span>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2 space-y-1.5">
                <Label>题目标题 *</Label>
                <Input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="例：第1题：数据库卸载" />
              </div>
              <div className="space-y-1.5">
                <Label>题目分类</Label>
                <Select value={form.categoryId} onValueChange={v => setForm(f => ({ ...f, categoryId: v }))}>
                  <SelectTrigger><SelectValue placeholder="选择分类" /></SelectTrigger>
                  <SelectContent>
                    {(categories ?? []).map(c => <SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>难度</Label>
                <Select value={form.difficulty} onValueChange={v => setForm(f => ({ ...f, difficulty: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">简单</SelectItem>
                    <SelectItem value="2">中等</SelectItem>
                    <SelectItem value="3">困难</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>满分分值</Label>
                <Input type="number" value={form.maxScore} onChange={e => setForm(f => ({ ...f, maxScore: e.target.value }))} min={1} />
              </div>
              <div className="space-y-1.5">
                <Label>排序序号</Label>
                <Input type="number" value={form.sortOrder} onChange={e => setForm(f => ({ ...f, sortOrder: e.target.value }))} min={0} />
              </div>
              <div className="col-span-2 space-y-1.5">
                <Label>题目内容 *</Label>
                <Textarea value={form.content} onChange={e => setForm(f => ({ ...f, content: e.target.value }))}
                  placeholder={"请在用户 {{username}} 的机器上完成以下操作：\n1. 卸载现有的达梦数据库软件\n2. ..."}
                  className="min-h-32 font-mono text-sm" />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowForm(false)}>取消</Button>
            <Button onClick={handleSubmit} disabled={createQ.isPending || updateQ.isPending}>
              {editing ? "保存修改" : "创建题目"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Category Form Dialog */}
      <Dialog open={showCatForm} onOpenChange={setShowCatForm}>
        <DialogContent className="max-w-md">
          <DialogHeader><DialogTitle>添加题目分类</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label>分类名称 *</Label>
              <Input value={catForm.name} onChange={e => setCatForm(f => ({ ...f, name: e.target.value }))} placeholder="例：数据库安装" />
            </div>
            <div className="space-y-1.5">
              <Label>描述</Label>
              <Textarea value={catForm.description} onChange={e => setCatForm(f => ({ ...f, description: e.target.value }))} placeholder="分类说明..." />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCatForm(false)}>取消</Button>
            <Button onClick={() => { if (!catForm.name.trim()) { toast.error("请输入分类名称"); return; } createCat.mutate(catForm); }} disabled={createCat.isPending}>
              创建分类
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirm */}
      <AlertDialog open={deleteId !== null} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>确认删除</AlertDialogTitle>
            <AlertDialogDescription>此操作将永久删除该题目，无法恢复。</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction className="bg-destructive text-white hover:bg-destructive/90"
              onClick={() => deleteId !== null && deleteQ.mutate({ id: deleteId })}>
              确认删除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </DashboardLayout>
  );
}
