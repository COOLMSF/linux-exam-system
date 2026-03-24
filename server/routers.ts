import { TRPCError } from "@trpc/server";
import { z } from "zod";
import { COOKIE_NAME } from "@shared/const";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { protectedProcedure, publicProcedure, router } from "./_core/trpc";
import {
  createCategory,
  createCheckItem,
  createExamRecord,
  createExamSession,
  createQuestion,
  createScoringRule,
  createStudent,
  deleteCategory,
  deleteCheckItem,
  deleteQuestion,
  deleteScoringRule,
  deleteStudent,
  drawRandomQuestions,
  getAssignmentsForStudent,
  getDb,
  getExamRecord,
  getExamRecordById,
  getExamSessionById,
  getExamStats,
  getQuestionErrorRates,
  getScoreDetails,
  getScoreDistribution,
  getScoringRuleByQuestion,
  getStudentByStudentId,
  getStudentByToken,
  getUserByOpenId,
  listCategories,
  listCheckItemsByRule,
  listExamRecords,
  listExamSessions,
  listQuestions,
  listScoringRules,
  listStudents,
  saveScoreDetails,
  updateCategory,
  updateCheckItem,
  updateExamRecord,
  updateExamSession,
  updateQuestion,
  updateScoringRule,
  updateStudent,
  upsertUser,
} from "./db";
import { nanoid } from "nanoid";
import { createHash, randomBytes } from "crypto";
import { examQuestionAssignments } from "../drizzle/schema";
import { getUserByName, setUserPassword, listAdminUsers } from "./db";

// ─── Local auth helpers ───────────────────────────────────────────────────────
function hashPassword(password: string, salt: string): string {
  return createHash('sha256').update(salt + password + salt).digest('hex');
}
function makePasswordHash(password: string): string {
  const salt = randomBytes(16).toString('hex');
  return salt + ':' + hashPassword(password, salt);
}
function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(':');
  if (!salt || !hash) return false;
  return hashPassword(password, salt) === hash;
}

// ─── Admin guard ──────────────────────────────────────────────────────────────

const adminProcedure = protectedProcedure.use(({ ctx, next }) => {
  if (ctx.user.role !== "admin") {
    throw new TRPCError({ code: "FORBIDDEN", message: "Admin access required" });
  }
  return next({ ctx });
});

// ─── Students Router ──────────────────────────────────────────────────────────

const studentsRouter = router({
  list: adminProcedure.input(z.object({ className: z.string().optional() }).optional()).query(({ input }) =>
    listStudents(input ?? {})
  ),
  create: adminProcedure.input(z.object({
    studentId: z.string().min(1),
    name: z.string().min(1),
    className: z.string().optional(),
    department: z.string().optional(),
    clientUsername: z.string().optional(),
  })).mutation(({ input }) => createStudent(input)),
  update: adminProcedure.input(z.object({
    id: z.number(),
    name: z.string().optional(),
    className: z.string().optional(),
    department: z.string().optional(),
    clientUsername: z.string().optional(),
    isActive: z.boolean().optional(),
  })).mutation(({ input: { id, ...data } }) => updateStudent(id, data)),
  delete: adminProcedure.input(z.object({ id: z.number() })).mutation(({ input }) =>
    deleteStudent(input.id)
  ),
});

// ─── Categories Router ────────────────────────────────────────────────────────

const categoriesRouter = router({
  list: protectedProcedure.query(() => listCategories()),
  create: adminProcedure.input(z.object({ name: z.string().min(1), description: z.string().optional() }))
    .mutation(({ input }) => createCategory(input.name, input.description)),
  update: adminProcedure.input(z.object({ id: z.number(), name: z.string().min(1), description: z.string().optional() }))
    .mutation(({ input }) => updateCategory(input.id, input.name, input.description)),
  delete: adminProcedure.input(z.object({ id: z.number() })).mutation(({ input }) => deleteCategory(input.id)),
});

// ─── Questions Router ─────────────────────────────────────────────────────────

