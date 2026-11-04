# SECURITY_AUDIT.md — Vulnerability & Access Control Assessment

**Date**: November 4, 2026  
**Auditor**: Senior Application Security Engineer & Penetration Tester  
**Classification**: High Priority Remediation Plan  
**Standard References**: OWASP Top 10 (2021), ASVS Level 2, NIST SP 800-63B  

---

## 1. Executive Summary

A comprehensive application security review was conducted across the FastAPI backend endpoints, JWT token handling, database queries, and Flutter Web frontend client. 

The audit identified **4 High/Critical security vulnerabilities** and **3 Medium vulnerabilities**, dominated by **Insecure Direct Object References (IDOR)** in task management, **unrestricted cross-project visibility for Project Managers**, **absence of Client data isolation**, and **improper CORS wildcard configuration**.

---

## 2. Vulnerability Catalog & Threat Analysis

### SEC-01: Insecure Direct Object References (IDOR) on Task Operations
- **OWASP Category**: A01:2021 — Broken Access Control
- **Severity**: **CRITICAL** (CVSS 8.5)
- **Vulnerable Endpoints**:
  - `GET /api/v1/tasks/{task_id}`
  - `PUT /api/v1/tasks/{task_id}`
  - `PATCH /api/v1/tasks/{task_id}/status`
  - `DELETE /api/v1/tasks/{task_id}`
- **Evidence**:
  In `backend/app/services/task_service.py` line 78-89:
  ```python
  def get_task_by_id(self, db: Session, *, task_id: int, current_user: User) -> TaskDetailResponse:
      task = task_repo.get(db, id=task_id)
      if not task:
          raise EntityNotFoundException("Task", task_id)
      # NO MEMBERSHIP CHECK PERFORMED!
      return TaskDetailResponse(...)
  ```
  In `backend/app/services/task_service.py` line 124-157:
  `update_task()` accepts any `task_id` and executes updates without validating if `current_user` belongs to `task.project_id`.
- **Business Impact**: Any logged-in Employee or external Client can modify, delete, or inspect sensitive tasks and milestones belonging to completely different projects or competing clients.
- **Remediation**:
  Enforce project membership validation on every task operation:
  ```python
  def _verify_task_access(self, db: Session, task: Task, current_user: User, write: bool = False):
      if current_user.role == UserRole.ADMIN:
          return
      is_member = db.query(ProjectMember).filter(
          ProjectMember.project_id == task.project_id,
          ProjectMember.user_id == current_user.id
      ).first()
      if not is_member and task.project.owner_id != current_user.id:
          raise PermissionDeniedException("Access denied to this project's tasks.")
      if write and current_user.role == UserRole.CLIENT:
          raise PermissionDeniedException("Clients cannot modify internal tasks.")
  ```

---

### SEC-02: Unbounded Cross-Project Access for Project Managers
- **OWASP Category**: A01:2021 — Broken Access Control
- **Severity**: **HIGH** (CVSS 7.4)
- **Vulnerable Code**:
  `backend/app/services/project_service.py` lines 25-27:
  ```python
  user_filter_id = None if current_user.role in [UserRole.ADMIN, UserRole.PROJECT_MANAGER] else current_user.id
  ```
  and line 69-73:
  ```python
  if current_user.role not in [UserRole.ADMIN, UserRole.PROJECT_MANAGER]:
      is_member = any(m.user_id == current_user.id for m in project.members)
      if project.owner_id != current_user.id and not is_member:
          raise PermissionDeniedException("You are not authorized to view this project.")
  ```
- **Business Impact**: A Project Manager hired to lead Project A can freely view, modify, and delete Project B, C, and D, violating the enterprise principle of least privilege and client confidentiality.
- **Remediation**:
  Only Admins have global cross-project visibility. Project Managers must be restricted to projects where they are either the `owner_id` or listed in `project_members`.

---

