-- DM8 compatible schema for exam system

CREATE TABLE exams (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description CLOB,
    status VARCHAR(20) DEFAULT 'draft',
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE students (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    student_no VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    class_name VARCHAR(100),
    is_active SMALLINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE agents (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    agent_id VARCHAR(64) NOT NULL UNIQUE,
    student_id BIGINT NOT NULL,
    hostname VARCHAR(120),
    os_version VARCHAR(120),
    last_seen_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'offline',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_agents_student FOREIGN KEY (student_id) REFERENCES students(id)
);

CREATE TABLE results (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    exam_id BIGINT NOT NULL,
    student_id BIGINT NOT NULL,
    agent_id VARCHAR(64) NOT NULL,
    score INT NOT NULL,
    detail_json CLOB,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_results_exam FOREIGN KEY (exam_id) REFERENCES exams(id),
    CONSTRAINT fk_results_student FOREIGN KEY (student_id) REFERENCES students(id)
);

CREATE INDEX idx_results_exam ON results(exam_id);
CREATE INDEX idx_results_student ON results(student_id);
CREATE INDEX idx_agents_student ON agents(student_id);