const questionsRouter = router({
  list: protectedProcedure.input(z.object({ categoryId: z.number().optional(), isActive: z.boolean().optional() }).optional())
    .query(({ input }) => listQuestions(input ?? {})),
  create: adminProcedure.input(z.object({
    title: z.string().min(1),
    content: z.string().min(1),
    categoryId: z.number().optional(),
    difficulty: z.number().min(1).max(3).default(2),
    maxScore: z.number().min(1).default(10),
    sortOrder: z.number().default(0),
  })).mutation(({ input }) => createQuestion(input)),
  update: adminProcedure.input(z.object({
    id: z.number(),
    title: z.string().optional(),
    content: z.string().optional(),
    categoryId: z.number().optional(),
    difficulty: z.number().min(1).max(3).optional(),
    maxScore: z.number().min(1).optional(),
    sortOrder: z.number().optional(),
    isActive: z.boolean().optional(),
  })).mutation(({ input: { id, ...data } }) => updateQuestion(id, data)),
  delete: adminProcedure.input(z.object({ id: z.number() })).mutation(({ input }) => deleteQuestion(input.id)),
});

// ─── Scoring Rules Router ─────────────────────────────────────────────────────

const scoringRulesRouter = router({
  list: adminProcedure.query(() => listScoringRules()),
  getByQuestion: adminProcedure.input(z.object({ questionId: z.number() }))
    .query(({ input }) => getScoringRuleByQuestion(input.questionId)),
  getCheckItems: adminProcedure.input(z.object({ ruleId: z.number() }))
    .query(({ input }) => listCheckItemsByRule(input.ruleId)),
  createRule: adminProcedure.input(z.object({
    questionId: z.number(),
    name: z.string().min(1),
    description: z.string().optional(),
    initialScore: z.number().min(0),
  })).mutation(({ input }) => createScoringRule(input)),
  updateRule: adminProcedure.input(z.object({
    id: z.number(),
    name: z.string().optional(),
    description: z.string().optional(),
    initialScore: z.number().min(0).optional(),
  })).mutation(({ input: { id, ...data } }) => updateScoringRule(id, data)),
  deleteRule: adminProcedure.input(z.object({ id: z.number() })).mutation(({ input }) => deleteScoringRule(input.id)),
  createCheckItem: adminProcedure.input(z.object({
    ruleId: z.number(),
    description: z.string().min(1),
    checkType: z.enum(["file_exists", "file_not_exists", "command_output", "db_query", "custom_script"]),
    checkTarget: z.string().min(1),
    expectedValue: z.string().optional(),
    compareOperator: z.enum(["eq", "ne", "contains", "gt", "lt"]).default("eq"),
    deductionPoints: z.number().min(0).default(0),
    failMessage: z.string().optional(),
    sortOrder: z.number().default(0),
  })).mutation(({ input }) => createCheckItem(input)),
  updateCheckItem: adminProcedure.input(z.object({
    id: z.number(),
    description: z.string().optional(),
    checkType: z.enum(["file_exists", "file_not_exists", "command_output", "db_query", "custom_script"]).optional(),
    checkTarget: z.string().optional(),
    expectedValue: z.string().optional(),
    compareOperator: z.enum(["eq", "ne", "contains", "gt", "lt"]).optional(),
    deductionPoints: z.number().min(0).optional(),
    failMessage: z.string().optional(),
    sortOrder: z.number().optional(),
    isActive: z.boolean().optional(),
  })).mutation(({ input: { id, ...data } }) => updateCheckItem(id, data)),
  deleteCheckItem: adminProcedure.input(z.object({ id: z.number() })).mutation(({ input }) => deleteCheckItem(input.id)),
  /** Generate a Shell scoring script from the rule configuration */
  generateScript: adminProcedure.input(z.object({ questionId: z.number() })).query(async ({ input }) => {
    const rule = await getScoringRuleByQuestion(input.questionId);
    if (!rule) return null;
    const items = await listCheckItemsByRule(rule.id);
    return generateShellScript(rule, items);
  }),
});

