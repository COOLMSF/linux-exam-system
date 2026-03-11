CREATE TABLE `exam_question_assignments` (
	`id` int AUTO_INCREMENT NOT NULL,
	`examId` int NOT NULL,
	`studentId` int NOT NULL,
	`questionId` int NOT NULL,
	`personalizedContent` text,
	`sortOrder` int NOT NULL DEFAULT 0,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `exam_question_assignments_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `exam_records` (
	`id` int AUTO_INCREMENT NOT NULL,
	`examId` int NOT NULL,
	`studentId` int NOT NULL,
	`clientUsername` varchar(128),
	`status` enum('in_progress','submitted','graded') NOT NULL DEFAULT 'in_progress',
	`totalScore` float,
	`maxPossibleScore` float,
	`durationSeconds` int,
	`startedAt` timestamp NOT NULL DEFAULT (now()),
	`submittedAt` timestamp,
	`gradedAt` timestamp,
	`scriptOutput` text,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `exam_records_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `exam_sessions` (
	`id` int AUTO_INCREMENT NOT NULL,
	`name` varchar(256) NOT NULL,
	`description` text,
	`durationMinutes` int NOT NULL DEFAULT 120,
	`questionCount` int NOT NULL DEFAULT 9,
	`categoryFilter` json,
	`status` enum('draft','active','paused','ended') NOT NULL DEFAULT 'draft',
	`startedAt` timestamp,
	`endedAt` timestamp,
	`createdBy` int,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `exam_sessions_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `question_categories` (
	`id` int AUTO_INCREMENT NOT NULL,
	`name` varchar(128) NOT NULL,
	`description` text,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `question_categories_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `questions` (
	`id` int AUTO_INCREMENT NOT NULL,
	`categoryId` int,
	`title` varchar(512) NOT NULL,
	`content` text NOT NULL,
	`difficulty` int NOT NULL DEFAULT 2,
	`maxScore` int NOT NULL DEFAULT 10,
	`sortOrder` int NOT NULL DEFAULT 0,
	`isActive` boolean NOT NULL DEFAULT true,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `questions_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `score_details` (
	`id` int AUTO_INCREMENT NOT NULL,
	`examRecordId` int NOT NULL,
	`questionId` int NOT NULL,
	`earnedScore` float NOT NULL,
	`maxScore` float NOT NULL,
	`failedChecks` json,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `score_details_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `scoring_check_items` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ruleId` int NOT NULL,
	`description` varchar(512) NOT NULL,
	`checkType` enum('file_exists','file_not_exists','command_output','db_query','custom_script') NOT NULL,
	`checkTarget` text NOT NULL,
	`expectedValue` varchar(512),
	`compareOperator` enum('eq','ne','contains','gt','lt') DEFAULT 'eq',
	`deductionPoints` int NOT NULL DEFAULT 0,
	`failMessage` varchar(512),
	`sortOrder` int NOT NULL DEFAULT 0,
	`isActive` boolean NOT NULL DEFAULT true,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `scoring_check_items_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `scoring_rules` (
	`id` int AUTO_INCREMENT NOT NULL,
	`questionId` int NOT NULL,
	`name` varchar(256) NOT NULL,
	`description` text,
	`initialScore` int NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `scoring_rules_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `students` (
	`id` int AUTO_INCREMENT NOT NULL,
	`studentId` varchar(64) NOT NULL,
	`name` varchar(128) NOT NULL,
	`className` varchar(128),
	`department` varchar(128),
	`clientUsername` varchar(128),
	`deviceId` varchar(256),
	`apiToken` varchar(512),
	`tokenExpiresAt` timestamp,
	`isActive` boolean NOT NULL DEFAULT true,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `students_id` PRIMARY KEY(`id`),
	CONSTRAINT `students_studentId_unique` UNIQUE(`studentId`)
);
--> statement-breakpoint
ALTER TABLE `exam_question_assignments` ADD CONSTRAINT `exam_question_assignments_examId_exam_sessions_id_fk` FOREIGN KEY (`examId`) REFERENCES `exam_sessions`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `exam_question_assignments` ADD CONSTRAINT `exam_question_assignments_studentId_students_id_fk` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `exam_question_assignments` ADD CONSTRAINT `exam_question_assignments_questionId_questions_id_fk` FOREIGN KEY (`questionId`) REFERENCES `questions`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `exam_records` ADD CONSTRAINT `exam_records_examId_exam_sessions_id_fk` FOREIGN KEY (`examId`) REFERENCES `exam_sessions`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `exam_records` ADD CONSTRAINT `exam_records_studentId_students_id_fk` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `exam_sessions` ADD CONSTRAINT `exam_sessions_createdBy_users_id_fk` FOREIGN KEY (`createdBy`) REFERENCES `users`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `questions` ADD CONSTRAINT `questions_categoryId_question_categories_id_fk` FOREIGN KEY (`categoryId`) REFERENCES `question_categories`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `score_details` ADD CONSTRAINT `score_details_examRecordId_exam_records_id_fk` FOREIGN KEY (`examRecordId`) REFERENCES `exam_records`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `score_details` ADD CONSTRAINT `score_details_questionId_questions_id_fk` FOREIGN KEY (`questionId`) REFERENCES `questions`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `scoring_check_items` ADD CONSTRAINT `scoring_check_items_ruleId_scoring_rules_id_fk` FOREIGN KEY (`ruleId`) REFERENCES `scoring_rules`(`id`) ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `scoring_rules` ADD CONSTRAINT `scoring_rules_questionId_questions_id_fk` FOREIGN KEY (`questionId`) REFERENCES `questions`(`id`) ON DELETE no action ON UPDATE no action;