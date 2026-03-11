# Linux Exam System - TODO

## Database Schema
- [x] Users table (extended with student_id, class, department)
- [x] Question bank table (questions with categories, difficulty, username placeholder)
- [x] Exam sessions table (exam creation, status control, timing)
- [x] Exam assignments table (student-exam mapping)
- [x] Scoring rules table (configurable check items, deductions, initial scores)
- [x] Scoring check items table (individual check items per question)
- [x] Exam records table (student exam submissions)
- [x] Score details table (per-question scores)

## Backend API (tRPC Routers)
- [x] Auth router (login, logout, me, token management)
- [x] Students router (CRUD, device binding)
- [x] Questions router (CRUD, categories, difficulty filter, username replacement)
- [x] Exams router (create, start/stop, progress monitoring, assign questions)
- [x] Scoring rules router (CRUD for rules and check items, script generation)
- [x] Client API router (agent authentication, question fetch, score upload)
- [x] Reports router (score statistics, distribution, trends, export)

## Frontend Management System
- [x] Dashboard home with stats overview
- [x] Question bank management page (CRUD, categories, search/filter)
- [x] Exam management page (create exam, start/stop, monitor progress)
- [x] Scoring rules configuration page (visual rule editor, check items, script preview)
- [x] Student management page (CRUD, device binding)
- [x] Grade reports page (charts, statistics, export)
- [x] Global theme (elegant deep blue style)
- [x] DashboardLayout navigation (6 modules)

## Data Visualization
- [x] Score distribution chart (histogram)
- [x] Average score trend chart (line chart)
- [x] Per-question error rate analysis (bar chart)
- [x] Student ranking table
- [x] CSV export functionality

## Python Client Agent
- [x] Client username collection
- [x] Device fingerprint generation
- [x] Server authentication (token-based)
- [x] Question fetching from server
- [x] Question display (terminal UI)
- [x] Local scoring script execution
- [x] Score upload to server
- [x] Network exception retry mechanism (3 retries)
- [x] Token expiration handling
- [x] PyInstaller spec file for packaging

## Shell Scoring Script System
- [x] Dynamic script generator (based on backend rules)
- [x] Script template engine (5 check types)
- [x] Database config check rules (db_query)
- [x] File existence check rules (file_exists / file_not_exists)
- [x] Command execution result check rules (command_output)
- [x] Custom script support (custom_script)
- [x] Score calculation and JSON output format
- [x] Script download from server via agent

## Deployment Documentation
- [x] Kylin OS adaptation guide
- [x] DaMeng DM8 database configuration (MySQL compatibility mode)
- [x] Node.js backend deployment steps
- [x] systemd service configuration
- [x] Nginx reverse proxy configuration
- [x] PyInstaller packaging guide
- [x] Client agent distribution plan
- [x] Troubleshooting guide
- [x] Quick deployment checklist

## Testing
- [x] Backend API unit tests (21 tests, all passing)
- [x] Scoring rule engine tests
- [x] Client agent API integration tests
- [x] Auth logout test
