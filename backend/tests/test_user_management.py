import pytest
from app.models.enums import UserRole, UserStatus
from app.models.user import User


def test_admin_can_invite_user(client, admin_token_headers):
    payload = {
        "email": "newbie@taskforge.internal",
        "full_name": "New Team Member",
        "role": "developer",
        "department": "Engineering",
        "job_title": "Backend Intern"
    }
    response = client.post("/api/v1/users/invite", json=payload, headers=admin_token_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "newbie@taskforge.internal"
    assert data["role"] == "developer"
    assert data["status"] == "pending_invitation"
    assert "invitation_token" in data
    assert data["invitation_token"] is not None


def test_non_admin_cannot_invite_user(client, dev_token_headers):
    payload = {
        "email": "intruder@taskforge.internal",
        "full_name": "Intruder User",
        "role": "developer"
    }
    response = client.post("/api/v1/users/invite", json=payload, headers=dev_token_headers)
    assert response.status_code == 403


def test_duplicate_email_invitation_rejected(client, admin_token_headers):
    payload = {
        "email": "duplicate_check@taskforge.internal",
        "full_name": "Duplicate User One",
        "role": "developer"
    }
    res1 = client.post("/api/v1/users/invite", json=payload, headers=admin_token_headers)
    assert res1.status_code == 201

    res2 = client.post("/api/v1/users/invite", json=payload, headers=admin_token_headers)
    assert res2.status_code == 409


def test_user_can_accept_invitation_and_set_password(client, admin_token_headers):
    invite_payload = {
        "email": "invited_user@taskforge.internal",
        "full_name": "Invited User",
        "role": "developer"
    }
    invite_res = client.post("/api/v1/users/invite", json=invite_payload, headers=admin_token_headers)
    token = invite_res.json()["invitation_token"]

    # Public accept invitation
    accept_res = client.post(
        "/api/v1/users/accept-invitation",
        json={"token": token, "password": "SecurePassword123!"}
    )
    assert accept_res.status_code == 200
    user_data = accept_res.json()
    assert user_data["status"] == "active"
    assert user_data["is_active"] is True

    # User can now login with the new password
    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": "invited_user@taskforge.internal", "password": "SecurePassword123!"}
    )
    assert login_res.status_code == 200
    assert "access_token" in login_res.json()


def test_invitation_token_is_single_use(client, admin_token_headers):
    invite_res = client.post(
        "/api/v1/users/invite",
        json={"email": "single_use@taskforge.internal", "full_name": "Single Use"},
        headers=admin_token_headers
    )
    token = invite_res.json()["invitation_token"]

    # First accept
    res1 = client.post(
        "/api/v1/users/accept-invitation",
        json={"token": token, "password": "Password1!"}
    )
    assert res1.status_code == 200

    # Second accept must fail
    res2 = client.post(
        "/api/v1/users/accept-invitation",
        json={"token": token, "password": "Password2!"}
    )
    assert res2.status_code == 400


def test_admin_resend_invitation(client, admin_token_headers):
    invite_res = client.post(
        "/api/v1/users/invite",
        json={"email": "resend_test@taskforge.internal", "full_name": "Resend Test"},
        headers=admin_token_headers
    )
    user_id = invite_res.json()["user_id"]
    old_token = invite_res.json()["invitation_token"]

    # Resend invitation
    resend_res = client.post(f"/api/v1/users/{user_id}/resend-invitation", headers=admin_token_headers)
    assert resend_res.status_code == 200
    new_token = resend_res.json()["invitation_token"]
    assert new_token != old_token

    # Old token must now be rejected
    old_attempt = client.post(
        "/api/v1/users/accept-invitation",
        json={"token": old_token, "password": "Password123!"}
    )
    assert old_attempt.status_code == 400

    # New token succeeds
    new_attempt = client.post(
        "/api/v1/users/accept-invitation",
        json={"token": new_token, "password": "Password123!"}
    )
    assert new_attempt.status_code == 200


def test_admin_cannot_demote_themselves(client, admin_token_headers, admin_user):
    res = client.patch(
        f"/api/v1/users/{admin_user.id}/role",
        json={"role": "developer"},
        headers=admin_token_headers
    )
    assert res.status_code == 400


def test_last_admin_cannot_be_demoted_or_deactivated(client, admin_token_headers, admin_user):
    # Try deactivate
    res = client.patch(
        f"/api/v1/users/{admin_user.id}/status",
        json={"status": "inactive"},
        headers=admin_token_headers
    )
    assert res.status_code == 400


def test_admin_can_change_user_status_and_deactivated_cannot_login(client, admin_token_headers):
    # Invite and activate a user
    inv = client.post(
        "/api/v1/users/invite",
        json={"email": "status_check@taskforge.internal", "full_name": "Status User"},
        headers=admin_token_headers
    ).json()
    client.post(
        "/api/v1/users/accept-invitation",
        json={"token": inv["invitation_token"], "password": "Password123!"}
    )

    # Deactivate account
    deactivate_res = client.patch(
        f"/api/v1/users/{inv['user_id']}/status",
        json={"status": "inactive"},
        headers=admin_token_headers
    )
    assert deactivate_res.status_code == 200
    assert deactivate_res.json()["status"] == "inactive"
    assert deactivate_res.json()["is_active"] is False

    # Deactivated user cannot authenticate
    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": "status_check@taskforge.internal", "password": "Password123!"}
    )
    assert login_res.status_code == 401

    # Reactivate account
    activate_res = client.patch(
        f"/api/v1/users/{inv['user_id']}/status",
        json={"status": "active"},
        headers=admin_token_headers
    )
    assert activate_res.status_code == 200
    assert activate_res.json()["status"] == "active"

    # Now login succeeds
    relogin_res = client.post(
        "/api/v1/auth/login",
        json={"email": "status_check@taskforge.internal", "password": "Password123!"}
    )
    assert relogin_res.status_code == 200


