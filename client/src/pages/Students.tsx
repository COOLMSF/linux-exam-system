import DashboardLayout from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { trpc } from "@/lib/trpc";
import { Plus, Pencil, Trash2, Search, Users, Key, Monitor, KeyRound, Eye, EyeOff } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

export default function Students() {
  const utils = trpc.useUtils();
  const { data: students, isLoading } = trpc.students.list.useQuery({});
  const createS = trpc.students.create.useMutation({ onSuccess: () => { utils.students.list.invalidate(); toast.success("学生已添加"); setShowForm(false); } });
  const updateS = trpc.students.update.useMutation({ onSuccess: () => { utils.students.list.invalidate(); toast.success("信息已更新"); setShowForm(false); } });
  const deleteS = trpc.students.delete.useMutation({ onSuccess: () => { utils.students.list.invalidate(); toast.success("学生已删除"); setDeleteId(null); } });

  const setPasswordMutation = trpc.students.setPassword.useMutation({
    onSuccess: () => { toast.success("密码设置成功"); setPwdTarget(null); setPwdValue(""); },
    onError: (err) => toast.error(err.message || "设置失败"),
  });

  const [search, setSearch] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [deleteId, setDeleteId] = useState<number | null>(null);
  const [pwdTarget, setPwdTarget] = useState<{ studentId: string; name: string } | null>(null);
  const [pwdValue, setPwdValue] = useState("");
  const [showPwdValue, setShowPwdValue] = useState(false);
  type Student = NonNullable<typeof students>[number];
  const [editing, setEditing] = useState<Student | null>(null);
  const [form, setForm] = useState({ studentId: "", name: "", className: "", department: "", clientUsername: "", password: "" });

  const filtered = (students ?? []).filter(s =>
    !search || s.name.toLowerCase().includes(search.toLowerCase()) ||
    s.studentId.toLowerCase().includes(search.toLowerCase())
  );

  function openCreate() {
    setEditing(null);
    setForm({ studentId: "", name: "", className: "", department: "", clientUsername: "", password: "" });
    setShowForm(true);
  }

  function openEdit(s: Student) {
    setEditing(s);
    setForm({ studentId: s.studentId, name: s.name, className: s.className ?? "", department: s.department ?? "", clientUsername: s.clientUsername ?? "", password: "" });
    setShowForm(true);
  }

  function handleSubmit() {
    if (!form.studentId.trim() || !form.name.trim()) { toast.error("请填写学号和姓名"); return; }
    if (editing) {
      updateS.mutate({ id: editing.id, name: form.name, className: form.className || undefined, department: form.department || undefined, clientUsername: form.clientUsername || undefined });
    } else {
      if (!form.password || form.password.length < 6) { toast.error("请设置密码（至少 6 位）"); return; }
      createS.mutate({ studentId: form.studentId, name: form.name, className: form.className || undefined, department: form.department || undefined, clientUsername: form.clientUsername || undefined, password: form.password });
    }
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <PageHeader
          title="学生管理"
          description="管理考生信息与设备绑定"
          actions={
            <Button size="sm" onClick={openCreate}>
              <Plus className="h-4 w-4 mr-1.5" /> 添加学生
            </Button>
          }
        />

        <div className="relative max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input placeholder="搜索姓名或学号..." className="pl-9" value={search} onChange={e => setSearch(e.target.value)} />
        </div>

        <Card className="border-0 shadow-sm">
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b bg-muted/30">
                    {["学号", "姓名", "班级", "部门", "客户端用户名", "设备绑定", "Token状态", "操作"].map(h => (
                      <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr><td colSpan={8} className="text-center py-12 text-muted-foreground">加载中...</td></tr>
                  ) : filtered.length === 0 ? (
                    <tr><td colSpan={8} className="text-center py-12 text-muted-foreground">
                      <Users className="h-8 w-8 mx-auto mb-2 opacity-30" />暂无学生
                    </td></tr>
                  ) : filtered.map(s => (
                    <tr key={s.id} className="border-b last:border-0 hover:bg-muted/20 transition-colors">
                      <td className="px-4 py-3 font-mono text-sm">{s.studentId}</td>
                      <td className="px-4 py-3 font-medium text-sm">{s.name}</td>
                      <td className="px-4 py-3 text-sm text-muted-foreground">{s.className ?? "—"}</td>
                      <td className="px-4 py-3 text-sm text-muted-foreground">{s.department ?? "—"}</td>
                      <td className="px-4 py-3">
                        {s.clientUsername ? (
                          <code className="text-xs bg-muted px-1.5 py-0.5 rounded">{s.clientUsername}</code>
                        ) : <span className="text-muted-foreground text-sm">未采集</span>}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1.5">
                          <Monitor className={`h-3.5 w-3.5 ${s.deviceId ? "text-emerald-500" : "text-muted-foreground"}`} />
                          <span className="text-xs text-muted-foreground">{s.deviceId ? "已绑定" : "未绑定"}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1.5">
                          <Key className={`h-3.5 w-3.5 ${s.apiToken && s.tokenExpiresAt && new Date(s.tokenExpiresAt) > new Date() ? "text-emerald-500" : "text-muted-foreground"}`} />
                          <span className="text-xs text-muted-foreground">
                            {s.apiToken && s.tokenExpiresAt && new Date(s.tokenExpiresAt) > new Date() ? "有效" : "无效"}
                          </span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex gap-1">
                          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openEdit(s)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8" title="设置密码" onClick={() => { setPwdTarget({ studentId: s.studentId, name: s.name }); setPwdValue(""); setShowPwdValue(false); }}>
                            <KeyRound className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8 text-destructive hover:text-destructive" onClick={() => setDeleteId(s.id)}>
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

      <Dialog open={showForm} onOpenChange={setShowForm}>
        <DialogContent className="max-w-md">
          <DialogHeader><DialogTitle>{editing ? "编辑学生" : "添加学生"}</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label>学号 *</Label>
                <Input value={form.studentId} onChange={e => setForm(f => ({ ...f, studentId: e.target.value }))} disabled={!!editing} placeholder="S20240001" />
              </div>
              <div className="space-y-1.5">
                <Label>姓名 *</Label>
                <Input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="张三" />
              </div>
              <div className="space-y-1.5">
                <Label>班级</Label>
                <Input value={form.className} onChange={e => setForm(f => ({ ...f, className: e.target.value }))} placeholder="2024级1班" />
              </div>
              <div className="space-y-1.5">
                <Label>部门/院系</Label>
                <Input value={form.department} onChange={e => setForm(f => ({ ...f, department: e.target.value }))} placeholder="计算机学院" />
              </div>
              <div className="col-span-2 space-y-1.5">
                <Label>客户端用户名（预设）</Label>
                <Input value={form.clientUsername} onChange={e => setForm(f => ({ ...f, clientUsername: e.target.value }))} placeholder="student01（可由客户端自动采集）" />
              </div>
              {!editing && (
                <div className="col-span-2 space-y-1.5">
                  <Label>Web 登录密码 * <span className="text-muted-foreground font-normal">（至少 6 位）</span></Label>
                  <Input type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} placeholder="设置后学生可登录 Web 端查看成绩" />
                </div>
              )}
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowForm(false)}>取消</Button>
            <Button onClick={handleSubmit} disabled={createS.isPending || updateS.isPending}>
              {editing ? "保存" : "添加"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Set Password Dialog */}
      <Dialog open={pwdTarget !== null} onOpenChange={(v) => { if (!v) setPwdTarget(null); }}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><KeyRound className="h-4 w-4" />设置学生密码</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">为 <span className="font-medium text-foreground">{pwdTarget?.name}</span>（{pwdTarget?.studentId}）设置 Web 登录密码</p>
            <div className="space-y-1.5">
              <Label>新密码 <span className="text-muted-foreground font-normal">（至少 6 位）</span></Label>
              <div className="relative">
                <Input
                  type={showPwdValue ? "text" : "password"}
                  value={pwdValue}
                  onChange={e => setPwdValue(e.target.value)}
                  placeholder="请输入密码"
                  minLength={6}
                />
                <button type="button" tabIndex={-1} className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground" onClick={() => setShowPwdValue(!showPwdValue)}>
                  {showPwdValue ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPwdTarget(null)}>取消</Button>
            <Button
              disabled={pwdValue.length < 6 || setPasswordMutation.isPending}
              onClick={() => pwdTarget && setPasswordMutation.mutate({ studentId: pwdTarget.studentId, password: pwdValue })}
            >
              {setPasswordMutation.isPending ? "设置中..." : "确认设置"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <AlertDialog open={deleteId !== null} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>确认删除</AlertDialogTitle>
            <AlertDialogDescription>此操作将永久删除该学生及其所有考试记录。</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction className="bg-destructive text-white hover:bg-destructive/90"
              onClick={() => deleteId !== null && deleteS.mutate({ id: deleteId })}>
              确认删除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </DashboardLayout>
  );
}
