import {
  int,
  mysqlEnum,
  mysqlTable,
  text,
  timestamp,
  varchar,
  float,
  boolean,
  json,
} from "drizzle-orm/mysql-core";

// ─── Users / Students ────────────────────────────────────────────────────────

export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

// ─── Students ────────────────────────────────────────────────────────────────

export const students = mysqlTable("students", {
  id: int("id").autoincrement().primaryKey(),
  studentId: varchar("studentId", { length: 64 }).notNull().unique(),
  name: varchar("name", { length: 128 }).notNull(),
  className: varchar("className", { length: 128 }),
  department: varchar("department", { length: 128 }),
  /** Linux username on the client machine — used for question personalisation */
  clientUsername: varchar("clientUsername", { length: 128 }),
  /** Unique device fingerprint bound to this student */
  deviceId: varchar("deviceId", { length: 256 }),
  /** API token issued to the client agent */
  apiToken: varchar("apiToken", { length: 512 }),
  tokenExpiresAt: timestamp("tokenExpiresAt"),
  isActive: boolean("isActive").default(true).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Student = typeof students.$inferSelect;
export type InsertStudent = typeof students.$inferInsert;

// ─── Question Categories ──────────────────────────────────────────────────────

export const questionCategories = mysqlTable("question_categories", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 128 }).notNull(),
  description: text("description"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type QuestionCategory = typeof questionCategories.$inferSelect;

// ─── Questions ────────────────────────────────────────────────────────────────

export const questions = mysqlTable("questions", {
  id: int("id").autoincrement().primaryKey(),
  categoryId: int("categoryId").references(() => questionCategories.id),
  title: varchar("title", { length: 512 }).notNull(),
  /** Full question body; use {{username}} as placeholder for client username */
  content: text("content").notNull(),
  /** Difficulty: 1=easy, 2=medium, 3=hard */
  difficulty: int("difficulty").default(2).notNull(),
  /** Maximum score for this question */
  maxScore: int("maxScore").default(10).notNull(),
  /** Sort order within a category */
  sortOrder: int("sortOrder").default(0).notNull(),
  isActive: boolean("isActive").default(true).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Question = typeof questions.$inferSelect;
export type InsertQuestion = typeof questions.$inferInsert;

// ─── Scoring Rules ────────────────────────────────────────────────────────────

export const scoringRules = mysqlTable("scoring_rules", {
  id: int("id").autoincrement().primaryKey(),
  questionId: int("questionId")
    .notNull()
    .references(() => questions.id),
  name: varchar("name", { length: 256 }).notNull(),
  description: text("description"),
  /** Initial full score for this rule set */
  initialScore: int("initialScore").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type ScoringRule = typeof scoringRules.$inferSelect;
export type InsertScoringRule = typeof scoringRules.$inferInsert;

// ─── Scoring Check Items ──────────────────────────────────────────────────────

export const scoringCheckItems = mysqlTable("scoring_check_items", {
  id: int("id").autoincrement().primaryKey(),
  ruleId: int("ruleId")
    .notNull()
    .references(() => scoringRules.id),
  /** Human-readable description shown to admin */
  description: varchar("description", { length: 512 }).notNull(),
  /**
   * Check type:
   *  - file_exists   : check if a file/directory exists
   *  - file_not_exists : check if a file/directory does NOT exist
   *  - command_output : run a shell command and compare output
   *  - db_query      : run disql and compare result
   *  - custom_script : arbitrary shell snippet
   */
  checkType: mysqlEnum("checkType", [
    "file_exists",
    "file_not_exists",
    "command_output",
    "db_query",
    "custom_script",
  ]).notNull(),
  /** Path, command, SQL file path, or script body depending on checkType */
  checkTarget: text("checkTarget").notNull(),
  /** Expected value to compare against (for command_output / db_query) */
  expectedValue: varchar("expectedValue", { length: 512 }),
  /** Comparison operator: eq | ne | contains | gt | lt */
  compareOperator: mysqlEnum("compareOperator", [
    "eq",
    "ne",
    "contains",
    "gt",
    "lt",
  ]).default("eq"),
  /** Points deducted when this check FAILS */
  deductionPoints: int("deductionPoints").default(0).notNull(),
  /** Error message shown in the scoring output */
  failMessage: varchar("failMessage", { length: 512 }),
  sortOrder: int("sortOrder").default(0).notNull(),
  isActive: boolean("isActive").default(true).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type ScoringCheckItem = typeof scoringCheckItems.$inferSelect;
export type InsertScoringCheckItem = typeof scoringCheckItems.$inferInsert;

// ─── Exam Sessions ────────────────────────────────────────────────────────────

export const examSessions = mysqlTable("exam_sessions", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 256 }).notNull(),
  description: text("description"),
  /** Duration in minutes */
  durationMinutes: int("durationMinutes").default(120).notNull(),
  /** Number of questions to randomly draw */
  questionCount: int("questionCount").default(9).notNull(),
  /** JSON array of category IDs to draw from; null = all categories */
  categoryFilter: json("categoryFilter"),
  status: mysqlEnum("status", ["draft", "active", "paused", "ended"]).default("draft").notNull(),
  startedAt: timestamp("startedAt"),
  endedAt: timestamp("endedAt"),
  createdBy: int("createdBy").references(() => users.id),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type ExamSession = typeof examSessions.$inferSelect;
export type InsertExamSession = typeof examSessions.$inferInsert;

// ─── Exam Question Assignments ────────────────────────────────────────────────
// Stores the personalised question set drawn for each student in each exam.

export const examQuestionAssignments = mysqlTable("exam_question_assignments", {
  id: int("id").autoincrement().primaryKey(),
  examId: int("examId")
    .notNull()
    .references(() => examSessions.id),
  studentId: int("studentId")
    .notNull()
    .references(() => students.id),
  questionId: int("questionId")
    .notNull()
    .references(() => questions.id),
  /** Question content after username placeholder replacement */
  personalizedContent: text("personalizedContent"),
  sortOrder: int("sortOrder").default(0).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type ExamQuestionAssignment = typeof examQuestionAssignments.$inferSelect;

// ─── Exam Records ─────────────────────────────────────────────────────────────

export const examRecords = mysqlTable("exam_records", {
  id: int("id").autoincrement().primaryKey(),
  examId: int("examId")
    .notNull()
    .references(() => examSessions.id),
  studentId: int("studentId")
    .notNull()
    .references(() => students.id),
  /** Client-reported Linux username at time of exam */
  clientUsername: varchar("clientUsername", { length: 128 }),
  status: mysqlEnum("status", ["in_progress", "submitted", "graded"]).default("in_progress").notNull(),
  totalScore: float("totalScore"),
  maxPossibleScore: float("maxPossibleScore"),
  /** Duration student actually spent, in seconds */
  durationSeconds: int("durationSeconds"),
  startedAt: timestamp("startedAt").defaultNow().notNull(),
  submittedAt: timestamp("submittedAt"),
  gradedAt: timestamp("gradedAt"),
  /** Raw scoring script output for audit */
  scriptOutput: text("scriptOutput"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type ExamRecord = typeof examRecords.$inferSelect;
export type InsertExamRecord = typeof examRecords.$inferInsert;

// ─── Score Details ────────────────────────────────────────────────────────────

export const scoreDetails = mysqlTable("score_details", {
  id: int("id").autoincrement().primaryKey(),
  examRecordId: int("examRecordId")
    .notNull()
    .references(() => examRecords.id),
  questionId: int("questionId")
    .notNull()
    .references(() => questions.id),
  earnedScore: float("earnedScore").notNull(),
  maxScore: float("maxScore").notNull(),
  /** JSON array of failed check items */
  failedChecks: json("failedChecks"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type ScoreDetail = typeof scoreDetails.$inferSelect;
export type InsertScoreDetail = typeof scoreDetails.$inferInsert;
