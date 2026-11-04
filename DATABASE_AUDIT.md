# DATABASE_AUDIT.md — PostgreSQL Schema, Indexing & Integrity Audit

**Date**: November 4, 2026  
**Target Environment**: Neon Serverless PostgreSQL (`ep-orange-frost-beug30ej-pooler.c-9.us-east-2.aws.neon.tech`)  
**Database**: `neondb` (PostgreSQL 16)  
**Auditor**: Principal Database Architect  

---

## 1. Executive Summary

A comprehensive inspection of all PostgreSQL tables, indexes, constraints, and relationships in the live cloud database was executed using SQLAlchemy reflection and direct PostgreSQL information schema queries. 

The schema contains 11 core tables with valid primary keys and basic foreign keys. However, several critical database design flaws exist:
1. **Missing Indexes on Foreign Key Columns**: Several high-frequency foreign keys lack B-Tree indexes, triggering sequential table scans during join operations and user filtering.
2. **Missing Business Constraints**: Tasks and comments lack client-visibility and internal communication flags required for multi-role client data isolation.
3. **Enum Type Limitation**: The `userrole` enum only defines `admin`, `project_manager`, and `developer`. It lacks `employee` and `client`.
4. **Unversioned Database Schema**: Tables were generated via `Base.metadata.create_all()` rather than tracked versioned Alembic revisions; `alembic_version` is missing from the database.

---

## 2. Table-by-Table Technical Audit

### 2.1 Table: `users`
- **Columns**: `id`, `email`, `hashed_password`, `full_name`, `role`, `status`, `is_active`, `phone_number`, `company`, `department`, `job_title`, `avatar_url`, `last_login_at`, `deleted_at`, `created_at`, `updated_at`.
- **Existing Constraints**:
  - Primary Key: `users_pkey` on `id`.
  - Indexes: `ix_users_email` (Unique), `ix_users_status`, `ix_users_deleted_at`, `ix_users_id`.
- **Issues Identified**:
  - **Issue DB-01**: `role` column uses `VARCHAR(15)` or `userrole` enum without `employee` or `client` values.
    - **Severity**: **CRITICAL**
    - **Impact**: Cannot store clients or standard employees without schema violation.
    - **Fix**: Run `ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'employee';` and `ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'client';` (or standardize varchar check constraint).
  - **Issue DB-02**: Missing compound index on `(company, status, role)`. As the user directory grows, filtering employees within a company will degrade without a composite index.
    - **Severity**: **MEDIUM**
    - **Fix**: Add composite index `idx_users_company_status_role`.

### 2.2 Table: `projects`
- **Columns**: `id`, `title`, `description`, `status`, `priority`, `start_date`, `due_date`, `budget_hours`, `owner_id`, `created_at`, `updated_at`.
- **Existing Constraints**:
  - Primary Key: `projects_pkey` on `id`.
  - Foreign Key: `projects_owner_id_fkey` -> `users.id` (ON DELETE CASCADE).
  - Indexes: `ix_projects_title`, `ix_projects_status`, `ix_projects_due_date`, `ix_projects_id`.
- **Issues Identified**:
  - **Issue DB-03**: Foreign key `owner_id` is **NOT indexed**. When filtering projects by owner or performing cascade deletes, PostgreSQL must perform a full sequential scan on `projects`.
    - **Severity**: **HIGH**
    - **Impact**: High CPU consumption on relational joins and delete operations.
    - **Fix**: Add index `idx_projects_owner_id ON projects(owner_id)`.
  - **Issue DB-04**: Missing `client_id` foreign key. Projects cannot be explicitly associated with a primary Client account.
    - **Severity**: **HIGH**
    - **Fix**: Add `client_id INTEGER REFERENCES users(id) ON DELETE SET NULL` with index `idx_projects_client_id`.

### 2.3 Table: `project_members`
- **Columns**: `id`, `project_id`, `user_id`, `role_in_project`, `joined_at`.
- **Existing Constraints**:
  - Primary Key: `project_members_pkey` on `id`.
  - Unique Constraint: `uq_project_user` on `(project_id, user_id)`.
  - Foreign Keys: `project_members_project_id_fkey`, `project_members_user_id_fkey` (ON DELETE CASCADE).