// ─── Exam Sessions Router ─────────────────────────────────────────────────────

const examsRouter = router({
  list: adminProcedure.query(() => listExamSessions()),
  getById: adminProcedure.input(z.object({ id: z.number() })).query(({ input }) =>
    getExamSessionById(input.id)
  ),
  create: adminProcedure.input(z.object({
    name: z.string().min(1),
    description: z.string().optional(),
    durationMinutes: z.number().min(1).default(120),
    questionCount: z.number().min(1).default(9),
    categoryFilter: z.array(z.number()).optional(),
  })).mutation(({ input }) => createExamSession({
    ...input,
    categoryFilter: input.categoryFilter ?? null,
  })),
  update: adminProcedure.input(z.object({
    id: z.number(),
    name: z.string().optional(),
    description: z.string().optional(),
    durationMinutes: z.number().min(1).optional(),
    questionCount: z.number().min(1).optional(),
    status: z.enum(["draft", "active", "paused", "ended"]).optional(),
  })).mutation(async ({ input: { id, ...data } }) => {
    const updates: Record<string, unknown> = { ...data };
    if (data.status === "active") updates.startedAt = new Date();
    if (data.status === "ended") updates.endedAt = new Date();
    await updateExamSession(id, updates as never);
    return getExamSessionById(id);
  }),
  records: adminProcedure.input(z.object({ examId: z.number().optional() })).query(({ input }) =>
    listExamRecords(input.examId)
  ),
  recordDetails: adminProcedure.input(z.object({ recordId: z.number() })).query(({ input }) =>
    getScoreDetails(input.recordId)
  ),
  stats: adminProcedure.input(z.object({ examId: z.number() })).query(({ input }) =>
    getExamStats(input.examId)
  ),
  scoreDistribution: adminProcedure.input(z.object({ examId: z.number() })).query(({ input }) =>
    getScoreDistribution(input.examId)
  ),
  questionErrorRates: adminProcedure.input(z.object({ examId: z.number() })).query(({ input }) =>
    getQuestionErrorRates(input.examId)
  ),
});

// ─── Client API Router (used by Python Agent) ─────────────────────────────────

