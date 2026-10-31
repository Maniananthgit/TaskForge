def test_developer_cannot_create_project(client, dev_token):
    headers = {"Authorization": f"Bearer {dev_token}"}
    response = client.post(
        "/api/v1/projects/",
        headers=headers,
        json={
            "title": "Unauthorized Dev Project",
            "description": "Should fail with 403",
            "status": "planning",
            "priority": "low"
        }
    )
    assert response.status_code == 403


def test_pm_can_create_project(client, pm_token):
    headers = {"Authorization": f"Bearer {pm_token}"}
    response = client.post(
        "/api/v1/projects/",
        headers=headers,
        json={
            "title": "PM Approved Project",
            "description": "Created by Project Manager",
            "status": "planning",
            "priority": "high",
            "budget_hours": 120.0
        }
    )
    assert response.status_code == 201
    assert response.json()["title"] == "PM Approved Project"


def test_admin_can_update_user_roles(client, admin_token, dev_user):
    headers = {"Authorization": f"Bearer {admin_token}"}
    response = client.put(
        f"/api/v1/users/{dev_user.id}",
        headers=headers,
        json={"role": "project_manager"}
    )
    assert response.status_code == 200
    assert response.json()["role"] == "project_manager"


def test_non_admin_cannot_update_user_roles(client, dev_token, pm_user):
    headers = {"Authorization": f"Bearer {dev_token}"}
    response = client.put(
        f"/api/v1/users/{pm_user.id}",
        headers=headers,
        json={"role": "admin"}
    )
    assert response.status_code == 403
