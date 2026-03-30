import { and, desc, eq, inArray, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/mysql2";
import {
  examQuestionAssignments,
  examRecords,
  examSessions,
  InsertExamRecord,
  InsertExamSession,
  InsertQuestion,
  InsertScoringCheckItem,
  InsertScoringRule,
  InsertStudent,
  InsertUser,
  questionCategories,
  questions,
  scoreDetails,
  scoringCheckItems,
  scoringRules,
  students,
  users,
} from "../drizzle/schema";
import { logger } from "./_core/logger";

let _db: ReturnType<typeof drizzle> | null = null;

export async function getDb() {
  if (!_db && process.env.DATABASE_URL) {
    try {
      _db = drizzle(process.env.DATABASE_URL);
      logger.info("Database connection established successfully");
    } catch (error) {
      logger.error("Failed to connect to database", error, { url: process.env.DATABASE_URL?.replace(/:\/\/[^:]+:[^@]+@/, "://***:***@") });
      _db = null;
    }
  }
  return _db;
}

// ─── Users ────────────────────────────────────────────────────────────────────

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) throw new Error("User openId is required for upsert");
  const db = await getDb();
  if (!db) return;

  const values: InsertUser = { openId: user.openId };
  const updateSet: Record<string, unknown> = {};

  const textFields = ["name", "email", "loginMethod"] as const;
  textFields.forEach((f) => {
    const v = user[f];
    if (v !== undefined) { values[f] = v ?? null; updateSet[f] = v ?? null; }
  });

  const now = new Date();
  values.lastSignedIn = now;
  updateSet.lastSignedIn = now;

  if (user.role !== undefined) { values.role = user.role; updateSet.role = user.role; }

  await db.insert(users).values(values).onDuplicateKeyUpdate({ set: updateSet });
}

export async function getUserByOpenId(openId: string) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(users).where(eq(users.openId, openId)).limit(1);
  return r[0];
}

export async function getUserByName(name: string) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(users).where(eq(users.name, name)).limit(1);
  return r[0];
}

export async function setUserPassword(openId: string, passwordHash: string) {
  const db = await getDb();
  if (!db) return;
  await db.update(users).set({ passwordHash }).where(eq(users.openId, openId));
}

export async function listAdminUsers() {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(users).where(eq(users.role, 'admin'));
}

// ─── Students ─────────────────────────────────────────────────────────────────

export async function listStudents(opts?: { search?: string; className?: string }) {
  const db = await getDb();
  if (!db) return [];
  let q = db.select().from(students).$dynamic();
  if (opts?.className) q = q.where(eq(students.className, opts.className));
  return q.orderBy(desc(students.createdAt));
}

export async function getStudentById(id: number) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(students).where(eq(students.id, id)).limit(1);
  return r[0];
}

export async function getStudentByStudentId(studentId: string) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(students).where(eq(students.studentId, studentId)).limit(1);
  return r[0];
}

export async function getStudentByToken(token: string) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(students).where(eq(students.apiToken, token)).limit(1);
  return r[0];
}

export async function createStudent(data: InsertStudent) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(students).values(data);
  return res.insertId as number;
}

export async function updateStudent(id: number, data: Partial<InsertStudent>) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(students).set(data).where(eq(students.id, id));
}

export async function deleteStudent(id: number) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.delete(students).where(eq(students.id, id));
}

// ─── Question Categories ──────────────────────────────────────────────────────

export async function listCategories() {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(questionCategories).orderBy(questionCategories.name);
}

export async function createCategory(name: string, description?: string) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(questionCategories).values({ name, description });
  return res.insertId as number;
}

export async function updateCategory(id: number, name: string, description?: string) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(questionCategories).set({ name, description }).where(eq(questionCategories.id, id));
}

export async function deleteCategory(id: number) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.delete(questionCategories).where(eq(questionCategories.id, id));
}

// ─── Questions ────────────────────────────────────────────────────────────────

export async function listQuestions(opts?: { categoryId?: number; isActive?: boolean }) {
  const db = await getDb();
  if (!db) return [];
  const conditions = [];
  if (opts?.categoryId !== undefined) conditions.push(eq(questions.categoryId, opts.categoryId));
  if (opts?.isActive !== undefined) conditions.push(eq(questions.isActive, opts.isActive));
  let q = db.select({
    id: questions.id,
    title: questions.title,
    content: questions.content,
    difficulty: questions.difficulty,
    maxScore: questions.maxScore,
    sortOrder: questions.sortOrder,
    isActive: questions.isActive,
    categoryId: questions.categoryId,
    categoryName: questionCategories.name,
    createdAt: questions.createdAt,
    updatedAt: questions.updatedAt,
  }).from(questions)
    .leftJoin(questionCategories, eq(questions.categoryId, questionCategories.id))
    .$dynamic();
  if (conditions.length > 0) q = q.where(and(...conditions));
  return q.orderBy(questions.sortOrder, questions.id);
}

export async function getQuestionById(id: number) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(questions).where(eq(questions.id, id)).limit(1);
  return r[0];
}

