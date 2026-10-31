from datetime import datetime, timedelta, timezone


def test_create_task_and_update_status(client, pm_token, dev_user):
    headers = {"Authorization": f"Bearer {pm_token}"}
    proj_res = client.post(
        "/api/v1/projects/",
        headers=headers,
        json={"title": "App Redesign", "status": "in_progress"}
    )
    project_id = proj_res.json()["id"]

    # Create task
    task_res = client.post(
        "/api/v1/tasks/",
        headers=headers,
        json={
            "project_id": project_id,
            "title": "Design responsive navigation rail",
            "description": "Adaptive drawer and rail layout for Flutter",
            "status": "todo",
            "priority": "high",
            "assignee_id": dev_user.id,
            "estimated_hours": 8.0
        }
    )
    assert task_res.status_code == 201
    task_id = task_res.json()["id"]

    # Update status to in_progress
    status_res = client.patch(
        f"/api/v1/tasks/{task_id}/status",
        headers=headers,
        json={"status": "in_progress"}
    )
    assert status_res.status_code == 200
    assert status_res.json()["status"] == "in_progress"

    # Verify audit history
    detail_res = client.get(f"/api/v1/tasks/{task_id}", headers=headers)
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert len(detail["history"]) >= 2  # creation + status change
    assert any(h["field_changed"] == "status" for h in detail["history"])


def test_task_overdue_flag(client, pm_token):
    headers = {"Authorization": f"Bearer {pm_token}"}
    proj_res = client.post(
        "/api/v1/projects/",
        headers=headers,
        json={"title": "Audit Sprint", "status": "in_progress"}
    )
    project_id = proj_res.json()["id"]

    # Past due date
    past_due = (datetime.now(timezone.utc) - timedelta(days=2)).isoformat()
    task_res = client.post(
        "/api/v1/tasks/",
        headers=headers,
        json={
            "project_id": project_id,
            "title": "Fix security vulnerability",
            "status": "in_progress",
            "priority": "urgent",
            "due_date": past_due
        }
    )
    assert task_res.status_code == 201
    assert task_res.json()["is_overdue"] is True
