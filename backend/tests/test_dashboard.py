def test_dashboard_metrics(client, pm_token):
    headers = {"Authorization": f"Bearer {pm_token}"}
    response = client.get("/api/v1/dashboard/metrics", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert "total_projects" in data
    assert "active_tasks" in data
    assert "completed_tasks" in data
    assert "overdue_tasks" in data
    assert "project_progress" in data
    assert "tasks_by_status" in data
    assert "tasks_by_priority" in data
