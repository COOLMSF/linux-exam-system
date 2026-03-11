import { describe, expect, it, vi, beforeEach } from "vitest";
import { appRouter } from "./routers";
import type { TrpcContext } from "./_core/context";

// ─── Mock DB helpers ──────────────────────────────────────────────────────────
vi.mock("./db", () => ({
  getDb: vi.fn().mockResolvedValue(null),
  upsertUser: vi.fn().mockResolvedValue(undefined),
  getUserByOpenId: vi.fn().mockResolvedValue(null),
  listStudents: vi.fn().mockResolvedValue([]),
  createStudent: vi.fn().mockResolvedValue({ id: 1, studentId: "S001", name: "张三" }),
  updateStudent: vi.fn().mockResolvedValue(undefined),
  deleteStudent: vi.fn().mockResolvedValue(undefined),
  getStudentByStudentId: vi.fn().mockResolvedValue(null),
  getStudentByToken: vi.fn().mockResolvedValue(null),
  listCategories: vi.fn().mockResolvedValue([]),
  createCategory: vi.fn().mockResolvedValue({ id: 1, name: "达梦数据库" }),
  updateCategory: vi.fn().mockResolvedValue(undefined),
  deleteCategory: vi.fn().mockResolvedValue(undefined),
  listQuestions: vi.fn().mockResolvedValue([]),
  createQuestion: vi.fn().mockResolvedValue({ id: 1, title: "数据库安装题" }),
  updateQuestion: vi.fn().mockResolvedValue(undefined),
  deleteQuestion: vi.fn().mockResolvedValue(undefined),
  listScoringRules: vi.fn().mockResolvedValue([]),
  getScoringRuleByQuestion: vi.fn().mockResolvedValue(null),
  createScoringRule: vi.fn().mockResolvedValue({ id: 1, name: "安装评分规则", initialScore: 10 }),
  updateScoringRule: vi.fn().mockResolvedValue(undefined),
  deleteScoringRule: vi.fn().mockResolvedValue(undefined),
  listCheckItemsByRule: vi.fn().mockResolvedValue([]),
  createCheckItem: vi.fn().mockResolvedValue({ id: 1, description: "检查安装目录" }),
  updateCheckItem: vi.fn().mockResolvedValue(undefined),
  deleteCheckItem: vi.fn().mockResolvedValue(undefined),
  listExamSessions: vi.fn().mockResolvedValue([]),
  getExamSessionById: vi.fn().mockResolvedValue(null),
  createExamSession: vi.fn().mockResolvedValue({ id: 1, name: "2024年考试" }),
  updateExamSession: vi.fn().mockResolvedValue(undefined),
  listExamRecords: vi.fn().mockResolvedValue([]),
  getExamRecord: vi.fn().mockResolvedValue(null),
  createExamRecord: vi.fn().mockResolvedValue({ id: 1 }),
  updateExamRecord: vi.fn().mockResolvedValue(undefined),
  getExamStats: vi.fn().mockResolvedValue({ avgScore: 85, maxScore: 100, minScore: 60, count: 30 }),
  getScoreDistribution: vi.fn().mockResolvedValue([]),
  getQuestionErrorRates: vi.fn().mockResolvedValue([]),
  getScoreDetails: vi.fn().mockResolvedValue([]),
  saveScoreDetails: vi.fn().mockResolvedValue(undefined),
  drawRandomQuestions: vi.fn().mockResolvedValue([]),
  getAssignmentsForStudent: vi.fn().mockResolvedValue([]),
}));

// ─── Context factories ────────────────────────────────────────────────────────
function createAdminCtx(): TrpcContext {
  return {
    user: {
      id: 1,
      openId: "admin-open-id",
      name: "管理员",
      email: "admin@exam.com",
      loginMethod: "manus",
      role: "admin",
      createdAt: new Date(),
      updatedAt: new Date(),
      lastSignedIn: new Date(),
    },
    req: { protocol: "https", headers: {} } as TrpcContext["req"],
    res: { clearCookie: vi.fn() } as unknown as TrpcContext["res"],
  };
}

function createUserCtx(): TrpcContext {
  return {
    user: {
      id: 2,
      openId: "user-open-id",
      name: "普通用户",
      email: "user@exam.com",
      loginMethod: "manus",
      role: "user",
      createdAt: new Date(),
      updatedAt: new Date(),
      lastSignedIn: new Date(),
    },
    req: { protocol: "https", headers: {} } as TrpcContext["req"],
    res: { clearCookie: vi.fn() } as unknown as TrpcContext["res"],
  };
}

function createAnonCtx(): TrpcContext {
  return {
    user: null,
    req: { protocol: "https", headers: {} } as TrpcContext["req"],
    res: { clearCookie: vi.fn() } as unknown as TrpcContext["res"],
  };
}

