# PROJECT_AUDIT.md — TaskForge Architecture & Codebase Audit

**Date**: November 4, 2026  
**Auditor**: Senior Software Architect & Principal Systems Engineer  
**Classification**: Engineering Transformation — Phase 1  
**Project**: TaskForge Enterprise Project Management System  

---

## 1. Executive Summary

TaskForge is an enterprise project management application structured with a Flutter Web frontend, a Python FastAPI backend, and a PostgreSQL database (hosted on Neon Serverless PostgreSQL). A deep codebase inspection was performed across all frontend components, backend services, database models, and deployment configurations.

While the core user interface and basic REST API primitives are functioning, **the application currently operates in a hybrid demo state**. Significant architectural gaps exist between visible UI features and complete backend data flows, specifically in role-based authorization (RBAC), multi-tenant client data isolation, session lifecycle management, and database referential integrity.

---

## 2. Frontend Architecture Audit (Flutter Web)

### 2.1 Project Structure & State Management
- **Pattern**: Provider-based MVVM (Model-View-ViewModel) pattern located in `frontend/lib/viewmodels/`.
  - `AuthViewModel`, `ProjectViewModel`, `TaskViewModel`, `UserViewModel`, `NotificationViewModel`, `ThemeViewModel`.
- **Finding**: ViewModels maintain local in-memory fallback state (`_demoUsers`, `_demoProjects`, `_demoTasks`) in repositories (`user_repository.dart`, `project_repository.dart`, `task_repository.dart`). When backend API calls return HTML or fail with connection errors, the UI seamlessly falls back to in-memory mutations.
  - **Evidence**: `frontend/lib/repositories/user_repository.dart` line 250 (`if (_isNetworkFailure(e)) { final newUser = ...; _demoUsers.insert(0, newUser); }`).
  - **Severity**: **HIGH**
  - **Business Impact**: Users assume their created tasks or invited employees are saved to the enterprise database, but upon page reload or cache clear, all offline data vanishes.
  - **Recommended Fix**: Enforce distinct UI states for online vs offline modes. If connected to a production API, display real persistence failures to the user rather than masking them with temporary in-memory mock records.

### 2.2 Navigation & Route Guards
- **Routing**: `GoRouter` configured in `frontend/lib/core/routes/app_router.dart`.
- **Finding**: Route guards check `authViewModel.isAuthenticated`, but granular resource-level permission checks (e.g., verifying whether an Employee or Client belongs to `/projects/:id` or `/tasks/:id`) are absent in the router.
  - **Evidence**: `frontend/lib/core/routes/app_router.dart` line 90-95 mounts `ProjectDetailView(projectId: id)` without verifying membership.
  - **Severity**: **MEDIUM**
  - **Business Impact**: Unauthorized users can manually enter URLs to view project pages they do not belong to.
  - **Recommended Fix**: Add a centralized authorization resolver that checks project and task membership before rendering details.

### 2.3 Role Modeling Discrepancy
- **Finding**: The UI model only defines 3 roles (`admin`, `projectManager`, `developer`). The enterprise specification requires 4 distinct roles: **Admin**, **Project Manager**, **Employee**, and **Client**.
  - **Evidence**: `frontend/lib/models/user_model.dart` lines 1-17 (`enum UserRole { admin, projectManager, developer }`).
  - **Severity**: **HIGH**
  - **Business Impact**: The application cannot currently distinguish between internal Employees and external Clients, exposing sensitive company data to clients.
  - **Recommended Fix**: Refactor `UserRole` enum to support `admin`, `project_manager`, `employee`, and `client`, updating serialization and role display adapters.

---

## 3. Backend Architecture Audit (FastAPI)

### 3.1 Project Structure & Layering
- **Structure**:
  - `backend/app/api/v1/endpoints/`: HTTP route handlers.
  - `backend/app/services/`: Business logic.
  - `backend/app/repositories/`: Database query layer.
  - `backend/app/models/`: SQLAlchemy ORM models.
  - `backend/app/schemas/`: Pydantic validation schemas.
- **Finding**: Layer separation is well-structured; however, authorization checks are inconsistently divided. Some endpoints check roles in router decorators (`require_roles`), while others perform checks inside services, and some have no checks at all.
  - **Evidence**: `backend/app/api/v1/endpoints/projects.py` line 55 uses `require_roles`, while `backend/app/api/v1/endpoints/tasks.py` line 60 has no role restrictions.
  - **Severity**: **HIGH**
  - **Business Impact**: Inconsistent security boundaries lead to privilege escalation and data leakage.
  - **Recommended Fix**: Unify authorization using a centralized policy enforcer dependency.

### 3.2 Database Session & Transaction Lifecycle
- **Finding**: Sessions are injected using `get_db` dependency with auto-closing generators (`yield db; db.close()`). However, multi-step business transactions lack explicit rollback handling in case of secondary failures (e.g. creating project members after project creation).
  - **Evidence**: `backend/app/services/project_service.py` line 100-120 commits the project, then iterates over `member_ids` committing separately.
  - **Severity**: **MEDIUM**
  - **Business Impact**: If adding a member fails, an orphaned project without members or leads is left committed in the database.
  - **Recommended Fix**: Wrap multi-entity mutations in single atomic database transactions (`with db.begin():`).

---

## 4. Complete Data Flow Audit: UI vs Backend

| Feature | UI Control | API Endpoint | DB Persistence | Full Flow Verified? |
|:---|:---:|:---:|:---:|:---:|
| **User Invite** | `InviteUserDialog` | `POST /api/v1/users/invite` | `users` + `user_invitations` | **Yes** |
| **User Role Update** | `Change User Role` dialog | `PATCH /api/v1/users/:id/role` | `users.role` | **Yes** |
| **Company Setting** | `CompanySetupDialog` | `PUT /api/v1/users/:id` | `users.company` | **Yes** |
| **Project Creation** | `ProjectCreateDialog` | `POST /api/v1/projects/` | `projects` | **Yes** |
| **Task Creation** | `TaskCreateDialog` | `POST /api/v1/tasks/` | `tasks` | **Partial** (no membership check) |
| **Task Status Update** | `TaskDetailView` | `PATCH /api/v1/tasks/:id/status` | `tasks.status` | **Partial** (no assignee check) |
| **Client Data Isolation** | Not yet separated | `GET /api/v1/projects/` | Shared tables | **No** (Client role missing) |
| **Internal Comments** | Comment list | `GET /api/v1/tasks/:id/comments` | `task_comments` | **No** (No `is_internal` flag) |

---

## 5. Strategic Transformation Roadmap

1. **Phase 2 — Database Engineering**: Implement version-controlled Alembic migrations, enforce 4-role schema, add `client_visible` and `is_internal` columns, and add missing foreign key indexes.
2. **Phase 3 — Four-Role RBAC**: Implement centralized permission matrices for Admin, Project Manager, Employee, and Client across FastAPI and Flutter.
3. **Phase 4 — Authentication & Session**: Add automatic JWT refresh token interceptor, secure cookie strategy for web, and revoke expired tokens.
4. **Phase 5 & 6 — Full Stack Hardening**: Secure all task and comment endpoints, prevent IDOR, and eliminate silent mock fallback in production mode.
5. **Phase 7 to 11 — Testing & CI/CD**: End-to-end integration tests with PostgreSQL test database, GitHub Actions deployment verification, and performance profiling.