const clientRouter = router({
  /** Step 1: Agent authenticates with studentId + deviceId, receives token */
  authenticate: publicProcedure.input(z.object({
    studentId: z.string(),
    deviceId: z.string(),
    clientUsername: z.string(),
  })).mutation(async ({ input }) => {
    const student = await getStudentByStudentId(input.studentId);
    if (!student || !student.isActive) {
      throw new TRPCError({ code: "UNAUTHORIZED", message: "Student not found or inactive" });
    }
    // Bind device on first auth; reject mismatched device on subsequent auths
    if (student.deviceId && student.deviceId !== input.deviceId) {
      throw new TRPCError({ code: "FORBIDDEN", message: "Device mismatch" });
    }
    const token = nanoid(64);
    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000); // 8 hours
    await updateStudent(student.id, {
      apiToken: token,
      tokenExpiresAt: expiresAt,
      deviceId: input.deviceId,
      clientUsername: input.clientUsername,
    });
    return { token, expiresAt, studentId: student.id, name: student.name };
  }),

  /** Step 2: Agent fetches personalised questions for an active exam */
  fetchQuestions: publicProcedure.input(z.object({
    token: z.string(),
    examId: z.number(),
  })).mutation(async ({ input }) => {
    const student = await validateToken(input.token);
    const exam = await getExamSessionById(input.examId);
    if (!exam || exam.status !== "active") {
      throw new TRPCError({ code: "NOT_FOUND", message: "Exam not active" });
    }

    // Check for existing assignment
    let assignments = await getAssignmentsForStudent(input.examId, student.id);
    if (assignments.length === 0) {
      // Draw questions and personalise
      const categoryIds = exam.categoryFilter as number[] | null ?? undefined;
      const drawn = await drawRandomQuestions(exam.questionCount, categoryIds);
      if (drawn.length === 0) {
        throw new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "No questions available" });
      }
      const db = await getDb();
      if (!db) throw new TRPCError({ code: "INTERNAL_SERVER_ERROR" });
      await db.insert(examQuestionAssignments).values(
        drawn.map((q, i) => ({
          examId: input.examId,
          studentId: student.id,
          questionId: q.id,
          personalizedContent: q.content.replace(/\{\{username\}\}/g, student.clientUsername ?? "student"),
          sortOrder: i,
        }))
      );
      // Create exam record
      const existing = await getExamRecord(input.examId, student.id);
      if (!existing) {
        await createExamRecord({
          examId: input.examId,
          studentId: student.id,
          clientUsername: student.clientUsername,
          status: "in_progress",
          maxPossibleScore: drawn.reduce((s, q) => s + q.maxScore, 0),
        });
      }
      assignments = await getAssignmentsForStudent(input.examId, student.id);
    }

    return {
      examName: exam.name,
      durationMinutes: exam.durationMinutes,
      questions: assignments,
    };
  }),

  /** Step 3: Agent uploads scored results */
  submitScore: publicProcedure.input(z.object({
    token: z.string(),
    examId: z.number(),
    totalScore: z.number(),
    durationSeconds: z.number(),
    scriptOutput: z.string().optional(),
    details: z.array(z.object({
      questionId: z.number(),
      earnedScore: z.number(),
      maxScore: z.number(),
      failedChecks: z.array(z.string()).optional(),
    })),
  })).mutation(async ({ input }) => {
    const student = await validateToken(input.token);
    const record = await getExamRecord(input.examId, student.id);
    if (!record) {
      throw new TRPCError({ code: "NOT_FOUND", message: "Exam record not found" });
    }
    if (record.status === "graded") {
      return { success: true, message: "Already graded" };
    }
    const now = new Date();
    await updateExamRecord(record.id, {
      status: "graded",
      totalScore: input.totalScore,
      durationSeconds: input.durationSeconds,
      scriptOutput: input.scriptOutput,
      submittedAt: now,
      gradedAt: now,
    });
    await saveScoreDetails(record.id, input.details);
    return { success: true };
  }),

  /** Step 4: Agent finishes exam and updates record status */
  finishExam: publicProcedure.input(z.object({
    recordId: z.number(),
  })).mutation(async ({ input }) => {
    const record = await getExamRecordById(input.recordId);
    if (!record) {
      throw new TRPCError({ code: "NOT_FOUND", message: "Exam record not found" });
    }
    // Update exam record to completed status
    await updateExamRecord(record.id, {
      status: "completed",
      completedAt: new Date(),
    });
    return { success: true, recordId: input.recordId };
  }),

  /** Fetch the generated scoring script for a specific exam question */
  fetchScoringScript: publicProcedure.input(z.object({
    token: z.string(),
    questionId: z.number(),
  })).query(async ({ input }) => {
    await validateToken(input.token);
    const rule = await getScoringRuleByQuestion(input.questionId);
    if (!rule) return null;
    const items = await listCheckItemsByRule(rule.id);
    return { script: generateShellScript(rule, items), ruleName: rule.name };
  }),
});

// ─── Reports Router ───────────────────────────────────────────────────────────

const reportsRouter = router({
  overview: adminProcedure.query(async () => {
    const db = await getDb();
    if (!db) return null;
    const [examCount] = await db.execute("SELECT COUNT(*) as count FROM exam_sessions");
    const [studentCount] = await db.execute("SELECT COUNT(*) as count FROM students WHERE isActive = 1");
    const [submissionCount] = await db.execute("SELECT COUNT(*) as count FROM exam_records WHERE status = 'graded'");
    const [avgScore] = await db.execute("SELECT AVG(totalScore) as avg FROM exam_records WHERE status = 'graded'");
    return { examCount, studentCount, submissionCount, avgScore };
  }),
  allRecords: adminProcedure.query(() => listExamRecords()),
});