// ─── Auth Tests ───────────────────────────────────────────────────────────────
describe("auth", () => {
  it("returns null for unauthenticated user", async () => {
    const caller = appRouter.createCaller(createAnonCtx());
    const user = await caller.auth.me();
    expect(user).toBeNull();
  });

  it("returns user for authenticated user", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const user = await caller.auth.me();
    expect(user).not.toBeNull();
    expect(user?.role).toBe("admin");
  });

  it("clears session cookie on logout", async () => {
    const ctx = createAdminCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.auth.logout();
    expect(result.success).toBe(true);
  });
});

// ─── Students Router Tests ────────────────────────────────────────────────────
describe("students", () => {
  it("admin can list students", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.students.list({});
    expect(Array.isArray(result)).toBe(true);
  });

  it("non-admin cannot list students", async () => {
    const caller = appRouter.createCaller(createUserCtx());
    await expect(caller.students.list({})).rejects.toThrow("Admin access required");
  });

  it("admin can create student", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.students.create({
      studentId: "S001",
      name: "张三",
      className: "计算机2班",
      clientUsername: "zhangsan",
    });
    expect(result).toBeDefined();
    expect(result.name).toBe("张三");
  });
});

// ─── Questions Router Tests ───────────────────────────────────────────────────
describe("questions", () => {
  it("admin can list questions", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.questions.list({});
    expect(Array.isArray(result)).toBe(true);
  });

  it("admin can create question with username placeholder", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.questions.create({
      title: "创建数据库用户",
      content: "请为用户 {{username}} 创建数据库账号，并授予 DBA 权限",
      difficulty: 2,
      maxScore: 10,
    });
    expect(result).toBeDefined();
  });
});

// ─── Scoring Rules Router Tests ───────────────────────────────────────────────
describe("scoringRules", () => {
  it("admin can list scoring rules", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.scoringRules.list();
    expect(Array.isArray(result)).toBe(true);
  });

  it("admin can create scoring rule", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.scoringRules.createRule({
      questionId: 1,
      name: "数据库安装评分规则",
      description: "检查达梦数据库是否正确安装",
      initialScore: 10,
    });
    expect(result).toBeDefined();
    expect(result.name).toBe("安装评分规则");
  });

  it("admin can create check item with file_exists type", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.scoringRules.createCheckItem({
      ruleId: 1,
      description: "检查数据库安装目录",
      checkType: "file_exists",
      checkTarget: "/home/dmdba/dmdbms/bin/dmserver",
      deductionPoints: 5,
      failMessage: "数据库未安装:-5",
    });
    expect(result).toBeDefined();
  });

  it("admin can create check item with command_output type", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.scoringRules.createCheckItem({
      ruleId: 1,
      description: "检查数据库服务状态",
      checkType: "command_output",
      checkTarget: "systemctl is-active DmServiceDMSERVER",
      expectedValue: "active",
      compareOperator: "eq",
      deductionPoints: 3,
      failMessage: "数据库服务未启动:-3",
    });
    expect(result).toBeDefined();
  });

  it("generateScript returns null when no rule exists", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.scoringRules.generateScript({ questionId: 999 });
    expect(result).toBeNull();
  });
});

// ─── Exam Sessions Router Tests ───────────────────────────────────────────────
describe("exams", () => {
  it("admin can list exam sessions", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.exams.list();
    expect(Array.isArray(result)).toBe(true);
  });

  it("admin can create exam session", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.exams.create({
      name: "2024年达梦数据库期末考试",
      durationMinutes: 120,
      questionCount: 9,
    });
    expect(result).toBeDefined();
    expect(result.name).toBe("2024年考试");
  });

  it("admin can view exam records", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.exams.records({});
    expect(Array.isArray(result)).toBe(true);
  });
});

// ─── Agent API Tests ──────────────────────────────────────────────────────────
describe("agentApi", () => {
  it("authenticate rejects unknown student", async () => {
    const caller = appRouter.createCaller(createAnonCtx());
    await expect(
      caller.agentApi.authenticate({
        studentId: "UNKNOWN",
        deviceId: "device-123",
        clientUsername: "testuser",
      })
    ).rejects.toThrow("Student not found or inactive");
  });

  it("fetchQuestions rejects invalid token", async () => {
    const caller = appRouter.createCaller(createAnonCtx());
    await expect(
      caller.agentApi.fetchQuestions({
        token: "invalid-token",
        examId: 1,
      })
    ).rejects.toThrow("Invalid token");
  });

  it("submitScore rejects invalid token", async () => {
    const caller = appRouter.createCaller(createAnonCtx());
    await expect(
      caller.agentApi.submitScore({
        token: "invalid-token",
        examId: 1,
        totalScore: 85,
        durationSeconds: 3600,
        details: [],
      })
    ).rejects.toThrow("Invalid token");
  });
});

// ─── Shell Script Generation Tests ───────────────────────────────────────────
describe("shell script generation (unit)", () => {
  // Test the generateShellScript function indirectly via the router
  it("generateScript returns null for non-existent question", async () => {
    const caller = appRouter.createCaller(createAdminCtx());
    const result = await caller.scoringRules.generateScript({ questionId: 0 });
    expect(result).toBeNull();
  });
});
