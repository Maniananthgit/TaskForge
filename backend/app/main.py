from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.database import engine, Base, SessionLocal
from app.core.exceptions import TaskForgeException
from app.core.security import get_password_hash, RSAKeyManager
from app.core.logging import logger
from app.models.user import User
from app.models.enums import UserRole, UserStatus
from app.api.v1.api import api_router


def seed_initial_data():
    """Seed initial administrator, team members, projects, and tasks if not present."""
    from datetime import datetime, timedelta, timezone
    from app.models.project import Project
    from app.models.project_member import ProjectMember
    from app.models.task import Task
    from app.models.enums import ProjectStatus, ProjectPriority, TaskStatus, TaskPriority

    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)

        # 1. Users to seed (All 5 enterprise accounts)
        users_data = [
            {
                "email": "admin@taskforge.internal",
                "password": "Admin123!",
                "full_name": "Super Admin",
                "role": UserRole.ADMIN,
                "status": UserStatus.ACTIVE,
                "phone_number": "+1-555-0100",
                "department": "Platform Engineering",
                "job_title": "Principal Security Architect",
            },
            {
                "email": "pm@taskforge.internal",
                "password": "Manager123!",
                "full_name": "Elena Rostova",
                "role": UserRole.PROJECT_MANAGER,
                "status": UserStatus.ACTIVE,
                "phone_number": "+1-555-0122",
                "department": "Product Operations",
                "job_title": "Senior Technical Program Manager",
            },
            {
                "email": "dev@taskforge.internal",
                "password": "Developer123!",
                "full_name": "David Chen",
                "role": UserRole.DEVELOPER,
                "status": UserStatus.ACTIVE,
                "phone_number": "+1-555-0133",
                "department": "Frontend Engineering",
                "job_title": "Senior Flutter Developer",
            },
            {
                "email": "sarah.connor@taskforge.internal",
                "password": "Developer123!",
                "full_name": "Sarah Connor",
                "role": UserRole.DEVELOPER,
                "status": UserStatus.PENDING_INVITATION,
                "is_active": False,
                "phone_number": "+1-555-0144",
                "department": "Security Operations",
                "job_title": "AppSec Engineer",
            },
            {
                "email": "alex.rivera@taskforge.internal",
                "password": "Developer123!",
                "full_name": "Alex Rivera",
                "role": UserRole.DEVELOPER,
                "status": UserStatus.INACTIVE,
                "is_active": False,
                "phone_number": "+1-555-0155",
                "department": "QA & Automation",
                "job_title": "QA Automation Engineer",
            },
        ]

        user_map = {}
        for u_data in users_data:
            existing = db.query(User).filter(User.email == u_data["email"]).first()
            if not existing:
                user = User(
                    email=u_data["email"],
                    hashed_password=get_password_hash(u_data["password"]),
                    full_name=u_data["full_name"],
                    role=u_data["role"],
                    status=u_data["status"],
                    is_active=u_data.get("is_active", True),
                    phone_number=u_data["phone_number"],
                    company="TaskForge Technologies",
                    department=u_data["department"],
                    job_title=u_data["job_title"],
                    last_login_at=now,
                )
                db.add(user)
                db.flush()
                user_map[u_data["email"]] = user
            else:
                user_map[u_data["email"]] = existing

        admin_user = user_map.get("admin@taskforge.internal")
        pm_user = user_map.get("pm@taskforge.internal")
        dev_user = user_map.get("dev@taskforge.internal")

        # 2. Projects to seed
        if admin_user and db.query(Project).count() == 0:
            p1 = Project(
                title="Cloud Infrastructure & Kubernetes",
                description="Multi-region AWS & GCP Kubernetes cluster deployment with automated canary rollouts and zero-downtime failover.",
                status=ProjectStatus.IN_PROGRESS,
                priority=ProjectPriority.URGENT,
                start_date=now - timedelta(days=30),
                due_date=now + timedelta(days=60),
                budget_hours=120.0,
                owner_id=admin_user.id
            )
            p2 = Project(
                title="TaskForge Flutter Web App Redesign",
                description="Modern, responsive Flutter enterprise UI featuring MVVM state management and dark/light themes.",
                status=ProjectStatus.IN_PROGRESS,
                priority=ProjectPriority.HIGH,
                start_date=now - timedelta(days=15),
                due_date=now + timedelta(days=45),
                budget_hours=80.0,
                owner_id=pm_user.id if pm_user else admin_user.id
            )
            p3 = Project(
                title="PostgreSQL RBAC Security Hardening",
                description="Row-level security enforcement, audited role transitions, and secure bcrypt credential hashing policies.",
                status=ProjectStatus.PLANNING,
                priority=ProjectPriority.MEDIUM,
                start_date=now,
                due_date=now + timedelta(days=30),
                budget_hours=60.0,
                owner_id=admin_user.id
            )
            p4 = Project(
                title="Design System 2.0 & Component Library",
                description="Unified design tokens, accessibility compliance (WCAG 2.1 AA), and reusable design assets.",
                status=ProjectStatus.PLANNING,
                priority=ProjectPriority.LOW,
                start_date=now,
                due_date=now + timedelta(days=90),
                budget_hours=40.0,
                owner_id=pm_user.id if pm_user else admin_user.id
            )
            db.add_all([p1, p2, p3, p4])
            db.flush()

            # 3. Project Members
            members = [
                ProjectMember(project_id=p1.id, user_id=admin_user.id, role_in_project="Lead"),
                ProjectMember(project_id=p1.id, user_id=pm_user.id, role_in_project="Member") if pm_user else None,
                ProjectMember(project_id=p2.id, user_id=pm_user.id, role_in_project="Lead") if pm_user else None,
                ProjectMember(project_id=p2.id, user_id=dev_user.id, role_in_project="Member") if dev_user else None,
                ProjectMember(project_id=p3.id, user_id=admin_user.id, role_in_project="Lead"),
            ]
            for m in members:
                if m:
                    db.add(m)

            # 4. Tasks to seed
            if dev_user and pm_user:
                t1 = Task(
                    project_id=p1.id,
                    title="Implement Redis Token Blacklist Revocation",
                    description="Ensure token blacklist persists in Redis with TTL matching JWT expiration.",
                    status=TaskStatus.IN_PROGRESS,
                    priority=TaskPriority.URGENT,
                    due_date=now + timedelta(days=1),
                    estimated_hours=8.0,
                    actual_hours=4.5,
                    creator_id=admin_user.id,
                    assignee_id=dev_user.id
                )
                t2 = Task(
                    project_id=p2.id,
                    title="Design Responsive Mobile Navigation Shell",
                    description="Adaptive bottom navigation for mobile and navigation rail for wide desktop screens.",
                    status=TaskStatus.TODO,
                    priority=TaskPriority.HIGH,
                    due_date=now + timedelta(days=3),
                    estimated_hours=12.0,
                    actual_hours=2.0,
                    creator_id=pm_user.id,
                    assignee_id=dev_user.id
                )
                t3 = Task(
                    project_id=p3.id,
                    title="Alembic Database Migration Script Review",
                    description="Verify foreign keys, cascading deletes, and default timestamp triggers.",
                    status=TaskStatus.DONE,
                    priority=TaskPriority.MEDIUM,
                    due_date=now - timedelta(days=2),
                    estimated_hours=6.0,
                    actual_hours=5.5,
                    creator_id=pm_user.id,
                    assignee_id=admin_user.id
                )
                t4 = Task(
                    project_id=p3.id,
                    title="Configure Asymmetric RSA-OAEP-256 Key Exchange",
                    description="Secure payload encryption for sensitive communication between client and backend.",
                    status=TaskStatus.IN_REVIEW,
                    priority=TaskPriority.URGENT,
                    due_date=now + timedelta(days=2),
                    estimated_hours=10.0,
                    actual_hours=9.0,
                    creator_id=admin_user.id,
                    assignee_id=pm_user.id
                )
                db.add_all([t1, t2, t3, t4])

        db.commit()
        logger.info("Initial seed accounts and enterprise sample data checked/created.")
    except Exception as e:
        logger.warning(f"Seed data execution notice: {e}")
        db.rollback()
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure tables exist and seed default accounts
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION} [{settings.ENVIRONMENT}]")
    try:
        Base.metadata.create_all(bind=engine)
        seed_initial_data()
    except Exception as e:
        logger.error(f"Error during startup table creation: {e}")
    yield
    # Shutdown
    logger.info("Shutting down TaskForge backend application...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Enterprise Project Management System — High-performance REST APIs built with FastAPI, SQLAlchemy 2.0 & PostgreSQL.",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Exception Handlers
@app.exception_handler(TaskForgeException)
async def taskforge_exception_handler(request: Request, exc: TaskForgeException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error_code": exc.error_code,
            "message": exc.detail,
            "path": request.url.path,
        },
        headers=exc.headers
    )


