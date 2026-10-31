def test_create_and_get_project(client, pm_token, dev_user):
    headers = {"Authorization": f"Bearer {pm_token}"}
    create_res = client.post(
        "/api/v1/projects/",
        headers=headers,
        json={
            "title": "Cloud Migration",
            "description": "Migrate on-prem services to AWS ECS",
            "status": "in_progress",
            "priority": "urgent",
            "budget_hours": 200.0,
            "member_ids": [dev_user.id]
        }
    )
    assert create_res.status_code == 201
    project_id = create_res.json()["id"]

    # Get project detail
    detail_res = client.get(f"/api/v1/projects/{project_id}", headers=headers)
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["title"] == "Cloud Migration"
    assert len(detail["members"]) >= 1


def test_list_projects_pagination(client, pm_token):
    headers = {"Authorization": f"Bearer {pm_token}"}
    # Create 3 projects
    for i in range(3):
        client.post(
            "/api/v1/projects/",
            headers=headers,
            json={
                "title": f"Project Batch {i}",
                "description": f"Batch item {i}",
                "status": "planning",
                "priority": "medium"
            }
        )

    response = client.get("/api/v1/projects/?page=1&page_size=2", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["items"]) == 2
    assert data["total"] >= 3
    assert data["total_pages"] >= 2


def test_add_and_remove_project_member(client, pm_token, dev_user):
    headers = {"Authorization": f"Bearer {pm_token}"}
    create_res = client.post(
        "/api/v1/projects/",
        headers=headers,
        json={"title": "Team Expansion", "status": "planning"}
    )
    project_id = create_res.json()["id"]

    # Add member
    add_res = client.post(
        f"/api/v1/projects/{project_id}/members",
        headers=headers,
        json={"user_id": dev_user.id, "role_in_project": "Lead Developer"}
    )
    assert add_res.status_code == 201

    # Remove member
    del_res = client.delete(
        f"/api/v1/projects/{project_id}/members/{dev_user.id}",
        headers=headers
    )
    assert del_res.status_code == 200
