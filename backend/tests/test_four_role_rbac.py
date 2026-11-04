import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.project import Project
from app.models.task import Task
from app.models.project_member import ProjectMember
from app.models.task_comment import TaskComment
from app.models.enums import UserRole, TaskStatus, TaskPriority, ProjectStatus
from app.core.security import get_password_hash, create_access_token


def test_admin_full_access(
    client: TestClient,
    admin_token_headers: dict,
    db: Session
):
    # Admin can create a project
    res = client.post(
        "/api/v1/projects/",
        headers=admin_token_headers,
        json={"title": "Admin Project", "description": "Admin created"}
    )
    assert res.status_code == 201
    project_id = res.json()["id"]

    # Admin can list all projects
    res_list = client.get("/api/v1/projects/", headers=admin_token_headers)
    assert res_list.status_code == 200
    assert any(p["id"] == project_id for p in res_list.json()["items"])


def test_pm_cross_project_isolation(
    client: TestClient,
    pm_token_headers: dict,
    admin_user: User,
    db: Session
):
    # Admin creates an isolated project where PM is NOT owner and NOT member
    isolated_proj = Project(
        title="Admin Confidential Project",
        description="Top secret",
        owner_id=admin_user.id
    )
    db.add(isolated_proj)
    db.commit()
    db.refresh(isolated_proj)

    # PM attempts to access the isolated project -> 403 Forbidden
    res = client.get(f"/api/v1/projects/{isolated_proj.id}", headers=pm_token_headers)
    assert res.status_code == 403
    error_msg = res.json().get("message") or res.json().get("detail", "")
    assert "not authorized" in error_msg.lower()

    # PM attempts to edit the isolated project -> 403 Forbidden
    res_edit = client.put(
        f"/api/v1/projects/{isolated_proj.id}",
        headers=pm_token_headers,
        json={"title": "Tampered Title"}
    )
    assert res_edit.status_code == 403


def test_employee_permissions_and_status_update(
    client: TestClient,
    employee_token_headers: dict,
    employee_user: User,
    admin_user: User,
    db: Session
):
    # Employee attempts to create a project -> 403 Forbidden
    res_proj = client.post(
        "/api/v1/projects/",
        headers=employee_token_headers,
        json={"title": "Employee Rogue Project"}
    )
    assert res_proj.status_code == 403

    # Create project and add employee as member
    proj = Project(title="Team Project", owner_id=admin_user.id)
    db.add(proj)
    db.flush()

    member = ProjectMember(project_id=proj.id, user_id=employee_user.id, role_in_project="Developer")
    db.add(member)

    # Create task assigned to employee
    task = Task(
        title="Implement Feature",
        project_id=proj.id,
        creator_id=admin_user.id,
        assignee_id=employee_user.id,
        status=TaskStatus.TODO
    )
    db.add(task)
    db.commit()

    # Employee can view project
    res_view = client.get(f"/api/v1/projects/{proj.id}", headers=employee_token_headers)
    assert res_view.status_code == 200

    # Employee CANNOT edit task core attributes (like title) -> 403
    res_edit = client.put(
        f"/api/v1/tasks/{task.id}",
        headers=employee_token_headers,
        json={"title": "Hacked Title"}
    )
    assert res_edit.status_code == 403

    # Employee CAN update task status of their assigned task -> 200
    res_status = client.patch(
        f"/api/v1/tasks/{task.id}/status",
        headers=employee_token_headers,
        json={"status": TaskStatus.IN_PROGRESS.value}
    )
    assert res_status.status_code == 200
    assert res_status.json()["status"] == TaskStatus.IN_PROGRESS.value


