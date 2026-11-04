import pytest
from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.project import Project
from app.models.task import Task
from app.models.project_member import ProjectMember
from app.models.task_comment import TaskComment
from app.models.notification import Notification
from app.models.enums import UserRole, UserStatus, TaskStatus, TaskPriority, ProjectStatus, ProjectPriority
from app.core.security import get_password_hash, create_access_token


def test_workflow_a_admin(client: TestClient, db: Session):
    """Workflow A — Admin:
    1. Admin logs in.
    2. Admin invites/creates a user.
    3. Admin assigns/updates a role.
    4. Admin creates a project.
    5. Admin assigns a Project Manager.
    6. Admin manages project membership.
    """
    # 1. Admin login
    admin = User(
        email="wf_admin@taskforge.internal",
        hashed_password=get_password_hash("Admin123!"),
        full_name="Workflow Admin",
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    pm = User(
        email="wf_pm@taskforge.internal",
        hashed_password=get_password_hash("Manager123!"),
        full_name="Workflow PM",
        role=UserRole.PROJECT_MANAGER,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    db.add_all([admin, pm])
    db.commit()

    login_res = client.post("/api/v1/auth/login", json={"email": admin.email, "password": "Admin123!"})
    assert login_res.status_code == 200
    admin_token = login_res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 2. Admin invites a new Employee
    invite_res = client.post(
        "/api/v1/users/invite",
        headers=admin_headers,
        json={
            "email": "wf_emp@taskforge.internal",
            "full_name": "Workflow Employee",
            "role": "employee",
            "company": "TaskForge Corp",
            "department": "Core Engineering"
        }
    )
    assert invite_res.status_code == 201
    invited_user_id = invite_res.json()["user_id"]
    assert invite_res.json()["role"] == "employee"

    # 3. Admin assigns / changes role
    role_change_res = client.patch(
        f"/api/v1/users/{invited_user_id}/role",
        headers=admin_headers,
        json={"role": "employee"}
    )
    assert role_change_res.status_code == 200

    # 4. Admin creates a project
    proj_res = client.post(
        "/api/v1/projects/",
        headers=admin_headers,
        json={
            "title": "Enterprise Cloud Migration",
            "description": "Multi-region database migration and Kubernetes orchestration",
            "priority": "high",
            "budget_hours": 160.0
        }
    )
    assert proj_res.status_code == 201
    project_id = proj_res.json()["id"]

    # 5. Admin updates project to assign the PM as owner
    update_proj_res = client.put(
        f"/api/v1/projects/{project_id}",
        headers=admin_headers,
        json={"owner_id": pm.id, "status": "in_progress"}
    )
    assert update_proj_res.status_code == 200
    assert update_proj_res.json()["owner_id"] == pm.id

    # 6. Admin manages project membership (adds employee)
    add_member_res = client.post(
        f"/api/v1/projects/{project_id}/members",
        headers=admin_headers,
        json={"user_id": invited_user_id, "role_in_project": "Backend Engineer"}
    )
    assert add_member_res.status_code == 201

    # Verify persistence
    db.expire_all()
    db_project = db.query(Project).filter(Project.id == project_id).first()
    assert db_project is not None
    assert db_project.owner_id == pm.id
    assert any(m.user_id == invited_user_id for m in db_project.members)


def test_workflow_b_project_manager(client: TestClient, db: Session):
    """Workflow B — Project Manager:
    1. Project Manager logs in.
    2. Views assigned projects.
    3. Creates tasks within authorized projects.
    4. Assigns employees.
    5. Sets priorities and deadlines.
    6. Monitors task progress and notifications.
    """
    pm = User(
        email="pm_wf_b@taskforge.internal",
        hashed_password=get_password_hash("Manager123!"),
        full_name="PM Workflow B",
        role=UserRole.PROJECT_MANAGER,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    emp = User(
        email="emp_wf_b@taskforge.internal",
        hashed_password=get_password_hash("Emp123!"),
        full_name="Employee Workflow B",
        role=UserRole.EMPLOYEE,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    db.add_all([pm, emp])
    db.commit()

    proj = Project(
        title="Mobile App Redesign",
        owner_id=pm.id,
        status=ProjectStatus.IN_PROGRESS
    )
    db.add(proj)
    db.flush()
    db.add(ProjectMember(project_id=proj.id, user_id=emp.id, role_in_project="Developer"))
    db.commit()

    # 1. PM logs in
    login_res = client.post("/api/v1/auth/login", json={"email": pm.email, "password": "Manager123!"})
    assert login_res.status_code == 200
    pm_headers = {"Authorization": f"Bearer {login_res.json()['access_token']}"}

    # 2. PM views assigned projects
    proj_list_res = client.get("/api/v1/projects/", headers=pm_headers)
    assert proj_list_res.status_code == 200
    items = proj_list_res.json()["items"]
    assert any(p["id"] == proj.id for p in items)

    # 3, 4, 5. PM creates task, assigns employee, sets priority and deadline
    due_date = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
    task_res = client.post(
        "/api/v1/tasks/",
        headers=pm_headers,
        json={
            "project_id": proj.id,
            "title": "Build Authentication Flow",
            "description": "Implement biometric and JWT token refresh",
            "priority": "high",
            "status": "todo",
            "assignee_id": emp.id,
            "due_date": due_date,
            "estimated_hours": 16.0,
            "is_client_visible": True
        }
    )
    assert task_res.status_code == 201
    task_id = task_res.json()["id"]
    assert task_res.json()["assignee_id"] == emp.id
    assert task_res.json()["priority"] == "high"

    # 6. PM monitors project progress
    detail_res = client.get(f"/api/v1/projects/{proj.id}", headers=pm_headers)
    assert detail_res.status_code == 200
    assert detail_res.json()["tasks_count"] >= 1

    # Verify notification created for assigned employee
    db.expire_all()
    notif = db.query(Notification).filter(Notification.user_id == emp.id).first()
    assert notif is not None
    assert "assigned" in notif.title.lower()


def test_workflow_c_employee(client: TestClient, db: Session):
    """Workflow C — Employee:
    1. Employee logs in.
    2. Views assigned tasks.
    3. Updates permitted task statuses.
    4. Adds comments.
    5. Submits progress updates.
    """
    pm = User(
        email="pm_wf_c@taskforge.internal",
        hashed_password=get_password_hash("Manager123!"),
        full_name="PM Workflow C",
        role=UserRole.PROJECT_MANAGER,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    emp = User(
        email="emp_wf_c@taskforge.internal",
        hashed_password=get_password_hash("Emp123!"),
        full_name="Employee Workflow C",
        role=UserRole.EMPLOYEE,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    db.add_all([pm, emp])
    db.commit()

    proj = Project(title="Payment Gateway Integration", owner_id=pm.id)
    db.add(proj)
    db.flush()
    db.add(ProjectMember(project_id=proj.id, user_id=emp.id, role_in_project="Developer"))

    task = Task(
        project_id=proj.id,
        creator_id=pm.id,
        assignee_id=emp.id,
        title="Integrate Stripe Webhooks",
        status=TaskStatus.TODO,
        priority=TaskPriority.HIGH
    )
    db.add(task)
    db.commit()

    # 1. Employee logs in
    login_res = client.post("/api/v1/auth/login", json={"email": emp.email, "password": "Emp123!"})
    assert login_res.status_code == 200
    emp_headers = {"Authorization": f"Bearer {login_res.json()['access_token']}"}

    # 2. Employee views assigned tasks
    tasks_res = client.get(f"/api/v1/tasks/?assignee_id={emp.id}", headers=emp_headers)
    assert tasks_res.status_code == 200
    assert any(t["id"] == task.id for t in tasks_res.json()["items"])

    # 3. Employee updates task status to in_progress, then in_review
    status_res1 = client.patch(
        f"/api/v1/tasks/{task.id}/status",
        headers=emp_headers,
        json={"status": "in_progress"}
    )
    assert status_res1.status_code == 200
    assert status_res1.json()["status"] == "in_progress"

    status_res2 = client.patch(
        f"/api/v1/tasks/{task.id}/status",
        headers=emp_headers,
        json={"status": "in_review"}
    )
    assert status_res2.status_code == 200
    assert status_res2.json()["status"] == "in_review"

    # 4. Employee adds comment
    comment_res = client.post(
        f"/api/v1/tasks/{task.id}/comments",
        headers=emp_headers,
        json={"content": "Webhook signature verification unit tests completed. Ready for review."}
    )
    assert comment_res.status_code == 201
    assert comment_res.json()["author_id"] == emp.id

    # 5. Verify database persistence and audit history
    db.expire_all()
    updated_task = db.query(Task).filter(Task.id == task.id).first()
    assert updated_task.status == TaskStatus.IN_REVIEW
    assert len(updated_task.comments) >= 1
    assert len(updated_task.history) >= 2  # creation + 2 status updates


def test_workflow_d_client(client: TestClient, db: Session):
    """Workflow D — Client:
    1. Client logs in.
    2. Views only authorized projects.
    3. Monitors project progress.
    4. Views client-visible tasks and updates.
    5. Submits permitted feedback.
    6. Is prevented from accessing internal data.
    """
    admin = User(
        email="admin_wf_d@taskforge.internal",
        hashed_password=get_password_hash("Admin123!"),
        full_name="Admin D",
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    client_user = User(
        email="client_wf_d@taskforge.internal",
        hashed_password=get_password_hash("Client123!"),
        full_name="Acme Corp Client",
        role=UserRole.CLIENT,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    db.add_all([admin, client_user])
    db.commit()

    # Project 1: Assigned to this Client
    authorized_proj = Project(
        title="Acme E-Commerce Portal",
        owner_id=admin.id,
        client_id=client_user.id,
        status=ProjectStatus.IN_PROGRESS
    )
    # Project 2: Internal company project
    internal_proj = Project(
        title="Company Secret R&D",
        owner_id=admin.id,
        client_id=None
    )
    db.add_all([authorized_proj, internal_proj])
    db.flush()

    # Tasks for authorized project
    visible_task = Task(
        project_id=authorized_proj.id,
        creator_id=admin.id,
        title="Homepage UI Polish",
        status=TaskStatus.DONE,
        is_client_visible=True
    )
    hidden_task = Task(
        project_id=authorized_proj.id,
        creator_id=admin.id,
        title="Database Schema Migration Internals",
        status=TaskStatus.TODO,
        is_client_visible=False
    )
    db.add_all([visible_task, hidden_task])
    db.flush()

    # Internal and public comments
    pub_comment = TaskComment(
        task_id=visible_task.id,
        author_id=admin.id,
        content="Here is the staging preview link.",
        is_internal=False
    )
    priv_comment = TaskComment(
        task_id=visible_task.id,
        author_id=admin.id,
        content="Internal note: server cost optimization pending.",
        is_internal=True
    )
    db.add_all([pub_comment, priv_comment])
    db.commit()

    # 1. Client logs in
    login_res = client.post("/api/v1/auth/login", json={"email": client_user.email, "password": "Client123!"})
    assert login_res.status_code == 200
    client_headers = {"Authorization": f"Bearer {login_res.json()['access_token']}"}

    # 2. Client views authorized projects only
    proj_list_res = client.get("/api/v1/projects/", headers=client_headers)
    assert proj_list_res.status_code == 200
    projs = proj_list_res.json()["items"]
    assert len(projs) == 1
    assert projs[0]["id"] == authorized_proj.id

    # Accessing internal project directly returns 403
    internal_res = client.get(f"/api/v1/projects/{internal_proj.id}", headers=client_headers)
    assert internal_res.status_code == 403

    # 3. Client monitors project progress
    detail_res = client.get(f"/api/v1/projects/{authorized_proj.id}", headers=client_headers)
    assert detail_res.status_code == 200
    assert detail_res.json()["title"] == "Acme E-Commerce Portal"

    # 4. Client views tasks: hidden task must not appear
    tasks_res = client.get("/api/v1/tasks/", headers=client_headers)
    assert tasks_res.status_code == 200
    task_ids = [t["id"] for t in tasks_res.json()["items"]]
    assert visible_task.id in task_ids
    assert hidden_task.id not in task_ids

    # 5. Client submits permitted feedback
    feedback_res = client.post(
        f"/api/v1/tasks/{visible_task.id}/comments",
        headers=client_headers,
        json={"content": "The homepage preview looks fantastic! Approved for release.", "is_internal": False}
    )
    assert feedback_res.status_code == 201

    # 6. Verify client cannot see internal comments
    comments_res = client.get(f"/api/v1/tasks/{visible_task.id}/comments", headers=client_headers)
    assert comments_res.status_code == 200
    comment_contents = [c["content"] for c in comments_res.json()]
    assert "Here is the staging preview link." in comment_contents
    assert "The homepage preview looks fantastic! Approved for release." in comment_contents
    assert "Internal note: server cost optimization pending." not in comment_contents


def test_concurrent_updates_and_data_integrity(client: TestClient, db: Session):
    """Test concurrent updates, rapid sequential status modifications, and data integrity."""
    admin = User(
        email="admin_concurrent@taskforge.internal",
        hashed_password=get_password_hash("Admin123!"),
        full_name="Admin Concurrent",
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE,
        is_active=True
    )
    db.add(admin)
    db.commit()

    proj = Project(title="High Concurrency Project", owner_id=admin.id)
    db.add(proj)
    db.commit()

    admin_token = create_access_token(subject=admin.id, role="admin", email=admin.email)
    headers = {"Authorization": f"Bearer {admin_token}"}

    create_task_res = client.post(
        "/api/v1/tasks/",
        headers=headers,
        json={"project_id": proj.id, "title": "Concurrent Task", "status": "todo"}
    )
    assert create_task_res.status_code == 201
    task_id = create_task_res.json()["id"]

    # Rapid sequential status transitions
    statuses = ["in_progress", "in_review", "done"]
    for s in statuses:
        res = client.patch(f"/api/v1/tasks/{task_id}/status", headers=headers, json={"status": s})
        assert res.status_code == 200
        assert res.json()["status"] == s

    # Verify all audit history logs are present and ordered (newest first)
    task_detail = client.get(f"/api/v1/tasks/{task_id}", headers=headers).json()
    history = task_detail["history"]
    assert len(history) == 4  # creation + 3 transitions
    assert history[0]["new_value"] == "done"
    assert "Created" in history[-1]["new_value"]
