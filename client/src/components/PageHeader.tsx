import { Button } from "@/components/ui/button";
import { LayoutDashboard, Home } from "lucide-react";
import { useLocation } from "wouter";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

type PageHeaderProps = {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  showDashboardLink?: boolean;
};

const pageLabels: Record<string, string> = {
  "/dashboard": "控制台",
  "/questions": "题库管理",
  "/students": "学生管理",
  "/exams": "考试管理",
  "/scoring-rules": "评分规则",
  "/reports": "成绩报表",
};

export function PageHeader({
  title,
  description,
  actions,
  showDashboardLink = true,
}: PageHeaderProps) {
  const [location, setLocation] = useLocation();

  // 生成面包屑路径
  const breadcrumbs = location.split("/").filter(Boolean);

  return (
    <div className="flex flex-col gap-4 pb-6 border-b mb-6">
      {/* 面包屑导航 */}
      <div className="flex items-center justify-between">
        <Breadcrumb>
          <BreadcrumbList>
            <BreadcrumbItem>
              <BreadcrumbLink
                href="/dashboard"
                className="flex items-center gap-1"
              >
                <Home className="h-3.5 w-3.5" />
                <span>主页</span>
              </BreadcrumbLink>
            </BreadcrumbItem>

            {breadcrumbs.map((crumb, index) => {
              const path = "/" + breadcrumbs.slice(0, index + 1).join("/");
              const label = pageLabels[path] || crumb;
              const isLast = index === breadcrumbs.length - 1;

              return (
                <div key={path} className="flex items-center">
                  <BreadcrumbSeparator className="mx-2" />
                  <BreadcrumbItem>
                    {isLast ? (
                      <BreadcrumbPage>{label}</BreadcrumbPage>
                    ) : (
                      <BreadcrumbLink href={path}>{label}</BreadcrumbLink>
                    )}
                  </BreadcrumbItem>
                </div>
              );
            })}
          </BreadcrumbList>
        </Breadcrumb>

        {/* 快速返回 Dashboard 按钮 */}
        {showDashboardLink && location !== "/dashboard" && (
          <Button
            variant="outline"
            size="sm"
            onClick={() => setLocation("/dashboard")}
            className="gap-2"
          >
            <LayoutDashboard className="h-4 w-4" />
            <span className="hidden sm:inline">返回控制台</span>
          </Button>
        )}
      </div>

      {/* 页面标题和操作 */}
      <div className="flex items-center justify-between gap-4">
        <div className="flex-1 min-w-0">
          <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
          {description && (
            <p className="text-muted-foreground mt-1">{description}</p>
          )}
        </div>

        {actions && <div className="flex items-center gap-2 shrink-0">{actions}</div>}
      </div>
    </div>
  );
}
