def test_register_user(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "newuser@taskforge.internal",
            "password": "Password123!",
            "full_name": "New User",
            "role": "developer"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "newuser@taskforge.internal"
    assert data["role"] == "developer"
    assert "hashed_password" not in data


def test_register_duplicate_email(client, dev_user):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": dev_user.email,
            "password": "Password123!",
            "full_name": "Duplicate Tester",
            "role": "developer"
        }
    )
    assert response.status_code == 409


def test_login_success(client, dev_user):
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": dev_user.email,
            "password": "Dev123!"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == dev_user.email


def test_login_invalid_password(client, dev_user):
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": dev_user.email,
            "password": "WrongPassword!"
        }
    )
    assert response.status_code == 401


def test_get_current_user_profile(client, dev_token, dev_user):
    headers = {"Authorization": f"Bearer {dev_token}"}
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == dev_user.id
    assert data["email"] == dev_user.email


def test_logout_token_invalidation(client, dev_token):
    headers = {"Authorization": f"Bearer {dev_token}"}
    # Logout
    logout_res = client.post("/api/v1/auth/logout", headers=headers)
    assert logout_res.status_code == 200

    # Attempting to access profile with revoked token should fail with 401
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 401


def test_refresh_token_lifecycle(client, dev_user):
    # 1. Login to get token pair
    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": dev_user.email, "password": "Dev123!"}
    )
    assert login_res.status_code == 200
    data = login_res.json()
    old_refresh = data["refresh_token"]

    # 2. Use refresh token to get a fresh pair
    refresh_res = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh}
    )
    assert refresh_res.status_code == 200
    refreshed_data = refresh_res.json()
    new_access = refreshed_data["access_token"]
    assert "access_token" in refreshed_data

    # 3. Verify new access token works
    me_res = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {new_access}"})
    assert me_res.status_code == 200
    assert me_res.json()["email"] == dev_user.email

    # 4. Old refresh token was revoked during rotation; re-using it must fail with 401
    second_refresh = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh}
    )
    assert second_refresh.status_code == 401


def test_change_password_flow(client, dev_user):
    # Login to get access token
    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": dev_user.email, "password": "Dev123!"}
    )
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Wrong current password fails with 401
    bad_change = client.post(
        "/api/v1/auth/change-password",
        headers=headers,
        json={"current_password": "WrongPassword!", "new_password": "NewSecret123!"}
    )
    assert bad_change.status_code == 401

    # Correct current password succeeds with 200
    ok_change = client.post(
        "/api/v1/auth/change-password",
        headers=headers,
        json={"current_password": "Dev123!", "new_password": "NewSecret123!"}
    )
    assert ok_change.status_code == 200

    # Old password no longer works
    old_login = client.post(
        "/api/v1/auth/login",
        json={"email": dev_user.email, "password": "Dev123!"}
    )
    assert old_login.status_code == 401

    # New password works
    new_login = client.post(
        "/api/v1/auth/login",
        json={"email": dev_user.email, "password": "NewSecret123!"}
    )
    assert new_login.status_code == 200
