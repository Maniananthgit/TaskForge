from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
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
    """Seed initial administrator and sample data if not present."""
    db = SessionLocal()
    try:
        admin_email = "admin@taskforge.internal"
        admin = db.query(User).filter(User.email == admin_email).first()
        if not admin:
            admin = User(
                email=admin_email,
                hashed_password=get_password_hash("Admin123!"),
                full_name="Enterprise Administrator",
                role=UserRole.ADMIN,
                status=UserStatus.ACTIVE,
                is_active=True
            )
            db.add(admin)

        # Also seed a Project Manager and a Developer for quick testing
        pm_email = "pm@taskforge.internal"
        pm = db.query(User).filter(User.email == pm_email).first()
        if not pm:
            pm = User(
                email=pm_email,
                hashed_password=get_password_hash("Manager123!"),
                full_name="Sarah Connor (Project Manager)",
                role=UserRole.PROJECT_MANAGER,
                status=UserStatus.ACTIVE,
                is_active=True
            )
            db.add(pm)

        dev_email = "dev@taskforge.internal"
        dev = db.query(User).filter(User.email == dev_email).first()
        if not dev:
            dev = User(
                email=dev_email,
                hashed_password=get_password_hash("Developer123!"),
                full_name="Alex Rivera (Developer)",
                role=UserRole.DEVELOPER,
                status=UserStatus.ACTIVE,
                is_active=True
            )
            db.add(dev)

        db.commit()
        logger.info("Initial seed accounts checked/created.")
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
