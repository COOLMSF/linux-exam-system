/**
 * Linux 考试系统 - 数据库集成测试
 * 测试数据库连接、CRUD 操作、迁移和关系
 * 
 * 运行：pnpm test test_db_integration.test.ts
 */

import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { drizzle } from "drizzle-orm/mysql2";
import mysql from "mysql2/promise";
import * as schema from "../drizzle/schema";
import { eq, sql } from "drizzle-orm";

// ─── 测试配置 ──────────────────────────────────────────────────────────────────

const TEST_DB_NAME = "linux_exam_test";
const TEST_USER = "exam_user";

// 从 .env 读取配置
function getDatabaseConfig() {
  const envPath = process.env.DATABASE_URL || process.env.npm_config_DATABASE_URL;
  
  if (envPath && !envPath.includes("please-change")) {
    // 解析 DATABASE_URL
    const match = envPath.match(/mysql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)/);
    if (match) {
      const [, user, password, host, port, database] = match;
      return {
        host,
        port: parseInt(port),
        user,
        password: decodeURIComponent(password),
        database,
        testDatabase: TEST_DB_NAME,
      };
    }
  }
  
  // 默认配置
  return {
    host: "localhost",
    port: 3306,
    user: "root",
    password: "password",
    database: "linux_exam",
    testDatabase: TEST_DB_NAME,
  };
}

const config = getDatabaseConfig();

// ─── 测试辅助函数 ──────────────────────────────────────────────────────────────

