def test_add_and_list_comments(client, pm_token, dev_token):
    pm_headers = {"Authorization": f"Bearer {pm_token}"}
    dev_headers = {"Authorization": f"Bearer {dev_token}"}

    # Project and Task setup
    proj = client.post("/api/v1/projects/", headers=pm_headers, json={"title": "Sprint 42", "status": "planning"}).json()
    task = client.post("/api/v1/tasks/", headers=pm_headers, json={"project_id": proj["id"], "title": "Setup CI/CD"}).json()

    # Developer posts comment
    comment_res = client.post(
        f"/api/v1/tasks/{task['id']}/comments",
        headers=dev_headers,
        json={"content": "GitHub Actions workflow YAML file has been written."}
    )
    assert comment_res.status_code == 201
    comment_id = comment_res.json()["id"]

    # List comments
    list_res = client.get(f"/api/v1/tasks/{task['id']}/comments", headers=dev_headers)
    assert list_res.status_code == 200
    comments = list_res.json()
    assert len(comments) == 1
    assert comments[0]["content"] == "GitHub Actions workflow YAML file has been written."

    # Delete comment
    del_res = client.delete(f"/api/v1/comments/{comment_id}", headers=dev_headers)
    assert del_res.status_code == 200