- **Issues Identified**:
  - **Issue DB-05**: Column `user_id` is only the second column in the composite unique index `(project_id, user_id)`. Queries that look up all projects for a user (`WHERE user_id = :uid`) **cannot use the index efficiently**!
    - **Severity**: **HIGH**
    - **Impact**: Slow dashboard queries for employees and clients loading their assigned projects.
    - **Fix**: Add single-column index `idx_project_members_user_id ON project_members(user_id)`.

### 2.4 Table: `tasks`
- **Columns**: `id`, `project_id`, `title`, `description`, `status`, `priority`, `due_date`, `estimated_hours`, `actual_hours`, `creator_id`, `assignee_id`, `created_at`, `updated_at`.
- **Existing Constraints**:
  - Primary Key: `tasks_pkey` on `id`.
  - Foreign Keys: `tasks_project_id_fkey`, `tasks_creator_id_fkey`, `tasks_assignee_id_fkey`.
  - Indexes: `ix_tasks_project_id`, `ix_tasks_assignee_id`, `ix_tasks_status`, `ix_tasks_priority`, `ix_tasks_due_date`, `ix_tasks_title`, `ix_tasks_id`.
- **Issues Identified**:
  - **Issue DB-06**: Foreign key `creator_id` is unindexed.
    - **Severity**: **MEDIUM**
    - **Fix**: Add index `idx_tasks_creator_id ON tasks(creator_id)`.
  - **Issue DB-07**: Missing `is_client_visible` boolean column (defaults to `true`). Without this, clients see all internal engineering tasks, spikes, and sensitive refactor items.
    - **Severity**: **HIGH**
    - **Fix**: Add column `is_client_visible BOOLEAN NOT NULL DEFAULT TRUE` with index.
  - **Issue DB-08**: Missing composite index `(project_id, status)` and `(assignee_id, status)`. The task board constantly filters tasks by project and status simultaneously.
    - **Severity**: **HIGH**
    - **Fix**: Add composite indexes `idx_tasks_project_status` and `idx_tasks_assignee_status`.

### 2.5 Table: `task_comments`
- **Columns**: `id`, `task_id`, `author_id`, `content`, `created_at`, `updated_at`.
- **Existing Constraints**:
  - Primary Key: `task_comments_pkey` on `id`.
  - Foreign Keys: `task_comments_task_id_fkey`, `task_comments_author_id_fkey`.
  - Indexes: `ix_task_comments_task_id`, `ix_task_comments_id`.
- **Issues Identified**:
  - **Issue DB-09**: Missing `is_internal` boolean flag. Internal staff notes cannot be hidden from client users.
    - **Severity**: **CRITICAL**
    - **Fix**: Add column `is_internal BOOLEAN NOT NULL DEFAULT FALSE` and filter out `is_internal=true` for Client role.
  - **Issue DB-10**: `author_id` foreign key is unindexed.
    - **Severity**: **MEDIUM**
    - **Fix**: Add index `idx_task_comments_author_id ON task_comments(author_id)`.

### 2.6 Table: `user_audit_logs` & `task_history`
- **Columns**: `id`, `actor_id`, `target_user_id`, `action`, `details`, `ip_address`, `created_at`.
- **Issues Identified**:
  - **Issue DB-11**: `actor_id` and `target_user_id` lack indexes. Admin audit log searches by user or actor perform full table scans.
    - **Severity**: **MEDIUM**
    - **Fix**: Add indexes `idx_audit_logs_actor_id` and `idx_audit_logs_target_user_id`.

---

## 3. Database Migration Management

- **Current Status**: Alembic migration scripts exist in repository (`backend/alembic/versions/001_add_user_management_module.py`), but the `alembic_version` table is missing from the production database because initial deployment executed `create_all()`.
- **Risk**: Future automated Alembic migrations will fail with `relation "users" already exists` if executed blindly.
- **Remediation**:
  1. Stamp the production database with baseline revision: `alembic stamp 001_user_mgmt`.
  2. Author a clean, forward-only, idempotent migration `002_add_four_roles_and_client_isolation.py`.
  3. Ensure all table modifications use `IF NOT EXISTS` guards.
