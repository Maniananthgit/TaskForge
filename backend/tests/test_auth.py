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