def test_client_project_isolation(
    client: TestClient,
    client_token_headers: dict,
    client_user: User,
    admin_user: User,
    db: Session
):
    # Project 1: Assigned to Client
    client_proj = Project(
        title="Client Website",
        owner_id=admin_user.id,
        client_id=client_user.id
    )
    # Project 2: Unrelated internal project
    internal_proj = Project(
        title="Internal Infrastructure",
        owner_id=admin_user.id,
        client_id=None
    )
    db.add_all([client_proj, internal_proj])
    db.commit()
    db.refresh(client_proj)
    db.refresh(internal_proj)

    # Client can access their assigned project
    res1 = client.get(f"/api/v1/projects/{client_proj.id}", headers=client_token_headers)
    assert res1.status_code == 200
    assert res1.json()["id"] == client_proj.id

    # Client is blocked from viewing internal project -> 403
    res2 = client.get(f"/api/v1/projects/{internal_proj.id}", headers=client_token_headers)
    assert res2.status_code == 403

    # Client cannot list organization users -> 403
    res_users = client.get("/api/v1/users/", headers=client_token_headers)
    assert res_users.status_code == 403


def test_client_task_and_comment_visibility(
    client: TestClient,
    client_token_headers: dict,
    client_user: User,
    admin_user: User,
    db: Session
):
    # Setup client project
    proj = Project(
        title="Client Mobile App",
        owner_id=admin_user.id,
        client_id=client_user.id
    )
    db.add(proj)
    db.flush()

    # Task 1: Client visible
    public_task = Task(
        title="UI Design Mockups",
        project_id=proj.id,
        creator_id=admin_user.id,
        is_client_visible=True
    )
    # Task 2: Internal only task
    internal_task = Task(
        title="Refactor Legacy Auth Tables",
        project_id=proj.id,
        creator_id=admin_user.id,
        is_client_visible=False
    )
    db.add_all([public_task, internal_task])
    db.flush()

    # Comments on public task: 1 public, 1 internal
    pub_comment = TaskComment(
        task_id=public_task.id,
        author_id=admin_user.id,
        content="Here are the initial wireframes.",
        is_internal=False
    )
    priv_comment = TaskComment(
        task_id=public_task.id,
        author_id=admin_user.id,
        content="Internal note: budget might be tight.",
        is_internal=True
    )
    db.add_all([pub_comment, priv_comment])
    db.commit()

    # 1. Client task list must only include public task
    res_tasks = client.get("/api/v1/tasks/", headers=client_token_headers)
    assert res_tasks.status_code == 200
    task_ids = [t["id"] for t in res_tasks.json()["items"]]
    assert public_task.id in task_ids
    assert internal_task.id not in task_ids

    # 2. Client direct IDOR attempt on internal task -> 403
    res_internal = client.get(f"/api/v1/tasks/{internal_task.id}", headers=client_token_headers)
    assert res_internal.status_code == 403

    # 3. Client views public task detail: internal comments must be filtered out
    res_detail = client.get(f"/api/v1/tasks/{public_task.id}", headers=client_token_headers)
    assert res_detail.status_code == 200
    returned_comments = res_detail.json()["comments"]
    assert len(returned_comments) == 1
    assert returned_comments[0]["content"] == "Here are the initial wireframes."

    # 4. Client calls comments endpoint: internal comments must be hidden
    res_comments = client.get(f"/api/v1/tasks/{public_task.id}/comments", headers=client_token_headers)
    assert res_comments.status_code == 200
    assert len(res_comments.json()) == 1
    assert res_comments.json()[0]["is_internal"] is False

    # 5. Client attempts to post internal comment -> 403 Forbidden
    res_post_priv = client.post(
        f"/api/v1/tasks/{public_task.id}/comments",
        headers=client_token_headers,
        json={"content": "Sneaky internal comment", "is_internal": True}
    )
    assert res_post_priv.status_code == 403

    # 6. Client posts public feedback -> 201 Created
    res_post_pub = client.post(
        f"/api/v1/tasks/{public_task.id}/comments",
        headers=client_token_headers,
        json={"content": "Wireframes look great!", "is_internal": False}
    )
    assert res_post_pub.status_code == 201
    assert res_post_pub.json()["is_internal"] is False