async function createTestDatabase() {
  let connection;
  try {
    connection = await mysql.createConnection({
      host: config.host,
      port: config.port,
      user: config.user,
      password: config.password,
    });
    
    // 创建测试数据库
    await connection.query(`DROP DATABASE IF EXISTS ${TEST_DB_NAME}`);
    await connection.query(`CREATE DATABASE ${TEST_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    console.log(`✓ 测试数据库 ${TEST_DB_NAME} 创建成功`);
  } finally {
    if (connection) await connection.end();
  }
}

async function dropTestDatabase() {
  let connection;
  try {
    connection = await mysql.createConnection({
      host: config.host,
      port: config.port,
      user: config.user,
      password: config.password,
    });
    
    await connection.query(`DROP DATABASE IF EXISTS ${TEST_DB_NAME}`);
    console.log(`✓ 测试数据库 ${TEST_DB_NAME} 已清理`);
  } finally {
    if (connection) await connection.end();
  }
}

async function runMigrations(connection: mysql.Connection) {
  // 读取并执行迁移文件
  const fs = await import("fs");
  const path = await import("path");
  
  const migrationDir = path.join(process.cwd(), "drizzle");
  const files = fs.readdirSync(migrationDir)
    .filter(f => f.endsWith(".sql"))
    .sort();
  
  for (const file of files) {
    const filePath = path.join(migrationDir, file);
    const sqlContent = fs.readFileSync(filePath, "utf-8");
    
    // 分割并执行每个语句
    const statements = sqlContent
      .split("--> statement-breakpoint")
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith("--"));
    
    for (const statement of statements) {
      if (statement.trim()) {
        await connection.query(statement);
      }
    }
  }
}

// ─── 测试套件 ──────────────────────────────────────────────────────────────────

describe("Database Integration Tests", () => {
  let db: ReturnType<typeof drizzle>;
  let mysqlConnection: mysql.Connection;

  // ─── 测试前设置 ──────────────────────────────────────────────────────────────
  
  beforeAll(async () => {
    console.log("\n📋 测试配置:");
    console.log(`  主机：${config.host}:${config.port}`);
    console.log(`  用户：${config.user}`);
    console.log(`  数据库：${config.database}`);
    console.log(`  测试数据库：${TEST_DB_NAME}`);
    
    // 创建测试数据库
    await createTestDatabase();
    
    // 连接到测试数据库
    mysqlConnection = await mysql.createConnection({
      host: config.host,
      port: config.port,
      user: config.user,
      password: config.password,
      database: TEST_DB_NAME,
    });
    
    // 运行迁移
    console.log("\n🔄 运行数据库迁移...");
    await runMigrations(mysqlConnection);
    console.log("✓ 迁移完成");
    
    // 创建 Drizzle ORM 实例
    const testDbUrl = `mysql://${config.user}:${encodeURIComponent(config.password)}@${config.host}:${config.port}/${TEST_DB_NAME}`;
    db = drizzle(testDbUrl, { schema, mode: "default" });
  }, 30000);

  // ─── 测试后清理 ──────────────────────────────────────────────────────────────
  
  afterAll(async () => {
    if (mysqlConnection) {
      await mysqlConnection.end();
    }
    await dropTestDatabase();
  });

  // ─── 单元测试 ────────────────────────────────────────────────────────────────
  
  describe("Database Connection", () => {
    it("should connect to database successfully", async () => {
      const result = await mysqlConnection.query("SELECT 1 as test");
      expect(result[0]).toEqual([{ test: 1 }]);
    });

    it("should have correct character set", async () => {
      const result = await mysqlConnection.query(
        `SELECT DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME 
         FROM information_schema.SCHEMATA 
         WHERE SCHEMA_NAME = ?`,
        [TEST_DB_NAME]
      );
      expect((result[0] as any)[0]).toMatchObject({
        DEFAULT_CHARACTER_SET_NAME: "utf8mb4",
        DEFAULT_COLLATION_NAME: "utf8mb4_unicode_ci",
      });
    });
  });

  describe("Database Schema", () => {
    it("should have all required tables", async () => {
      const requiredTables = [
        "users",
        "students",
        "question_categories",
        "questions",
        "scoring_rules",
        "scoring_check_items",
        "exam_sessions",
        "exam_question_assignments",
        "exam_records",
        "score_details",
      ];

      const result = await mysqlConnection.query(
        `SELECT TABLE_NAME FROM information_schema.TABLES 
         WHERE TABLE_SCHEMA = ?`,
        [TEST_DB_NAME]
      );

      const tables = (result[0] as any[]).map(r => r.TABLE_NAME);
      
      for (const table of requiredTables) {
        expect(tables).toContain(table);
      }
    });

    it("users table should have correct columns", async () => {
      const result = await mysqlConnection.query(
        `SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
         FROM information_schema.COLUMNS 
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users'
         ORDER BY ORDINAL_POSITION`,
        [TEST_DB_NAME]
      );

      const columns = (result[0] as any[]).map(c => c.COLUMN_NAME);
      const expectedColumns = [
        "id", "openId", "name", "email", "loginMethod", 
        "passwordHash", "role", "createdAt", "updatedAt", "lastSignedIn"
      ];

      for (const col of expectedColumns) {
        expect(columns).toContain(col);
      }
    });

    it("should have foreign key constraints", async () => {
      const result = await mysqlConnection.query(
        `SELECT COUNT(*) as count FROM information_schema.TABLE_CONSTRAINTS 
         WHERE CONSTRAINT_SCHEMA = ? AND CONSTRAINT_TYPE = 'FOREIGN KEY'`,
        [TEST_DB_NAME]
      );

      const count = (result[0] as any)[0].count;
      expect(parseInt(count)).toBeGreaterThan(0);
    });
  });

  describe("User CRUD Operations", () => {
    const testOpenId = `test_user_${Date.now()}`;
    let userId: number;

    it("should insert a user", async () => {
      const insertResult = await db.insert(schema.users).values({
        openId: testOpenId,
        name: "Test User",
        email: "test@example.com",
        loginMethod: "test",
        role: "user",
        lastSignedIn: new Date(),
      });

      userId = insertResult[0].insertId as number;
      expect(userId).toBeGreaterThan(0);
    });

    it("should query user by openId", async () => {
      const user = await db.query.users.findFirst({
        where: eq(schema.users.openId, testOpenId),
      });

      expect(user).toBeDefined();
      expect(user?.name).toBe("Test User");
      expect(user?.email).toBe("test@example.com");
    });

    it("should update user", async () => {
      await db.update(schema.users)
        .set({ name: "Updated User" })
        .where(eq(schema.users.openId, testOpenId));

      const user = await db.query.users.findFirst({
        where: eq(schema.users.openId, testOpenId),
      });

      expect(user?.name).toBe("Updated User");
    });

    it("should delete user", async () => {
      await db.delete(schema.users).where(eq(schema.users.openId, testOpenId));

      const user = await db.query.users.findFirst({
        where: eq(schema.users.openId, testOpenId),
      });

      expect(user).toBeUndefined();
    });
  });

  describe("Student CRUD Operations", () => {
    const testStudentId = `test_student_${Date.now()}`;
    let studentId: number;

    it("should insert a student", async () => {
      const insertResult = await db.insert(schema.students).values({
        studentId: testStudentId,
        name: "测试学生",
        className: "测试班级",
        department: "测试院系",
        isActive: true,
      });

      studentId = insertResult[0].insertId as number;
      expect(studentId).toBeGreaterThan(0);
    });

    it("should query student by studentId", async () => {
      const student = await db.query.students.findFirst({
        where: eq(schema.students.studentId, testStudentId),
      });

      expect(student).toBeDefined();
      expect(student?.name).toBe("测试学生");
      expect(student?.className).toBe("测试班级");
    });

    it("should update student", async () => {
      await db.update(schema.students)
        .set({ name: "更新后的学生" })
        .where(eq(schema.students.studentId, testStudentId));

      const student = await db.query.students.findFirst({
        where: eq(schema.students.studentId, testStudentId),
      });

      expect(student?.name).toBe("更新后的学生");
    });

    it("should delete student", async () => {
      await db.delete(schema.students).where(eq(schema.students.id, studentId));

      const student = await db.query.students.findFirst({
        where: eq(schema.students.studentId, testStudentId),
      });

      expect(student).toBeUndefined();
    });
  });

  describe("Question Category and Question Operations", () => {
    let categoryId: number;
    let questionId: number;

    it("should insert a question category", async () => {
      const insertResult = await db.insert(schema.questionCategories).values({
        name: "测试分类",
        description: "测试题目分类",
      });

      categoryId = insertResult[0].insertId as number;
      expect(categoryId).toBeGreaterThan(0);
    });

    it("should insert a question", async () => {
      const insertResult = await db.insert(schema.questions).values({
        categoryId,
        title: "测试题目",
        content: "这是测试题目的内容",
        difficulty: 2,
        maxScore: 10,
        sortOrder: 1,
        isActive: true,
      });

      questionId = insertResult[0].insertId as number;
      expect(questionId).toBeGreaterThan(0);
    });

    it("should query questions with category", async () => {
      const questions = await db.query.questions.findMany({
        where: eq(schema.questions.categoryId, categoryId),
        with: {
          category: true,
        },
      });

      expect(questions.length).toBeGreaterThan(0);
      expect(questions[0].category).toBeDefined();
      expect(questions[0].category?.name).toBe("测试分类");
    });

    it("should update question", async () => {
      await db.update(schema.questions)
        .set({ title: "更新后的题目", maxScore: 15 })
        .where(eq(schema.questions.id, questionId));

      const question = await db.query.questions.findFirst({
        where: eq(schema.questions.id, questionId),
      });

      expect(question?.title).toBe("更新后的题目");
      expect(question?.maxScore).toBe(15);
    });

    it("should delete question and category", async () => {
      await db.delete(schema.questions).where(eq(schema.questions.id, questionId));
      await db.delete(schema.questionCategories).where(eq(schema.questionCategories.id, categoryId));

      const question = await db.query.questions.findFirst({
        where: eq(schema.questions.id, questionId),
      });
      const category = await db.query.questionCategories.findFirst({
        where: eq(schema.questionCategories.id, categoryId),
      });

      expect(question).toBeUndefined();
      expect(category).toBeUndefined();
    });
  });

  describe("Exam Session Operations", () => {
    let categoryId: number;
    let examId: number;

    beforeAll(async () => {
      // 创建分类
      const catResult = await db.insert(schema.questionCategories).values({
        name: "考试分类",
        description: "用于考试",
      });
      categoryId = catResult[0].insertId as number;

      // 创建题目
      for (let i = 0; i < 5; i++) {
        await db.insert(schema.questions).values({
          categoryId,
          title: `题目 ${i + 1}`,
          content: `题目内容 ${i + 1}`,
          difficulty: 2,
          maxScore: 10,
          sortOrder: i,
          isActive: true,
        });
      }
    });

    afterAll(async () => {
      // 清理数据
      await db.delete(schema.questions).where(eq(schema.questions.categoryId, categoryId));
      await db.delete(schema.questionCategories).where(eq(schema.questionCategories.id, categoryId));
    });

    it("should create an exam session", async () => {
      const insertResult = await db.insert(schema.examSessions).values({
        name: "测试考试",
        description: "这是一次测试考试",
        durationMinutes: 120,
        questionCount: 3,
        status: "draft",
        categoryFilter: [categoryId],
      });

      examId = insertResult[0].insertId as number;
      expect(examId).toBeGreaterThan(0);
    });

    it("should query exam session", async () => {
      const exam = await db.query.examSessions.findFirst({
        where: eq(schema.examSessions.id, examId),
      });

      expect(exam).toBeDefined();
      expect(exam?.name).toBe("测试考试");
      expect(exam?.durationMinutes).toBe(120);
      expect(exam?.status).toBe("draft");
    });

    it("should update exam session status", async () => {
      await db.update(schema.examSessions)
        .set({ status: "active" })
        .where(eq(schema.examSessions.id, examId));

      const exam = await db.query.examSessions.findFirst({
        where: eq(schema.examSessions.id, examId),
      });

      expect(exam?.status).toBe("active");
    });

    it("should delete exam session", async () => {
      await db.delete(schema.examSessions).where(eq(schema.examSessions.id, examId));

      const exam = await db.query.examSessions.findFirst({
        where: eq(schema.examSessions.id, examId),
      });

      expect(exam).toBeUndefined();
    });
  });

  describe("Scoring Rules and Check Items", () => {
    let questionId: number;
    let ruleId: number;

    beforeAll(async () => {
      // 创建题目
      const qResult = await db.insert(schema.questions).values({
        categoryId: null,
        title: "评分测试题目",
        content: "测试内容",
        difficulty: 2,
        maxScore: 10,
        sortOrder: 0,
        isActive: true,
      });
      questionId = qResult[0].insertId as number;
    });

    afterAll(async () => {
      await db.delete(schema.questions).where(eq(schema.questions.id, questionId));
    });

    it("should create a scoring rule", async () => {
      const insertResult = await db.insert(schema.scoringRules).values({
        questionId,
        name: "评分规则",
        description: "测试评分规则",
        initialScore: 10,
      });

      ruleId = insertResult[0].insertId as number;
      expect(ruleId).toBeGreaterThan(0);
    });

    it("should create scoring check items", async () => {
      const items = [
        {
          ruleId,
          description: "检查文件是否存在",
          checkType: "file_exists" as const,
          checkTarget: "/tmp/test.txt",
          deductionPoints: 5,
          sortOrder: 1,
          isActive: true,
        },
        {
          ruleId,
          description: "检查命令输出",
          checkType: "command_output" as const,
          checkTarget: "echo hello",
          expectedValue: "hello",
          compareOperator: "eq" as const,
          deductionPoints: 3,
          sortOrder: 2,
          isActive: true,
        },
      ];

      for (const item of items) {
        const result = await db.insert(schema.scoringCheckItems).values(item);
        expect(result[0].insertId).toBeGreaterThan(0);
      }

      // 验证插入
      const checkItems = await db.query.scoringCheckItems.findMany({
        where: eq(schema.scoringCheckItems.ruleId, ruleId),
      });

      expect(checkItems.length).toBe(2);
    });

    it("should query scoring rule with check items", async () => {
      const rule = await db.query.scoringRules.findFirst({
        where: eq(schema.scoringRules.questionId, questionId),
        with: {
          checkItems: true,
        },
      });

      expect(rule).toBeDefined();
      expect(rule?.checkItems).toHaveLength(2);
    });

    it("should delete scoring rule and check items", async () => {
      await db.delete(schema.scoringCheckItems).where(eq(schema.scoringCheckItems.ruleId, ruleId));
      await db.delete(schema.scoringRules).where(eq(schema.scoringRules.questionId, questionId));

      const rule = await db.query.scoringRules.findFirst({
        where: eq(schema.scoringRules.questionId, questionId),
      });

      expect(rule).toBeUndefined();
    });
  });

  describe("Exam Record and Score Details", () => {
    let studentId: number;
    let examId: number;
    let recordId: number;

    beforeAll(async () => {
      // 创建学生
      const sResult = await db.insert(schema.students).values({
        studentId: `score_test_${Date.now()}`,
        name: "测试学生",
        isActive: true,
      });
      studentId = sResult[0].insertId as number;

      // 创建考试
      const eResult = await db.insert(schema.examSessions).values({
        name: "评分测试考试",
        durationMinutes: 60,
        questionCount: 2,
        status: "active",
      });
      examId = eResult[0].insertId as number;
    });

    afterAll(async () => {
      await db.delete(schema.students).where(eq(schema.students.id, studentId));
      await db.delete(schema.examSessions).where(eq(schema.examSessions.id, examId));
    });

    it("should create an exam record", async () => {
      const insertResult = await db.insert(schema.examRecords).values({
        examId,
        studentId,
        clientUsername: "test_user",
        status: "in_progress",
        startedAt: new Date(),
      });

      recordId = insertResult[0].insertId as number;
      expect(recordId).toBeGreaterThan(0);
    });

    it("should update exam record with score", async () => {
      await db.update(schema.examRecords)
        .set({
          status: "submitted",
          totalScore: 85,
          maxPossibleScore: 100,
          durationSeconds: 3600,
          submittedAt: new Date(),
        })
        .where(eq(schema.examRecords.id, recordId));

      const record = await db.query.examRecords.findFirst({
        where: eq(schema.examRecords.id, recordId),
      });

      expect(record?.status).toBe("submitted");
      expect(record?.totalScore).toBe(85);
      expect(record?.maxPossibleScore).toBe(100);
    });

    it("should create score details", async () => {
      const scoreDetailsData = [
        {
          examRecordId: recordId,
          questionId: 1,
          earnedScore: 8,
          maxScore: 10,
          failedChecks: [{ item: "check1", reason: "failed" }],
        },
        {
          examRecordId: recordId,
          questionId: 2,
          earnedScore: 9,
          maxScore: 10,
          failedChecks: null,
        },
      ];

      for (const detail of scoreDetailsData) {
        const result = await db.insert(schema.scoreDetails).values(detail);
        expect(result[0].insertId).toBeGreaterThan(0);
      }

      // 验证插入
      const details = await db.query.scoreDetails.findMany({
        where: eq(schema.scoreDetails.examRecordId, recordId),
      });

      expect(details.length).toBe(2);
    });

    it("should query exam record with score details", async () => {
      const record = await db.query.examRecords.findFirst({
        where: eq(schema.examRecords.id, recordId),
      });

      expect(record).toBeDefined();
      expect(record?.totalScore).toBe(85);

      const details = await db.query.scoreDetails.findMany({
        where: eq(schema.scoreDetails.examRecordId, recordId),
      });

      expect(details.length).toBe(2);
      expect(details.reduce((sum, d) => sum + d.earnedScore, 0)).toBe(17);
    });

    it("should cleanup exam record and score details", async () => {
      await db.delete(schema.scoreDetails).where(eq(schema.scoreDetails.examRecordId, recordId));
      await db.delete(schema.examRecords).where(eq(schema.examRecords.id, recordId));

      const record = await db.query.examRecords.findFirst({
        where: eq(schema.examRecords.id, recordId),
      });

      expect(record).toBeUndefined();
    });
  });

  describe("Database Performance", () => {
    it("should handle multiple concurrent connections", async () => {
      const connections: mysql.Connection[] = [];
      
      try {
        // 创建 10 个并发连接
        for (let i = 0; i < 10; i++) {
          const conn = await mysql.createConnection({
            host: config.host,
            port: config.port,
            user: config.user,
            password: config.password,
            database: TEST_DB_NAME,
          });
          connections.push(conn);
        }

        // 所有连接执行查询
        const promises = connections.map((conn, i) => 
          conn.query(`SELECT ${i} as test`)
        );

        const results = await Promise.all(promises);
        
        expect(results.length).toBe(10);
        results.forEach((result, i) => {
          expect((result[0] as any)[0].test).toBe(i);
        });
      } finally {
        // 关闭所有连接
        for (const conn of connections) {
          await conn.end();
        }
      }
    });

    it("should have acceptable query latency", async () => {
      const startTime = Date.now();
      
      await db.query.users.findMany({ limit: 1 });
      
      const latency = Date.now() - startTime;
      
      // 延迟应小于 100ms
      expect(latency).toBeLessThan(100);
      console.log(`  Query latency: ${latency}ms`);
    });
  });
});
