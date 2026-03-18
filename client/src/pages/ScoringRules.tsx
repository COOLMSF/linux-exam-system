import DashboardLayout from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { trpc } from "@/lib/trpc";
import { Plus, Pencil, Trash2, Code2, Settings2, ChevronDown, ChevronRight, Copy, Check } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

const CHECK_TYPE_LABELS: Record<string, { label: string; color: string }> = {
  file_exists:    { label: "文件存在",   color: "bg-blue-100 text-blue-700" },
  file_not_exists:{ label: "文件不存在", color: "bg-orange-100 text-orange-700" },
  command_output: { label: "命令输出",   color: "bg-violet-100 text-violet-700" },
  db_query:       { label: "数据库查询", color: "bg-emerald-100 text-emerald-700" },
  custom_script:  { label: "自定义脚本", color: "bg-slate-100 text-slate-700" },
};

export default function ScoringRules() {
  const utils = trpc.useUtils();
  const { data: questions } = trpc.questions.list.useQuery({});
  const { data: rules } = trpc.scoringRules.list.useQuery();

  const createRule = trpc.scoringRules.createRule.useMutation({ onSuccess: () => { utils.scoringRules.list.invalidate(); toast.success("规则已创建"); setShowRuleForm(false); } });
  const deleteRule = trpc.scoringRules.deleteRule.useMutation({ onSuccess: () => { utils.scoringRules.list.invalidate(); toast.success("规则已删除"); setSelectedRule(null); } });
  const createItem = trpc.scoringRules.createCheckItem.useMutation({ onSuccess: () => { utils.scoringRules.getCheckItems.invalidate(); toast.success("检查项已添加"); setShowItemForm(false); } });
  const deleteItem = trpc.scoringRules.deleteCheckItem.useMutation({ onSuccess: () => utils.scoringRules.getCheckItems.invalidate() });

  const [selectedRule, setSelectedRule] = useState<number | null>(null);
  const [showRuleForm, setShowRuleForm] = useState(false);
  const [showItemForm, setShowItemForm] = useState(false);
  const [showScript, setShowScript] = useState(false);
  const [copied, setCopied] = useState(false);
  const [ruleForm, setRuleForm] = useState({ questionId: "", name: "", description: "", initialScore: "10" });
  const [itemForm, setItemForm] = useState({ description: "", checkType: "file_exists", checkTarget: "", expectedValue: "", compareOperator: "eq", deductionPoints: "1", failMessage: "", sortOrder: "0" });

  const { data: checkItems } = trpc.scoringRules.getCheckItems.useQuery({ ruleId: selectedRule! }, { enabled: selectedRule !== null });
  const { data: scriptData } = trpc.scoringRules.generateScript.useQuery(
    { questionId: rules?.find(r => r.id === selectedRule)?.questionId ?? 0 },
    { enabled: selectedRule !== null && showScript }
  );

  function handleCreateRule() {
    if (!ruleForm.questionId || !ruleForm.name) { toast.error("请填写必填项"); return; }
    createRule.mutate({ questionId: Number(ruleForm.questionId), name: ruleForm.name, description: ruleForm.description || undefined, initialScore: Number(ruleForm.initialScore) });
  }

  function handleCreateItem() {
    if (!selectedRule || !itemForm.description || !itemForm.checkTarget) { toast.error("请填写必填项"); return; }
    createItem.mutate({ ruleId: selectedRule, description: itemForm.description, checkType: itemForm.checkType as never, checkTarget: itemForm.checkTarget, expectedValue: itemForm.expectedValue || undefined, compareOperator: itemForm.compareOperator as never, deductionPoints: Number(itemForm.deductionPoints), failMessage: itemForm.failMessage || undefined, sortOrder: Number(itemForm.sortOrder) });
  }

  function copyScript() {
    if (scriptData) { navigator.clipboard.writeText(scriptData); setCopied(true); setTimeout(() => setCopied(false), 2000); }
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <PageHeader
          title="评分规则配置"
          description="可视化配置评分标准，自动生成 Shell 评分脚本"
          actions={
            <Button size="sm" onClick={() => { setRuleForm({ questionId: "", name: "", description: "", initialScore: "10" }); setShowRuleForm(true); }}>
              <Plus className="h-4 w-4 mr-1.5" /> 新建规则
            </Button>
          }
        />

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Rules List */}
          <div className="space-y-3">
            <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">评分规则</h2>
            {(rules ?? []).map(rule => {
              const q = questions?.find(q => q.id === rule.questionId);
              return (
                <Card key={rule.id}
                  className={`border-0 shadow-sm cursor-pointer transition-all ${selectedRule === rule.id ? "ring-2 ring-primary" : "hover:shadow-md"}`}
                  onClick={() => setSelectedRule(rule.id)}
                >
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between">
                      <div className="min-w-0">
                        <p className="font-semibold text-sm truncate">{rule.name}</p>
                        <p className="text-xs text-muted-foreground mt-0.5 truncate">{q?.title ?? "未关联题目"}</p>
                      </div>
                      <Badge variant="secondary" className="shrink-0 ml-2">{rule.initialScore}分</Badge>
                    </div>
                    <Button variant="ghost" size="sm" className="mt-2 h-7 text-xs text-destructive hover:text-destructive w-full"
                      onClick={e => { e.stopPropagation(); deleteRule.mutate({ id: rule.id }); }}>
                      <Trash2 className="h-3 w-3 mr-1" /> 删除规则
                    </Button>
                  </CardContent>
                </Card>
              );
            })}
            {(rules ?? []).length === 0 && (
              <Card className="border-0 shadow-sm">
                <CardContent className="py-10 text-center text-muted-foreground text-sm">
                  <Settings2 className="h-8 w-8 mx-auto mb-2 opacity-20" />
                  暂无评分规则
                </CardContent>
              </Card>
            )}
          </div>

          {/* Check Items */}
          <div className="lg:col-span-2 space-y-4">
            {selectedRule === null ? (
              <Card className="border-0 shadow-sm h-64 flex items-center justify-center">
                <CardContent className="text-center text-muted-foreground">
                  <Settings2 className="h-10 w-10 mx-auto mb-3 opacity-20" />
                  <p>选择左侧规则查看检查项</p>
                </CardContent>
              </Card>
            ) : (
              <>
                <div className="flex items-center justify-between">
                  <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">检查项配置</h2>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" onClick={() => setShowScript(!showScript)}>
                      <Code2 className="h-4 w-4 mr-1.5" /> {showScript ? "隐藏脚本" : "查看脚本"}
                    </Button>
                    <Button size="sm" onClick={() => { setItemForm({ description: "", checkType: "file_exists", checkTarget: "", expectedValue: "", compareOperator: "eq", deductionPoints: "1", failMessage: "", sortOrder: String((checkItems?.length ?? 0)) }); setShowItemForm(true); }}>
                      <Plus className="h-4 w-4 mr-1.5" /> 添加检查项
                    </Button>
                  </div>
                </div>

                {/* Script Preview */}
                {showScript && scriptData && (
                  <Card className="border-0 shadow-sm bg-slate-900">
                    <CardHeader className="pb-2 flex-row items-center justify-between">
                      <CardTitle className="text-sm text-slate-300 font-mono">生成的 Shell 评分脚本</CardTitle>
                      <Button variant="ghost" size="sm" className="h-7 text-slate-400 hover:text-white" onClick={copyScript}>
                        {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
                      </Button>
                    </CardHeader>
                    <CardContent className="pt-0">
                      <pre className="text-xs text-slate-300 overflow-x-auto max-h-64 font-mono leading-relaxed">{scriptData}</pre>
                    </CardContent>
                  </Card>
                )}

                {/* Check Items List */}
                <div className="space-y-2">
                  {(checkItems ?? []).length === 0 ? (
                    <Card className="border-0 shadow-sm">
                      <CardContent className="py-8 text-center text-muted-foreground text-sm">暂无检查项，点击"添加检查项"开始配置</CardContent>
                    </Card>
                  ) : (checkItems ?? []).map((item, idx) => {
                    const ct = CHECK_TYPE_LABELS[item.checkType];
                    return (
                      <Card key={item.id} className="border-0 shadow-sm">
                        <CardContent className="p-4">
                          <div className="flex items-start justify-between gap-3">
                            <div className="flex items-start gap-3 min-w-0">
                              <span className="text-xs font-mono text-muted-foreground mt-0.5 shrink-0">#{idx + 1}</span>
                              <div className="min-w-0">
                                <div className="flex items-center gap-2 flex-wrap">
                                  <p className="font-medium text-sm">{item.description}</p>
                                  <Badge variant="secondary" className={ct?.color}>{ct?.label}</Badge>
                                  <Badge variant="outline" className="text-destructive border-destructive/30">-{item.deductionPoints}分</Badge>
                                </div>
                                <code className="text-xs text-muted-foreground mt-1 block truncate">{item.checkTarget}</code>
                                {item.expectedValue && (
                                  <p className="text-xs text-muted-foreground mt-0.5">期望值: <code className="bg-muted px-1 rounded">{item.expectedValue}</code></p>
                                )}
                                {item.failMessage && (
                                  <p className="text-xs text-amber-600 mt-0.5">失败提示: {item.failMessage}</p>
                                )}
                              </div>
                            </div>
                            <Button variant="ghost" size="icon" className="h-7 w-7 text-destructive hover:text-destructive shrink-0"
                              onClick={() => deleteItem.mutate({ id: item.id })}>
                              <Trash2 className="h-3.5 w-3.5" />
                            </Button>
                          </div>
                        </CardContent>
                      </Card>
                    );
                  })}
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Rule Form */}
      <Dialog open={showRuleForm} onOpenChange={setShowRuleForm}>
        <DialogContent className="max-w-md">
          <DialogHeader><DialogTitle>新建评分规则</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label>关联题目 *</Label>
              <Select value={ruleForm.questionId} onValueChange={v => setRuleForm(f => ({ ...f, questionId: v }))}>
                <SelectTrigger><SelectValue placeholder="选择题目" /></SelectTrigger>
                <SelectContent>
                  {(questions ?? []).map(q => <SelectItem key={q.id} value={String(q.id)}>{q.title}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>规则名称 *</Label>
              <Input value={ruleForm.name} onChange={e => setRuleForm(f => ({ ...f, name: e.target.value }))} placeholder="第1题评分规则" />
            </div>
            <div className="space-y-1.5">
              <Label>初始满分</Label>
              <Input type="number" value={ruleForm.initialScore} onChange={e => setRuleForm(f => ({ ...f, initialScore: e.target.value }))} min={0} />
            </div>
            <div className="space-y-1.5">
              <Label>规则说明</Label>
              <Textarea value={ruleForm.description} onChange={e => setRuleForm(f => ({ ...f, description: e.target.value }))} placeholder="规则说明..." />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowRuleForm(false)}>取消</Button>
            <Button onClick={handleCreateRule} disabled={createRule.isPending}>创建规则</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Check Item Form */}
      <Dialog open={showItemForm} onOpenChange={setShowItemForm}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader><DialogTitle>添加检查项</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label>检查描述 *</Label>
              <Input value={itemForm.description} onChange={e => setItemForm(f => ({ ...f, description: e.target.value }))} placeholder="数据库软件未成功卸载" />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label>检查类型 *</Label>
                <Select value={itemForm.checkType} onValueChange={v => setItemForm(f => ({ ...f, checkType: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="file_exists">文件存在</SelectItem>
                    <SelectItem value="file_not_exists">文件不存在</SelectItem>
                    <SelectItem value="command_output">命令输出</SelectItem>
                    <SelectItem value="db_query">数据库查询</SelectItem>
                    <SelectItem value="custom_script">自定义脚本</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>扣分分值</Label>
                <Input type="number" value={itemForm.deductionPoints} onChange={e => setItemForm(f => ({ ...f, deductionPoints: e.target.value }))} min={0} />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label>检查目标 *</Label>
              <Textarea value={itemForm.checkTarget} onChange={e => setItemForm(f => ({ ...f, checkTarget: e.target.value }))}
                placeholder={
                  itemForm.checkType === "file_exists" ? "/home/dmdba/dmdbms/jar" :
                  itemForm.checkType === "command_output" ? "echo $DBNAME" :
                  itemForm.checkType === "db_query" ? "/var/local/sc/rw_dbname.sql" :
                  "自定义 Shell 脚本内容..."
                }
                className="font-mono text-sm min-h-20" />
            </div>
            {(itemForm.checkType === "command_output" || itemForm.checkType === "db_query") && (
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label>期望值</Label>
                  <Input value={itemForm.expectedValue} onChange={e => setItemForm(f => ({ ...f, expectedValue: e.target.value }))} placeholder="DAMENG" />
                </div>
                <div className="space-y-1.5">
                  <Label>比较方式</Label>
                  <Select value={itemForm.compareOperator} onValueChange={v => setItemForm(f => ({ ...f, compareOperator: v }))}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="eq">等于 (=)</SelectItem>
                      <SelectItem value="ne">不等于 (≠)</SelectItem>
                      <SelectItem value="contains">包含</SelectItem>
                      <SelectItem value="gt">大于 (&gt;)</SelectItem>
                      <SelectItem value="lt">小于 (&lt;)</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            )}
            <div className="space-y-1.5">
              <Label>失败提示信息</Label>
              <Input value={itemForm.failMessage} onChange={e => setItemForm(f => ({ ...f, failMessage: e.target.value }))} placeholder="数据库软件未成功卸载:-4" />
            </div>
            <div className="space-y-1.5">
              <Label>排序序号</Label>
              <Input type="number" value={itemForm.sortOrder} onChange={e => setItemForm(f => ({ ...f, sortOrder: e.target.value }))} min={0} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowItemForm(false)}>取消</Button>
            <Button onClick={handleCreateItem} disabled={createItem.isPending}>添加检查项</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