// ─── Root Router ──────────────────────────────────────────────────────────────

export const appRouter = router({
  system: systemRouter,
  auth: router({
    me: publicProcedure.query((opts) => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return { success: true } as const;
    }),

    /** Local username/password login — for standalone deployment without Manus OAuth */
    localLogin: publicProcedure
      .input(z.object({ username: z.string().min(1), password: z.string().min(1) }))
      .mutation(async ({ ctx, input }) => {
        const user = await getUserByName(input.username);
        if (!user) throw new TRPCError({ code: 'UNAUTHORIZED', message: '用户名或密码错误' });
        if (!user.passwordHash) throw new TRPCError({ code: 'UNAUTHORIZED', message: '该账号未设置密码，请联系管理员' });
        if (!verifyPassword(input.password, user.passwordHash)) {
          throw new TRPCError({ code: 'UNAUTHORIZED', message: '用户名或密码错误' });
        }
        // Create session token using JWT (same as OAuth flow)
        const { sdk } = await import('./_core/sdk');
        const sessionToken = await sdk.createSessionToken(user.openId, { name: user.name || input.username });
        const { ONE_YEAR_MS } = await import('@shared/const');
        const cookieOptions = getSessionCookieOptions(ctx.req);
        ctx.res.cookie(COOKIE_NAME, sessionToken, { ...cookieOptions, maxAge: ONE_YEAR_MS });
        await upsertUser({ openId: user.openId, lastSignedIn: new Date() });
        return { success: true, user: { id: user.id, name: user.name, role: user.role } };
      }),

    /** First-time setup: create the first admin account (only when no admins exist) */
    setupAdmin: publicProcedure
      .input(z.object({ username: z.string().min(2), password: z.string().min(6) }))
      .mutation(async ({ input }) => {
        const admins = await listAdminUsers();
        if (admins.length > 0) throw new TRPCError({ code: 'FORBIDDEN', message: '管理员账号已存在，请直接登录' });
        const openId = 'local-admin-' + nanoid(12);
        const passwordHash = makePasswordHash(input.password);
        await upsertUser({ openId, name: input.username, loginMethod: 'local', role: 'admin' });
        await setUserPassword(openId, passwordHash);
        return { success: true, message: '管理员账号创建成功，请登录' };
      }),

    /** Check if any admin exists (used to show setup page) */
    needsSetup: publicProcedure.query(async () => {
      const admins = await listAdminUsers();
      return { needsSetup: admins.length === 0 };
    }),

    /** Change password for logged-in user */
    changePassword: protectedProcedure
      .input(z.object({ oldPassword: z.string(), newPassword: z.string().min(6) }))
      .mutation(async ({ ctx, input }) => {
        const user = await getUserByOpenId(ctx.user.openId);
        if (!user) throw new TRPCError({ code: 'NOT_FOUND', message: '用户不存在' });
        if (user.passwordHash && !verifyPassword(input.oldPassword, user.passwordHash)) {
          throw new TRPCError({ code: 'UNAUTHORIZED', message: '原密码错误' });
        }
        await setUserPassword(user.openId, makePasswordHash(input.newPassword));
        return { success: true };
      }),
  }),
  students: studentsRouter,
  categories: categoriesRouter,
  questions: questionsRouter,
  scoringRules: scoringRulesRouter,
  exams: examsRouter,
  agentApi: clientRouter,
  reports: reportsRouter,
});

export type AppRouter = typeof appRouter;

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function validateToken(token: string) {
  const student = await getStudentByToken(token);
  if (!student) throw new TRPCError({ code: "UNAUTHORIZED", message: "Invalid token" });
  if (student.tokenExpiresAt && student.tokenExpiresAt < new Date()) {
    throw new TRPCError({ code: "UNAUTHORIZED", message: "Token expired" });
  }
  return student;
}

