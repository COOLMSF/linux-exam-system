-- MySQL 8 compatible schema (same logical model)

CREATE TABLE IF NOT EXISTS exams (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    status VARCHAR(20) DEFAULT 'draft',
    start_time DATETIME NULL,
    end_time DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS students (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_no VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    class_name VARCHAR(100) NULL,
    is_active TINYINT(1) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agents (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    agent_id VARCHAR(64) NOT NULL UNIQUE,
    student_id BIGINT NOT NULL,
    hostname VARCHAR(120) NULL,
    os_version VARCHAR(120) NULL,
    last_seen_at DATETIME NULL,
    status VARCHAR(20) DEFAULT 'offline',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_agents_student FOREIGN KEY (student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS results (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    exam_id BIGINT NOT NULL,
    student_id BIGINT NOT NULL,
    agent_id VARCHAR(64) NOT NULL,
    score INT NOT NULL,
    detail_json TEXT NULL,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_results_exam FOREIGN KEY (exam_id) REFERENCES exams(id),
    CONSTRAINT fk_results_student FOREIGN KEY (student_id) REFERENCES students(id)
);

CREATE INDEX idx_results_exam ON results(exam_id);
CREATE INDEX idx_results_student ON results(student_id);
CREATE INDEX idx_agents_student ON agents(student_id);
