# API_AUDIT.md — REST API Layer, Validation & Endpoint Audit

**Date**: November 4, 2026  
**Framework**: FastAPI 0.115+ (Python 3.11)  
**Specification**: OpenAPI 3.1 / JSON Schema 2020-12  
**Auditor**: Senior Backend Architect & API Designer  

---

## 1. Executive Summary

The TaskForge API layer is organized under `/api/v1` with modular routers for `auth`, `users`, `projects`, `tasks`, `comments`, `notifications`, `dashboard`, and `health`. Request validation uses Pydantic v2 schemas, and centralized error handling returns uniform JSON payloads `{ "error_code", "message", "path" }`.

The primary engineering issues identified across the API are:
1. **Missing Resource Membership Validation on Task and Comment Routes** (IDOR vulnerabilities).
2. **Missing Rate Limiting** on sensitive endpoints (`/auth/login`, `/auth/refresh`, `/users/invite`).
3. **Missing Client Role Endpoints and Filtering**: No query parameter or service filter to isolate Client views.
4. **Lack of Idempotency on Critical Creation Operations**: Duplicate requests to create tasks or invite users can produce duplicate notifications or secondary constraint failures.

---

## 2. Endpoint-by-Endpoint Technical Evaluation

### 2.1 Authentication Router (`/api/v1/auth`)
- `POST /auth/register`:
  - Request: `UserRegister` (Email, Full Name, Password).
  - Issue: Always defaults role to `DEVELOPER`. Does not permit registering initial workspace owner without manual SQL mutation.
- `POST /auth/login`:
  - Request: OAuth2 password request form or JSON.
  - Security Check: Verifies bcrypt password, checks `user.is_active` and `user.status != UserStatus.DELETED`.
  - Issue: **No rate limiting or lockout protection**. Vulnerable to distributed brute-force password guessing.
  - Fix: Add slowapi rate limiter: `@limiter.limit("5/minute")`.
- `POST /auth/refresh`:
  - Issue: Re-issues access tokens, but does not rotate the refresh token itself.
  - Fix: Implement refresh token rotation with single-use revocation.
- `POST /auth/logout`:
  - Behavior: Stores JWT `jti` in `revoked_tokens` table. Verified functioning.

### 2.2 User Management Router (`/api/v1/users`)
- `GET /users/`:
  - Guard: Admin only (`require_roles([UserRole.ADMIN])`).
  - Search: Full-name, email, department, job title. Verified functioning.
- `POST /users/invite`:
  - Guard: Admin only.
  - Behavior: Creates user in `PENDING_INVITATION` status, generates 24-hr token.
- `PATCH /users/{id}/role`:
  - Safeguard: Prevents demoting the last active administrator. Verified working.
- `PATCH /users/{id}/status`:
  - Safeguard: Prevents deactivating the last active administrator. Verified working.

### 2.3 Projects Router (`/api/v1/projects`)
- `GET /projects/`:
  - Bug: Project Managers see **all** projects regardless of assignment.
  - Fix: If user is `PROJECT_MANAGER`, `EMPLOYEE`, or `CLIENT`, filter query to:
    `WHERE owner_id = :uid OR id IN (SELECT project_id FROM project_members WHERE user_id = :uid)`.
- `POST /projects/`:
  - Guard: Admin and Project Manager.
  - Issue: Transaction boundary is split when adding `member_ids`.
  - Fix: Atomic transaction block.
- `DELETE /projects/{id}`:
  - Guard: Admin or Project Owner only. Verified functioning.

### 2.4 Tasks Router (`/api/v1/tasks`)
- `GET /tasks/`:
  - Vulnerability: Unrestricted search across all company tasks.
  - Fix: Restrict to projects the current user belongs to (unless Admin). For Clients, also filter `is_client_visible == True`.
- `POST /tasks/`:
  - Vulnerability: No check that user is an Admin or Project Manager of `project_id`.
  - Fix: Verify user has `Manage Tasks` permission on the target project.
- `GET /tasks/{id}`:
  - Vulnerability: IDOR. Any user can view any task.
  - Fix: Check project membership before returning task details.
- `PUT /tasks/{id}`:
  - Vulnerability: Any user can modify task details, hours, assignees.
  - Fix: Restrict editing to Admins, Project Managers assigned to the project, or the task creator.
- `PATCH /tasks/{id}/status`:
  - Vulnerability: Any user can alter task status.
  - Fix: Allow only Admins, Project Managers, and the assigned Employee to transition statuses.

### 2.5 Comments Router (`/api/v1/comments` & `/tasks/{id}/comments`)
- `GET /tasks/{task_id}/comments`:
  - Vulnerability: Clients can read internal developer notes.
  - Fix: Check task project membership. If `current_user.role == UserRole.CLIENT`, filter `WHERE is_internal = FALSE`.
- `POST /tasks/{task_id}/comments`:
  - Missing field: `is_internal: bool = False` in `CommentCreate`.
  - Fix: Allow Employees, PMs, and Admins to flag comments as internal. Clients can only post public comments.

---

## 3. Recommended API Standard Response Structure

To ensure frontend reliability across network failures, all responses adhere to:

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation completed successfully.",
  "meta": {
    "page": 1,
    "page_size": 20,
    "total": 45,
    "total_pages": 3
  }
}
```

Error responses:
```json
{
  "success": false,
  "error_code": "PERMISSION_DENIED",
  "message": "You are not assigned to this project.",
  "path": "/api/v1/tasks/14"
}
```