export async function createQuestion(data: InsertQuestion) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(questions).values(data);
  return res.insertId as number;
}

export async function updateQuestion(id: number, data: Partial<InsertQuestion>) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(questions).set(data).where(eq(questions.id, id));
}

export async function deleteQuestion(id: number) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.delete(questions).where(eq(questions.id, id));
}

/** Randomly draw `count` active questions, optionally filtered by category IDs */
export async function drawRandomQuestions(count: number, categoryIds?: number[]) {
  const db = await getDb();
  if (!db) return [];
  const conditions = [eq(questions.isActive, true)];
  if (categoryIds && categoryIds.length > 0) {
    conditions.push(inArray(questions.categoryId, categoryIds));
  }
  // Use RAND() for MySQL compatibility (RANDOM() is PostgreSQL)
  return db.select().from(questions)
    .where(and(...conditions))
    .orderBy(sql`RAND()`)
    .limit(count);
}

/**
 * Generate variable context for a question based on the question set
 * @param questionSet The question set identifier (e.g., 'a', 'b')
 * @param questionIndex The index of the question in the exam
 * @param studentUsername The student's username
 * @returns Variable context object with placeholders and their values
 */
export function generateVariableContext(questionSet: string, questionIndex: number, studentUsername: string): Record<string, string> {
  const context: Record<string, string> = {
    '{{username}}': studentUsername,
    ['{{' + questionSet + '}}']: questionSet + 'set', // Main set variable
    ['{{' + questionSet + (questionIndex + 1) + '}}']: questionSet + 'set_q' + (questionIndex + 1), // Question-specific variable
  };
  
  // Add additional variables based on question set
  switch (questionSet) {
    case 'a':
      context['{{a_dbname}}'] = 'DAMENG';
      context['{{a_instance}}'] = 'PROD';
      context['{{a_port}}'] = '5236';
      break;
    case 'b':
      context['{{b_dbname}}'] = 'DMEXAM';
      context['{{b_instance}}'] = 'TEST';
      context['{{b_port}}'] = '5237';
      break;
    // Add more cases for additional question sets as needed
  }
  
  return context;
}

// ─── Scoring Rules ────────────────────────────────────────────────────────────

export async function getScoringRuleByQuestion(questionId: number) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(scoringRules).where(eq(scoringRules.questionId, questionId)).limit(1);
  return r[0];
}

export async function listScoringRules() {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(scoringRules).orderBy(scoringRules.id);
}

export async function createScoringRule(data: InsertScoringRule) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(scoringRules).values(data);
  return res.insertId as number;
}

export async function updateScoringRule(id: number, data: Partial<InsertScoringRule>) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(scoringRules).set(data).where(eq(scoringRules.id, id));
}

export async function deleteScoringRule(id: number) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.delete(scoringCheckItems).where(eq(scoringCheckItems.ruleId, id));
  await db.delete(scoringRules).where(eq(scoringRules.id, id));
}

// ─── Scoring Check Items ──────────────────────────────────────────────────────

export async function listCheckItemsByRule(ruleId: number) {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(scoringCheckItems)
    .where(eq(scoringCheckItems.ruleId, ruleId))
    .orderBy(scoringCheckItems.sortOrder);
}

export async function createCheckItem(data: InsertScoringCheckItem) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(scoringCheckItems).values(data);
  return res.insertId as number;
}

export async function updateCheckItem(id: number, data: Partial<InsertScoringCheckItem>) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(scoringCheckItems).set(data).where(eq(scoringCheckItems.id, id));
}

export async function deleteCheckItem(id: number) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.delete(scoringCheckItems).where(eq(scoringCheckItems.id, id));
}

// ─── Exam Sessions ────────────────────────────────────────────────────────────

export async function listExamSessions() {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(examSessions).orderBy(desc(examSessions.createdAt));
}

export async function getExamSessionById(id: number) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(examSessions).where(eq(examSessions.id, id)).limit(1);
  return r[0];
}

export async function createExamSession(data: InsertExamSession) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(examSessions).values(data);
  return res.insertId as number;
}

export async function updateExamSession(id: number, data: Partial<InsertExamSession>) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(examSessions).set(data).where(eq(examSessions.id, id));
}

// ─── Exam Question Assignments ────────────────────────────────────────────────

export async function getAssignmentsForStudent(examId: number, studentId: number) {
  const db = await getDb();
  if (!db) return [];
  return db.select({
    id: examQuestionAssignments.id,
    questionId: examQuestionAssignments.questionId,
    personalizedContent: examQuestionAssignments.personalizedContent,
    sortOrder: examQuestionAssignments.sortOrder,
    questionSet: examQuestionAssignments.questionSet,
    title: questions.title,
    maxScore: questions.maxScore,
    difficulty: questions.difficulty,
  }).from(examQuestionAssignments)
    .leftJoin(questions, eq(examQuestionAssignments.questionId, questions.id))
    .where(and(
      eq(examQuestionAssignments.examId, examId),
      eq(examQuestionAssignments.studentId, studentId),
    ))
    .orderBy(examQuestionAssignments.sortOrder);
}

