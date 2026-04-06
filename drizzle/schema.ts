import {
  bigint,
  boolean,
  int,
  json,
  mysqlTable,
  text,
  timestamp,
  varchar,
} from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  openId: varchar("openId", { length: 191 }).notNull().unique(),
  name: varchar("name", { length: 120 }),
  email: varchar("email", { length: 191 }),
  loginMethod: varchar("loginMethod", { length: 50 }),
  role: varchar("role", { length: 20 }).notNull().default("teacher"),
  passwordHash: varchar("passwordHash", { length: 255 }),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
  lastSignedIn: timestamp("lastSignedIn"),
});

export const students = mysqlTable("students", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  studentId: varchar("studentId", { length: 64 }).notNull().unique(),
  name: varchar("name", { length: 100 }).notNull(),
  className: varchar("className", { length: 100 }),
  department: varchar("department", { length: 100 }),
  clientUsername: varchar("clientUsername", { length: 100 }),
  isActive: boolean("isActive").notNull().default(true),
  apiToken: varchar("apiToken", { length: 191 }),
  tokenExpiresAt: timestamp("tokenExpiresAt"),
  deviceId: varchar("deviceId", { length: 100 }),
  passwordHash: varchar("passwordHash", { length: 255 }),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
  updatedAt: timestamp("updatedAt").notNull().defaultNow().onUpdateNow(),
});

export const questionCategories = mysqlTable("question_categories", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  name: varchar("name", { length: 100 }).notNull().unique(),
  description: text("description"),
});

export const questions = mysqlTable("questions", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  title: varchar("title", { length: 200 }).notNull(),
  content: text("content").notNull(),
  categoryId: bigint("categoryId", { mode: "number", unsigned: true }),
  difficulty: int("difficulty").notNull().default(2),
  maxScore: int("maxScore").notNull().default(10),
  sortOrder: int("sortOrder").notNull().default(0),
  isActive: boolean("isActive").notNull().default(true),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
  updatedAt: timestamp("updatedAt").notNull().defaultNow().onUpdateNow(),
});

export const scoringRules = mysqlTable("scoring_rules", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  questionId: bigint("questionId", { mode: "number", unsigned: true }).notNull(),
  name: varchar("name", { length: 200 }).notNull(),
  description: text("description"),
  initialScore: int("initialScore").notNull().default(10),
});

export const scoringCheckItems = mysqlTable("scoring_check_items", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  ruleId: bigint("ruleId", { mode: "number", unsigned: true }).notNull(),
  description: varchar("description", { length: 300 }).notNull(),
  checkType: varchar("checkType", { length: 50 }).notNull(),
  checkTarget: text("checkTarget").notNull(),
  expectedValue: text("expectedValue"),
  compareOperator: varchar("compareOperator", { length: 20 }).default("eq"),
  deductionPoints: int("deductionPoints").notNull().default(0),
  failMessage: text("failMessage"),
  sortOrder: int("sortOrder").notNull().default(0),
  isActive: boolean("isActive").notNull().default(true),
});

export const examSessions = mysqlTable("exam_sessions", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  name: varchar("name", { length: 200 }).notNull(),
  description: text("description"),
  durationMinutes: int("durationMinutes").notNull().default(120),
  questionCount: int("questionCount").notNull().default(9),
  status: varchar("status", { length: 20 }).notNull().default("draft"),
  categoryFilter: json("categoryFilter"),
  startedAt: timestamp("startedAt"),
  endedAt: timestamp("endedAt"),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
});

export const examQuestionAssignments = mysqlTable("exam_question_assignments", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  examId: bigint("examId", { mode: "number", unsigned: true }).notNull(),
  studentId: bigint("studentId", { mode: "number", unsigned: true }).notNull(),
  questionId: bigint("questionId", { mode: "number", unsigned: true }).notNull(),
  personalizedContent: text("personalizedContent").notNull(),
  sortOrder: int("sortOrder").notNull().default(0),
  questionSet: varchar("questionSet", { length: 10 }), // Added for question set identification
});

export const examRecords = mysqlTable("exam_records", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  examId: bigint("examId", { mode: "number", unsigned: true }).notNull(),
  studentId: bigint("studentId", { mode: "number", unsigned: true }).notNull(),
  clientUsername: varchar("clientUsername", { length: 100 }),
  questionSet: varchar("questionSet", { length: 10 }), // Added for question set identification
  status: varchar("status", { length: 20 }).notNull().default("in_progress"),
  totalScore: int("totalScore"),
  maxPossibleScore: int("maxPossibleScore"),
  durationSeconds: int("durationSeconds"),
  scriptOutput: text("scriptOutput"),
  startedAt: timestamp("startedAt").notNull().defaultNow(),
  submittedAt: timestamp("submittedAt"),
  gradedAt: timestamp("gradedAt"),
  completedAt: timestamp("completedAt"),
});

export const scoreDetails = mysqlTable("score_details", {
  id: bigint("id", { mode: "number", unsigned: true }).autoincrement().primaryKey(),
  examRecordId: bigint("examRecordId", { mode: "number", unsigned: true }).notNull(),
  questionId: bigint("questionId", { mode: "number", unsigned: true }).notNull(),
  earnedScore: int("earnedScore").notNull(),
  maxScore: int("maxScore").notNull(),
  failedChecks: json("failedChecks"),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;
export type InsertStudent = typeof students.$inferInsert;
export type InsertQuestion = typeof questions.$inferInsert;
export type InsertScoringRule = typeof scoringRules.$inferInsert;
export type InsertScoringCheckItem = typeof scoringCheckItems.$inferInsert;
export type InsertExamSession = typeof examSessions.$inferInsert;
export type InsertExamRecord = typeof examRecords.$inferInsert;
