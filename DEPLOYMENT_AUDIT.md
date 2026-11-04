# DEPLOYMENT_AUDIT.md — Infrastructure, CI/CD & Hosting Audit

**Date**: November 4, 2026  
**Repository**: `Maniananthgit/TaskForge`  
**Frontend Live Host**: Firebase Hosting (`https://taskforge-pm-app.web.app`)  
**Database Host**: Neon Serverless PostgreSQL (`us-east-2.aws.neon.tech`)  
**Auditor**: Lead DevOps & Cloud Infrastructure Engineer  

---

## 1. Executive Summary

TaskForge utilizes a modern multi-cloud hosting strategy: Flutter Web is delivered via **Firebase Hosting's global CDN**, and relational data is persisted in **Neon Serverless PostgreSQL**. The repository is managed on GitHub with continuous integration through GitHub Actions (`.github/workflows/ci.yml`).

The critical operational bottleneck identified is that **the FastAPI backend container is not currently deployed to a dedicated public URL**. While Firebase Hosting deploys successfully, it serves only static web assets. When the web app makes API calls to `/api/v1`, Firebase Hosting rewrites them to `/index.html`, causing API client calls to receive HTML rather than JSON, triggering the offline in-memory demo mode.

---

## 2. CI/CD Pipeline Analysis (`.github/workflows/ci.yml`)

The GitHub Actions workflow contains 5 sequential jobs triggered on push to `main`:

```
[backend-test] ────┐
                   ├──► [docker-build-verification] ──► [deploy-backend-cloudrun]
[frontend-test] ───┴──► [deploy-frontend-firebase]
```

### 2.1 Job 1: `backend-test`
- **Configuration**: Uses `ubuntu-latest` with background services for `postgres:16-alpine` and `redis:7-alpine`.
- **Finding DEP-01 (Severity: MEDIUM)**: The step overrides the database with `DATABASE_URL: "sqlite:///:memory:"`. Although a real Postgres service container is running, the tests run against SQLite. This fails to detect Postgres-specific enum syntax, array operations, or transaction isolation nuances during CI.
- **Remediation**: Configure `DATABASE_URL: "postgresql+psycopg2://postgres:postgres@localhost:5432/taskforge_test_db"` in the CI pytest step.

### 2.2 Job 2: `frontend-test`
- **Configuration**: Sets up Flutter `3.35.3`, runs `flutter pub get`, `flutter analyze --no-fatal-infos`, and `flutter test`.
- **Status**: **PASSING** (25/25 unit & widget tests pass).

### 2.3 Job 3: `docker-build-verification`
- **Configuration**: Builds `taskforge-backend:latest` and `taskforge-frontend:latest` using Docker Buildx.
- **Status**: **PASSING**.

### 2.4 Job 4: `deploy-frontend-firebase`
- **Configuration**: Runs `flutter build web --release --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL || '/api/v1' }}` and deploys using `FirebaseExtended/action-hosting-deploy@v0`.
- **Finding DEP-02 (Severity: HIGH)**: When `secrets.API_BASE_URL` is omitted, the Flutter build bakes in `/api/v1` as a relative path. In `firebase.json`:
  ```json
  "rewrites": [{ "source": "**", "destination": "/index.html" }]
  ```
  Firebase Hosting intercepts all requests to `/api/v1/*` and returns the HTML index page with HTTP 200. The frontend API client detects the HTML payload and falls back to offline in-memory mock storage.
- **Remediation**: Set `API_BASE_URL` to the public HTTPS URL of the deployed FastAPI backend.

### 2.5 Job 5: `deploy-backend-cloudrun`
- **Configuration**: Checks `secrets.GCP_SA_KEY`. If present, authenticates to Google Cloud and deploys to Cloud Run.
- **Finding DEP-03 (Severity: HIGH)**: The deployment step is currently skipped on every push because `GCP_SA_KEY` has not been added to GitHub Repository Secrets.
- **Remediation**: Provide Cloud Run credentials via `GCP_SA_KEY`, or deploy the Docker container to a managed web service platform (e.g. Render, Railway, or Google Cloud Run) and store the live API URL in `API_BASE_URL`.

---

## 3. Cloud Database Configuration (Neon PostgreSQL)

- **Provider**: Neon Serverless PostgreSQL.
- **Region**: `us-east-2` (AWS Ohio).
- **SSL Requirement**: `sslmode=require` & `channel_binding=require`.
- **Connection URL Normalization**: Neon outputs standard `postgresql://` URIs. Python's `psycopg2` requires `postgresql+psycopg2://`. The normalization layer in `backend/app/core/database.py` correctly handles this.
- **Backup & Recovery**: Neon maintains automated point-in-time recovery (PITR) with branch-level backups.

---

## 4. Environment Separation Matrix

| Configuration Component | Development | Staging (CI) | Production |
|:---|:---|:---|:---|
| **Database** | Local Postgres / Neon Dev | CI Postgres container (`localhost:5432`) | Neon Cloud PostgreSQL (`ep-orange-frost...`) |
| **API Base URL** | `http://127.0.0.1:8000/api/v1` | `http://localhost:8000/api/v1` | Live Deployed Backend URL |
| **Frontend URL** | `http://localhost:3000` | Local Web Server | `https://taskforge-pm-app.web.app` |
| **Secrets Storage** | `.env` (gitignored) | GitHub Actions Secrets | Cloud Environment Variables |