def test_admin_soft_delete_and_restore_user(client, admin_token_headers):
    inv = client.post(
        "/api/v1/users/invite",
        json={"email": "delete_check@taskforge.internal", "full_name": "Delete User"},
        headers=admin_token_headers
    ).json()
    user_id = inv["user_id"]

    # Soft delete
    del_res = client.delete(f"/api/v1/users/{user_id}", headers=admin_token_headers)
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "deleted"
    assert del_res.json()["deleted_at"] is not None

    # Normal list excludes deleted
    list_res = client.get("/api/v1/users/", headers=admin_token_headers)
    ids = [u["id"] for u in list_res.json()["items"]]
    assert user_id not in ids

    # Admin list with include_deleted=true includes deleted
    admin_list_res = client.get("/api/v1/users/?include_deleted=true", headers=admin_token_headers)
    admin_ids = [u["id"] for u in admin_list_res.json()["items"]]
    assert user_id in admin_ids

    # Restore account
    restore_res = client.post(f"/api/v1/users/{user_id}/restore", headers=admin_token_headers)
    assert restore_res.status_code == 200
    assert restore_res.json()["status"] == "inactive"
    assert restore_res.json()["deleted_at"] is None


def test_password_reset_flow(client, admin_token_headers):
    inv = client.post(
        "/api/v1/users/invite",
        json={"email": "reset_flow@taskforge.internal", "full_name": "Reset User"},
        headers=admin_token_headers
    ).json()
    user_id = inv["user_id"]
    client.post(
        "/api/v1/users/accept-invitation",
        json={"token": inv["invitation_token"], "password": "InitialPass1!"}
    )

    # Initiate password reset
    init_res = client.post(f"/api/v1/users/{user_id}/reset-password", headers=admin_token_headers)
    assert init_res.status_code == 200
    reset_token = init_res.json()["reset_token"]
    assert reset_token is not None

    # Confirm password reset
    confirm_res = client.post(
        "/api/v1/users/confirm-password-reset",
        json={"token": reset_token, "new_password": "NewSecretPass1!"}
    )
    assert confirm_res.status_code == 200

    # Login with old pass fails
    bad_login = client.post(
        "/api/v1/auth/login",
        json={"email": "reset_flow@taskforge.internal", "password": "InitialPass1!"}
    )
    assert bad_login.status_code == 401

    # Login with new pass succeeds
    good_login = client.post(
        "/api/v1/auth/login",
        json={"email": "reset_flow@taskforge.internal", "password": "NewSecretPass1!"}
    )
    assert good_login.status_code == 200


def test_project_assignment_workflow(client, admin_token_headers):
    # Create project
    proj = client.post(
        "/api/v1/projects/",
        json={"title": "Assignment Test Project", "status": "planning"},
        headers=admin_token_headers
    ).json()

    # Invite user
    user = client.post(
        "/api/v1/users/invite",
        json={"email": "project_assignee@taskforge.internal", "full_name": "Project Assignee"},
        headers=admin_token_headers
    ).json()

    # Assign user to project
    assign_res = client.post(
        f"/api/v1/users/{user['user_id']}/projects",
        json={"project_id": proj["id"], "role_in_project": "Lead Developer"},
        headers=admin_token_headers
    )
    assert assign_res.status_code == 201
    assert assign_res.json()["project_id"] == proj["id"]
    assert assign_res.json()["role_in_project"] == "Lead Developer"

    # Duplicate assignment rejected
    dup_res = client.post(
        f"/api/v1/users/{user['user_id']}/projects",
        json={"project_id": proj["id"]},
        headers=admin_token_headers
    )
    assert dup_res.status_code == 400

    # User project list shows assigned project
    proj_list = client.get(f"/api/v1/users/{user['user_id']}/projects", headers=admin_token_headers).json()
    assert len(proj_list) == 1
    assert proj_list[0]["project_id"] == proj["id"]

    # Remove user from project
    del_assign = client.delete(
        f"/api/v1/users/{user['user_id']}/projects/{proj['id']}",
        headers=admin_token_headers
    )
    assert del_assign.status_code == 204


def test_user_summary_metrics(client, admin_token_headers):
    metrics_res = client.get("/api/v1/users/metrics", headers=admin_token_headers)
    assert metrics_res.status_code == 200
    data = metrics_res.json()
    assert "total_users" in data
    assert "active_users" in data
    assert "admins_count" in data
    assert "project_managers_count" in data
    assert "developers_count" in data
    assert data["admins_count"] >= 1


def test_user_activity_audit_logs(client, admin_token_headers):
    # Invite user to trigger audit log
    inv = client.post(
        "/api/v1/users/invite",
        json={"email": "audit_check@taskforge.internal", "full_name": "Audit Check"},
        headers=admin_token_headers
    ).json()

    activity_res = client.get(f"/api/v1/users/{inv['user_id']}/activity", headers=admin_token_headers)
    assert activity_res.status_code == 200
    logs = activity_res.json()
    assert len(logs) >= 1
    assert logs[0]["action"] == "user_invited"
    assert "password" not in str(logs[0]["details"]).lower()