type ScoringRuleRow = { id: number; name: string; initialScore: number; description?: string | null };
type CheckItemRow = {
  id: number;
  description: string;
  checkType: string;
  checkTarget: string;
  expectedValue?: string | null;
  compareOperator?: string | null;
  deductionPoints: number;
  failMessage?: string | null;
  sortOrder: number;
  isActive: boolean;
};

function generateShellScript(rule: ScoringRuleRow, items: CheckItemRow[]): string {
  const activeItems = items.filter((i) => i.isActive).sort((a, b) => a.sortOrder - b.sortOrder);
  const lines: string[] = [
    "#!/bin/bash",
    "# ================================================================",
    `# Auto-generated scoring script: ${rule.name}`,
    `# Generated by Linux Exam System`,
    "# ================================================================",
    "",
    `score=${rule.initialScore}`,
    `max_score=${rule.initialScore}`,
    "",
    'echo "=== 开始评分 ==="',
    "",
  ];

  for (const item of activeItems) {
    lines.push(`# --- ${item.description} ---`);
    switch (item.checkType) {
      case "file_exists":
        lines.push(
          `if [ -e "${item.checkTarget}" ]; then`,
          `  echo "✓ ${item.description}"`,
          `else`,
          `  echo "✗ ${item.failMessage ?? item.description + ": 未找到"} (-${item.deductionPoints})"`,
          `  score=$((score - ${item.deductionPoints}))`,
          `fi`,
          ""
        );
        break;
      case "file_not_exists":
        lines.push(
          `if [ ! -e "${item.checkTarget}" ]; then`,
          `  echo "✓ ${item.description}"`,
          `else`,
          `  echo "✗ ${item.failMessage ?? item.description + ": 文件仍存在"} (-${item.deductionPoints})"`,
          `  score=$((score - ${item.deductionPoints}))`,
          `fi`,
          ""
        );
        break;
      case "command_output": {
        const op = item.compareOperator ?? "eq";
        const cmp = op === "eq" ? `[ "$output" = "${item.expectedValue}" ]`
          : op === "ne" ? `[ "$output" != "${item.expectedValue}" ]`
          : op === "contains" ? `echo "$output" | grep -q "${item.expectedValue}"`
          : op === "gt" ? `[ "$output" -gt "${item.expectedValue}" ]`
          : `[ "$output" -lt "${item.expectedValue}" ]`;
        lines.push(
          `output=$(${item.checkTarget} 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)`,
          `if ${cmp}; then`,
          `  echo "✓ ${item.description}"`,
          `else`,
          `  echo "✗ ${item.failMessage ?? item.description} (-${item.deductionPoints})"`,
          `  score=$((score - ${item.deductionPoints}))`,
          `fi`,
          ""
        );
        break;
      }
      case "db_query":
        lines.push(
          `DMPATH=/dm/bin`,
          `conn_s=sysdba/Dameng123@localhost:5236`,
          `$DMPATH/disql -s $conn_s \`${item.checkTarget} >/dev/null`,
          `db_result=$(head -1 /home/dmdba/check_result.buf | tr -s "  " | cut -d " " -f 2)`,
          `if [ "$db_result" = "${item.expectedValue}" ]; then`,
          `  echo "✓ ${item.description}"`,
          `else`,
          `  echo "✗ ${item.failMessage ?? item.description} (-${item.deductionPoints})"`,
          `  score=$((score - ${item.deductionPoints}))`,
          `fi`,
          ""
        );
        break;
      case "custom_script":
        lines.push(
          `# Custom check: ${item.description}`,
          item.checkTarget,
          `if [ $? -eq 0 ]; then`,
          `  echo "✓ ${item.description}"`,
          `else`,
          `  echo "✗ ${item.failMessage ?? item.description} (-${item.deductionPoints})"`,
          `  score=$((score - ${item.deductionPoints}))`,
          `fi`,
          ""
        );
        break;
    }
  }

  lines.push(
    'echo ""',
    `echo "=== 评分完成 ==="`,
    `echo "本题得分: $score / $max_score"`,
    `echo "SCORE:$score:$max_score"`,
  );

  return lines.join("\n");
}