### SEC-03: Lack of Client Role & Client Data Isolation
- **OWASP Category**: A01:2021 — Broken Access Control / Information Disclosure
- **Severity**: **CRITICAL** (CVSS 8.8)
- **Vulnerable Points**:
  - `UserRole` enum does not have a `CLIENT` role.
  - `TaskComment` table lacks an `is_internal` visibility filter.
  - `Task` table lacks an `is_client_visible` flag.
- **Business Impact**: External clients invited into the system would have visibility into internal developer discussions, sensitive wage/budget allocations, bug disclosures, and unvetted technical discussions.
- **Remediation**:
  1. Add `CLIENT` to `UserRole` enum.
  2. Add `is_internal: bool = False` to `TaskComment`.
  3. Filter out all `is_internal=True` comments whenever `current_user.role == UserRole.CLIENT`.
  4. Restrict Clients to read-only access for authorized projects and tasks.

---

### SEC-04: Permissive CORS Configuration with Credential Exposure
- **OWASP Category**: A05:2021 — Security Misconfiguration
- **Severity**: **HIGH** (CVSS 7.1)
- **Vulnerable Code**:
  `backend/app/core/config.py` line 45:
  `BACKEND_CORS_ORIGINS: List[str] = [ ... "*"]` combined with `CORSMiddleware(allow_credentials=True)` in `main.py` line 256.
- **Business Impact**: Modern browsers reject `*` when credentials are included, but misconfigured proxies or mobile webviews can permit malicious origins to trigger cross-origin authenticated requests.
- **Remediation**:
  Remove `"*"` from `BACKEND_CORS_ORIGINS`. Explicitly whitelist the exact domains:
  - `https://taskforge-pm-app.web.app`
  - `https://taskforge-pm-app.firebaseapp.com`
  - `http://localhost:8000`, `http://localhost:3000` (development only).

---

### SEC-05: Web Token Storage in LocalStorage
- **OWASP Category**: A02:2021 — Cryptographic Failures / Storage
- **Severity**: **MEDIUM** (CVSS 5.3)
- **Vulnerable Code**:
  `frontend/lib/services/storage_service.dart` line 18:
  ```dart
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
  }
  ```
- **Business Impact**: JavaScript executing in the web page has full access to `window.localStorage`. If any third-party script or dependency contains an XSS vulnerability, the authentication token can be exfiltrated.
- **Remediation**:
  Enforce strict Content Security Policy (CSP) headers in `firebase.json` to prevent malicious inline scripts, and configure JWT tokens with short expiration times (e.g., 15-30 minutes) backed by token rotation.

---

## 3. Four-Role Authorization Matrix (Enforced at Backend API)

| Permission / Action | Admin | Project Manager | Employee | Client |
|:---|:---:|:---:|:---:|:---:|
| **Manage Users & Invite** | ✅ Full | ❌ Denied | ❌ Denied | ❌ Denied |
| **Change User Roles / Status** | ✅ Full | ❌ Denied | ❌ Denied | ❌ Denied |
| **View All Projects (Global)** | ✅ Full | ❌ Assigned Only | ❌ Assigned Only | ❌ Authorized Only |
| **Create Project** | ✅ Yes | ✅ Yes | ❌ Denied | ❌ Denied |
| **Update Project Details** | ✅ Yes | ✅ If Assigned Lead | ❌ Denied | ❌ Denied |
| **Delete Project** | ✅ Yes | ❌ Denied | ❌ Denied | ❌ Denied |
| **Create Tasks** | ✅ Yes | ✅ If Project Lead | ❌ Denied | ❌ Denied |
| **Update Task Details & Assign** | ✅ Yes | ✅ If Project Lead | ❌ Denied | ❌ Denied |
| **Update Task Status** | ✅ Yes | ✅ Yes | ✅ If Assignee / Member | ❌ Denied |
| **View Internal Comments** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ Blocked |
| **Add Client Comments** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Permitted Tasks Only |
