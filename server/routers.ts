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
  generateVariableContext,
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
import { examQuestionAssignments } from "../drizzle/schema";
import { getUserByName, setUserPassword, listAdminUsers, setStudentPassword, getStudentExamRecords } from "./db";

// Import auth utilities from separate file to avoid crypto module issues in client build
import { makePasswordHash, verifyPassword } from "./utils/auth";
import { readFileSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

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
    password: z.string().min(6),
  })).mutation(async ({ input }) => {
    const { password, ...data } = input;
    const id = await createStudent({
      ...data,
      passwordHash: makePasswordHash(password),
    });
    return id;
  }),
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
  setPassword: adminProcedure
    .input(z.object({ studentId: z.string().min(1), password: z.string().min(6) }))
    .mutation(async ({ input }) => {
      const student = await getStudentByStudentId(input.studentId);
      if (!student) throw new TRPCError({ code: 'NOT_FOUND', message: '学生不存在' });
      await setStudentPassword(input.studentId, makePasswordHash(input.password));
      return { success: true };
    }),
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
    scoringScript: z.string().optional(),
    sortOrder: z.number().default(0),
  })).mutation(({ input }) => createQuestion(input)),
  update: adminProcedure.input(z.object({
    id: z.number(),
    title: z.string().optional(),
    content: z.string().optional(),
    categoryId: z.number().optional(),
    difficulty: z.number().min(1).max(3).optional(),
    maxScore: z.number().min(1).optional(),
    scoringScript: z.string().nullable().optional(),
    sortOrder: z.number().optional(),
    isActive: z.boolean().optional(),
  })).mutation(({ input: { id, ...data } }) => updateQuestion(id, data)),
  delete: adminProcedure.input(z.object({ id: z.number() })).mutation(({ input }) => deleteQuestion(input.id)),

  /** Validate a scoring script (bash -n syntax check) */
  validateScript: adminProcedure.input(z.object({
    script: z.string().min(1),
  })).mutation(async ({ input }) => {
    const { execSync } = await import('child_process');
    const { writeFileSync, unlinkSync } = await import('fs');
    const { join } = await import('path');
    const { tmpdir } = await import('os');
    const tmpFile = join(tmpdir(), `validate_${Date.now()}.sh`);
    try {
      writeFileSync(tmpFile, input.script, 'utf8');
      execSync(`bash -n "${tmpFile}" 2>&1`, { timeout: 5000 });
      return { valid: true, message: '语法检查通过' };
    } catch (err: any) {
      const output = err.stdout?.toString() || err.stderr?.toString() || err.message || '未知错误';
      return { valid: false, message: output.replace(tmpFile, 'script.sh') };
    } finally {
      try { unlinkSync(tmpFile); } catch {}
    }
  }),

  /** List preset scoring scripts from scoring_scripts/ directory */
  listPresets: adminProcedure.query(async () => {
    const { readdirSync, readFileSync, existsSync } = await import('fs');
    const { join } = await import('path');
    const dir = join(__dirname, '../scoring_scripts');
    if (!existsSync(dir)) return [];
    const files = readdirSync(dir).filter(f => f.endsWith('.sh')).sort();
    return files.map(f => {
      const content = readFileSync(join(dir, f), 'utf8');
      // Extract description from first comment line
      const descMatch = content.match(/^#\s*(.+)/m);
      return { filename: f, description: descMatch?.[1] ?? f, content };
    });
  }),
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

function buildScoringScript(questionSet: string, username: string): string {
  const candidateScriptPaths = [
    join(__dirname, `../score_${questionSet}.sh`),
    join(__dirname, `../score-${questionSet}.sh`),
    join(__dirname, "../score.sh"),
  ];
  const scoreScriptPath = candidateScriptPaths.find((p: string) => existsSync(p));

  if (!scoreScriptPath) {
    throw new TRPCError({
      code: "INTERNAL_SERVER_ERROR",
      message: "Score script not found",
    });
  }

  let scriptContent = readFileSync(scoreScriptPath, "utf8");

  const variables = generateVariableContext(questionSet, 0, username);

  Object.entries(variables).forEach(([placeholder, value]) => {
    scriptContent = scriptContent.replace(
      new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"),
      value,
    );
  });

  return scriptContent;
}

const clientRouter = router({
  /** Step 1: Agent authenticates with studentId + deviceId, receives token */
  authenticate: publicProcedure.input(z.object({
    studentId: z.string(),
    password: z.string(),
    deviceId: z.string(),
    clientUsername: z.string(),
  })).mutation(async ({ input }) => {
    const student = await getStudentByStudentId(input.studentId);
    if (!student || !student.isActive) {
      throw new TRPCError({ code: "UNAUTHORIZED", message: "Student not found or inactive" });
    }
    // Verify password
    if (!student.passwordHash) {
      throw new TRPCError({ code: "UNAUTHORIZED", message: "Account has no password set, contact admin" });
    }
    if (!verifyPassword(input.password, student.passwordHash)) {
      throw new TRPCError({ code: "UNAUTHORIZED", message: "Invalid password" });
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

  /** Step 1.5: Agent starts the exam (records start time/status) */
  startExam: publicProcedure.input(
    z.object({
      token: z.string(),
      examId: z.number(),
    }),
  ).mutation(async ({ input }) => {
    const student = await validateToken(input.token);
    const exam = await getExamSessionById(input.examId);
    if (!exam || exam.status !== "active") {
      throw new TRPCError({ code: "NOT_FOUND", message: "Exam not active" });
    }

    const record = await getExamRecord(input.examId, student.id);
    if (!record) {
      throw new TRPCError({
        code: "NOT_FOUND",
        message: "Exam record not found (call fetchQuestions first)",
      });
    }

    await updateExamRecord(record.id, {
      status: "in_progress",
      startedAt: new Date(),
    });

    return { success: true, recordId: record.id, questionSet: record.questionSet };
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
      
      // Generate random question set identifier (a/b)
      const questionSet = Math.random() < 0.5 ? 'a' : 'b';
      
      // Create variable context for each question using the centralized function
      const variableContexts = drawn.map((q, index) => {
        return generateVariableContext(questionSet, index, student.clientUsername ?? "student");
      });
      
      await db.insert(examQuestionAssignments).values(
        drawn.map((q, i) => {
          let personalizedContent = q.content;
          const variables = variableContexts[i];
          
          // Replace all variables in the question content
          Object.entries(variables).forEach(([placeholder, value]) => {
            personalizedContent = personalizedContent.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), value);
          });
          
          return {
            examId: input.examId,
            studentId: student.id,
            questionId: q.id,
            personalizedContent: personalizedContent,
            sortOrder: i,
            questionSet: questionSet, // Store question set for later use
          };
        })
      );
      
      // Create exam record (created on first fetch, startedAt is finalized in startExam)
      const existing = await getExamRecord(input.examId, student.id);
      if (!existing) {
        await createExamRecord({
          examId: input.examId,
          studentId: student.id,
          clientUsername: student.clientUsername,
          status: "in_progress",
          maxPossibleScore: drawn.reduce((s, q) => s + q.maxScore, 0),
          questionSet: questionSet, // Store question set for the exam
        });
      }
      assignments = await getAssignmentsForStudent(input.examId, student.id);
    }

    const questionSetUsed = assignments[0]?.questionSet ?? "a";
    // Build the legacy global script as fallback for questions without their own script
    let legacyScoringScript: string | null = null;
    try {
      legacyScoringScript = buildScoringScript(
        questionSetUsed,
        student.clientUsername ?? "student",
      );
    } catch { /* no legacy script available */ }

    return {
      examName: exam.name,
      durationMinutes: exam.durationMinutes,
      questions: assignments.map(a => ({
        ...a,
        // Per-question script takes priority; fallback to legacy global script
        scoringScript: a.scoringScript || legacyScoringScript || null,
      })),
      // Tell agent whether per-question scoring is available
      perQuestionScoring: assignments.some(a => !!a.scoringScript),
    };
  }),

  /** Step 3: Agent uploads scored results */
  submitScore: publicProcedure.input(z.object({
    token: z.string(),
    examId: z.number(),
    totalScore: z.number(),
    durationSeconds: z.number(),
    scriptOutput: z.string().optional(),
    examMeta: z.object({
      examStartedAt: z.string().optional(),
      examCompletedAt: z.string().optional(),
      clientStartedAt: z.string().optional(),
      hostname: z.string().optional(),
      os: z.string().optional(),
      osVersion: z.string().optional(),
      arch: z.string().optional(),
      deviceId: z.string().optional(),
      username: z.string().optional(),
      questionSet: z.string().optional(),
      questionCount: z.number().optional(),
    }).optional(),
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
    let finalScriptOutput = input.scriptOutput;
    if (input.examMeta) {
      finalScriptOutput = JSON.stringify({
        examMeta: input.examMeta,
        raw: input.scriptOutput ?? "",
      }, null, 2);
    }

    await updateExamRecord(record.id, {
      status: "graded",
      totalScore: input.totalScore,
      durationSeconds: input.durationSeconds,
      scriptOutput: finalScriptOutput,
      submittedAt: now,
      gradedAt: now,
    });
    await saveScoreDetails(record.id, input.details);
    return { success: true };
  }),

  /** Step 4: Agent finishes exam and updates record status */
  finishExam: publicProcedure.input(z.object({
    token: z.string(),
    recordId: z.number(),
  })).mutation(async ({ input }) => {
    const student = await validateToken(input.token);
    const record = await getExamRecordById(input.recordId);
    if (!record) {
      throw new TRPCError({ code: "NOT_FOUND", message: "Exam record not found" });
    }

    if (record.studentId !== student.id) {
      throw new TRPCError({ code: "FORBIDDEN", message: "Record mismatch" });
    }

    // Keep graded status for reports/dashboard while marking completion time.
    // If the exam is finished before grading, keep it as completed.
    const nextStatus = record.status === "graded" ? "graded" : "completed";
    await updateExamRecord(record.id, {
      status: nextStatus,
      completedAt: new Date(),
    });
    return { success: true, recordId: input.recordId };
  }),

  /** Fetch the generated scoring script for a specific exam question */
  fetchScoringScript: publicProcedure.input(z.object({
    token: z.string(),
    questionId: z.number(),
    examId: z.number(),
  })).query(async ({ input }) => {
    const student = await validateToken(input.token);
    
    // Get the question assignment to determine the question set
    const assignments = await getAssignmentsForStudent(input.examId, student.id);
    const assignment = assignments.find(a => a.questionId === input.questionId);
    const questionSet = assignment?.questionSet || 'a';
    
    const username = student.clientUsername ?? "student";
    const scriptContent = buildScoringScript(questionSet, username);
    const variables = generateVariableContext(questionSet, 0, username);
    
    return {
      script: scriptContent,
      ruleName: `score_${questionSet}`,
      variables: variables,
      username,
    };
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

    /** Student login — students use studentId + password */
    studentLogin: publicProcedure
      .input(z.object({ studentId: z.string().min(1), password: z.string().min(1) }))
      .mutation(async ({ ctx, input }) => {
        const student = await getStudentByStudentId(input.studentId);
        if (!student) throw new TRPCError({ code: 'UNAUTHORIZED', message: '学号或密码错误' });
        if (!student.isActive) throw new TRPCError({ code: 'FORBIDDEN', message: '该账号已被禁用' });
        if (!student.passwordHash) throw new TRPCError({ code: 'UNAUTHORIZED', message: '该账号未设置密码，请联系管理员' });
        if (!verifyPassword(input.password, student.passwordHash)) {
          throw new TRPCError({ code: 'UNAUTHORIZED', message: '学号或密码错误' });
        }
        // Create a user record for the student session (role='student')
        const openId = 'student-' + student.studentId;
        await upsertUser({ openId, name: student.name, loginMethod: 'local', role: 'student' });
        const { sdk } = await import('./_core/sdk');
        const sessionToken = await sdk.createSessionToken(openId, { name: student.name });
        const { ONE_YEAR_MS } = await import('@shared/const');
        const cookieOptions = getSessionCookieOptions(ctx.req);
        ctx.res.cookie(COOKIE_NAME, sessionToken, { ...cookieOptions, maxAge: ONE_YEAR_MS });
        return { success: true, user: { name: student.name, studentId: student.studentId, role: 'student' } };
      }),

    /** Student change password */
    studentChangePassword: protectedProcedure
      .input(z.object({ oldPassword: z.string(), newPassword: z.string().min(6) }))
      .mutation(async ({ ctx, input }) => {
        if (!ctx.user?.openId?.startsWith('student-')) {
          throw new TRPCError({ code: 'FORBIDDEN', message: '仅学生账号可用' });
        }
        const sid = ctx.user.openId.replace('student-', '');
        const student = await getStudentByStudentId(sid);
        if (!student) throw new TRPCError({ code: 'NOT_FOUND', message: '学生不存在' });
        if (student.passwordHash && !verifyPassword(input.oldPassword, student.passwordHash)) {
          throw new TRPCError({ code: 'UNAUTHORIZED', message: '原密码错误' });
        }
        await setStudentPassword(student.studentId, makePasswordHash(input.newPassword));
        return { success: true };
      }),
  }),

  // ─── Student Portal ──────────────────────────────────────────────────────────
  studentPortal: router({
    /** Get current student profile */
    profile: protectedProcedure.query(async ({ ctx }) => {
      if (!ctx.user?.openId?.startsWith('student-')) {
        throw new TRPCError({ code: 'FORBIDDEN', message: '仅学生可访问' });
      }
      const sid = ctx.user.openId.replace('student-', '');
      const student = await getStudentByStudentId(sid);
      if (!student) throw new TRPCError({ code: 'NOT_FOUND', message: '学生不存在' });
      return {
        id: student.id,
        studentId: student.studentId,
        name: student.name,
        className: student.className,
        department: student.department,
      };
    }),

    /** List exams visible to student (active or ended) */
    exams: protectedProcedure.query(async () => {
      const all = await listExamSessions();
      return all.filter(e => e.status === 'active' || e.status === 'ended').map(e => ({
        id: e.id,
        name: e.name,
        description: e.description,
        status: e.status,
        durationMinutes: e.durationMinutes,
        questionCount: e.questionCount,
        startedAt: e.startedAt,
        endedAt: e.endedAt,
      }));
    }),

    /** My exam records with scores */
    myRecords: protectedProcedure.query(async ({ ctx }) => {
      if (!ctx.user?.openId?.startsWith('student-')) {
        throw new TRPCError({ code: 'FORBIDDEN', message: '仅学生可访问' });
      }
      const sid = ctx.user.openId.replace('student-', '');
      const student = await getStudentByStudentId(sid);
      if (!student) return [];
      return getStudentExamRecords(student.id as number);
    }),

    /** My assigned questions for an exam */
    myQuestions: protectedProcedure
      .input(z.object({ examId: z.number() }))
      .query(async ({ ctx, input }) => {
        if (!ctx.user?.openId?.startsWith('student-')) {
          throw new TRPCError({ code: 'FORBIDDEN', message: '仅学生可访问' });
        }
        const sid = ctx.user.openId.replace('student-', '');
        const student = await getStudentByStudentId(sid);
        if (!student) return [];
        const assignments = await getAssignmentsForStudent(input.examId, student.id as number);
        return assignments.map(a => ({
          questionId: a.questionId,
          title: a.title,
          content: a.content,
          maxScore: a.maxScore,
          sortOrder: a.sortOrder,
        }));
      }),

    /** Score details for a specific exam record */
    scoreDetail: protectedProcedure
      .input(z.object({ recordId: z.number() }))
      .query(async ({ ctx, input }) => {
        if (!ctx.user?.openId?.startsWith('student-')) {
          throw new TRPCError({ code: 'FORBIDDEN', message: '仅学生可访问' });
        }
        const sid = ctx.user.openId.replace('student-', '');
        const student = await getStudentByStudentId(sid);
        if (!student) throw new TRPCError({ code: 'NOT_FOUND' });
        const record = await getExamRecordById(input.recordId);
        if (!record || record.studentId !== student.id) {
          throw new TRPCError({ code: 'NOT_FOUND', message: '记录不存在' });
        }
        const details = await getScoreDetails(input.recordId);
        return { record, details };
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