from fastapi.exceptions import RequestValidationError
from sqlalchemy.exc import SQLAlchemyError


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    first_msg = errors[0].get("msg", "Invalid request body") if errors else "Validation failed"
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error_code": "VALIDATION_ERROR",
            "message": f"Validation failed: {first_msg}",
            "details": errors,
            "path": request.url.path,
        }
    )


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    # Log database error with complete traceback internally, but NEVER leak SQL or credentials to clients
    logger.error(f"Database error at {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error_code": "DATABASE_ERROR",
            "message": "A database error occurred while processing your request. Please try again later.",
            "path": request.url.path,
        }
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error_code": "HTTP_ERROR",
            "message": exc.detail if isinstance(exc.detail, str) else str(exc.detail),
            "path": request.url.path,
        },
        headers=exc.headers
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception at {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": "An unexpected error occurred. Please contact the administrator.",
            "path": request.url.path,
        }
    )


# Public RSA Key endpoint for client asymmetric encryption
@app.get(f"{settings.API_V1_STR}/auth/rsa-public-key", tags=["Authentication"])
def get_rsa_public_key():
    """Retrieve server RSA Public Key PEM for client-side asymmetric payload encryption."""
    pem = RSAKeyManager.get_public_pem()
    return {"algorithm": "RSA-OAEP-256", "public_key": pem}


# Include V1 API Routers
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/", include_in_schema=False)
def root_redirect():
    return {
        "name": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": f"{settings.API_V1_STR}/docs"
    }