// ─── Exam Records ─────────────────────────────────────────────────────────────

export async function getExamRecord(examId: number, studentId: number) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(examRecords)
    .where(and(eq(examRecords.examId, examId), eq(examRecords.studentId, studentId)))
    .limit(1);
  return r[0];
}

export async function getExamRecordById(recordId: number) {
  const db = await getDb();
  if (!db) return undefined;
  const r = await db.select().from(examRecords)
    .where(eq(examRecords.id, recordId))
    .limit(1);
  return r[0];
}

export async function createExamRecord(data: InsertExamRecord) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  const [res] = await db.insert(examRecords).values(data);
  return res.insertId as number;
}

export async function updateExamRecord(id: number, data: Partial<InsertExamRecord>) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  await db.update(examRecords).set(data).where(eq(examRecords.id, id));
}

export async function listExamRecords(examId?: number) {
  const db = await getDb();
  if (!db) return [];
  const q = db.select({
    id: examRecords.id,
    examId: examRecords.examId,
    studentId: examRecords.studentId,
    studentName: students.name,
    studentClass: students.className,
    clientUsername: examRecords.clientUsername,
    questionSet: examRecords.questionSet,
    status: examRecords.status,
    totalScore: examRecords.totalScore,
    maxPossibleScore: examRecords.maxPossibleScore,
    durationSeconds: examRecords.durationSeconds,
    startedAt: examRecords.startedAt,
    submittedAt: examRecords.submittedAt,
    gradedAt: examRecords.gradedAt,
  }).from(examRecords)
    .leftJoin(students, eq(examRecords.studentId, students.id))
    .$dynamic();
  if (examId !== undefined) {
    return q.where(eq(examRecords.examId, examId)).orderBy(desc(examRecords.submittedAt));
  }
  return q.orderBy(desc(examRecords.submittedAt));
}

// ─── Score Details ────────────────────────────────────────────────────────────

export async function getScoreDetails(examRecordId: number) {
  const db = await getDb();
  if (!db) return [];
  return db.select({
    id: scoreDetails.id,
    questionId: scoreDetails.questionId,
    questionTitle: questions.title,
    earnedScore: scoreDetails.earnedScore,
    maxScore: scoreDetails.maxScore,
    failedChecks: scoreDetails.failedChecks,
  }).from(scoreDetails)
    .leftJoin(questions, eq(scoreDetails.questionId, questions.id))
    .where(eq(scoreDetails.examRecordId, examRecordId));
}

export async function saveScoreDetails(
  examRecordId: number,
  details: Array<{ questionId: number; earnedScore: number; maxScore: number; failedChecks?: unknown[] }>
) {
  const db = await getDb();
  if (!db) throw new Error("DB unavailable");
  if (details.length === 0) return;
  await db.insert(scoreDetails).values(
    details.map((d) => ({ examRecordId, ...d }))
  );
}

// ─── Statistics ───────────────────────────────────────────────────────────────

export async function getExamStats(examId: number) {
  const db = await getDb();
  if (!db) return null;
  const rows = await db.select({
    count: sql<number>`COUNT(*)`,
    avgScore: sql<number>`AVG(totalScore)`,
    maxScore: sql<number>`MAX(totalScore)`,
    minScore: sql<number>`MIN(totalScore)`,
    passCount: sql<number>`SUM(CASE WHEN totalScore >= 60 THEN 1 ELSE 0 END)`,
  }).from(examRecords)
    .where(and(eq(examRecords.examId, examId), eq(examRecords.status, "graded")));
  return rows[0] ?? null;
}

export async function getScoreDistribution(examId: number) {
  const db = await getDb();
  if (!db) return [];
  return db.select({
    bucket: sql<string>`CONCAT(FLOOR(totalScore/10)*10, '-', FLOOR(totalScore/10)*10+9)`,
    count: sql<number>`COUNT(*)`,
  }).from(examRecords)
    .where(and(eq(examRecords.examId, examId), eq(examRecords.status, "graded")))
    .groupBy(sql`FLOOR(totalScore/10)`)
    .orderBy(sql`FLOOR(totalScore/10)`);
}

export async function getQuestionErrorRates(examId: number) {
  const db = await getDb();
  if (!db) return [];
  return db.select({
    questionId: scoreDetails.questionId,
    questionTitle: questions.title,
    avgEarned: sql<number>`AVG(${scoreDetails.earnedScore})`,
    avgMax: sql<number>`AVG(${scoreDetails.maxScore})`,
    errorRate: sql<number>`1 - AVG(${scoreDetails.earnedScore} / NULLIF(${scoreDetails.maxScore}, 0))`,
  }).from(scoreDetails)
    .leftJoin(examRecords, eq(scoreDetails.examRecordId, examRecords.id))
    .leftJoin(questions, eq(scoreDetails.questionId, questions.id))
    .where(eq(examRecords.examId, examId))
    .groupBy(scoreDetails.questionId, questions.title)
    .orderBy(sql`errorRate DESC`);
}
