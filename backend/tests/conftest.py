import sys
import os

# Ensure local backend/ directory takes precedence over any site-packages "app"
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

os.environ["ENVIRONMENT"] = "testing"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

from app.core.config import settings
settings.DATABASE_URL = "sqlite:///:memory:"
settings.ENVIRONMENT = "testing"

import pytest
from typing import Generator
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
import app.core.database as core_db

# Point core_db.engine and SessionLocal to test sqlite engine
test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False}
)
core_db.engine = test_engine
core_db.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User
from app.models.enums import UserRole
from app.worker.celery_app import celery_app

# Enable eager execution for Celery tasks in test suite so no external broker is needed
celery_app.conf.update(
    task_always_eager=True,
    task_eager_propagates=True,
)

# Use in-memory SQLite database for fast, isolated, reliable tests
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session")
def db_engine():
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def db(db_engine) -> Generator[Session, None, None]:
    connection = db_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture(scope="function")
def client(db: Session) -> Generator[TestClient, None, None]:
    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def admin_user(db: Session) -> User:
    admin = User(
        email="admin_test@taskforge.internal",
        hashed_password=get_password_hash("Admin123!"),
        full_name="Admin Tester",
        role=UserRole.ADMIN,
        is_active=True
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


@pytest.fixture
def pm_user(db: Session) -> User:
    pm = User(
        email="pm_test@taskforge.internal",
        hashed_password=get_password_hash("Manager123!"),
        full_name="PM Tester",
        role=UserRole.PROJECT_MANAGER,
        is_active=True
    )
    db.add(pm)
    db.commit()
    db.refresh(pm)
    return pm


@pytest.fixture
def dev_user(db: Session) -> User:
    dev = User(
        email="dev_test@taskforge.internal",
        hashed_password=get_password_hash("Dev123!"),
        full_name="Developer Tester",
        role=UserRole.DEVELOPER,
        is_active=True
    )
    db.add(dev)
    db.commit()
    db.refresh(dev)
    return dev


@pytest.fixture
def admin_token(admin_user: User) -> str:
    return create_access_token(
        subject=admin_user.id,
        role=admin_user.role.value,
        email=admin_user.email
    )


@pytest.fixture
def admin_token_headers(admin_token: str) -> dict:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def pm_token(pm_user: User) -> str:
    return create_access_token(
        subject=pm_user.id,
        role=pm_user.role.value,
        email=pm_user.email
    )


@pytest.fixture
def pm_token_headers(pm_token: str) -> dict:
    return {"Authorization": f"Bearer {pm_token}"}


@pytest.fixture
def dev_token(dev_user: User) -> str:
    return create_access_token(
        subject=dev_user.id,
        role=dev_user.role.value,
        email=dev_user.email
    )


@pytest.fixture
def dev_token_headers(dev_token: str) -> dict:
    return {"Authorization": f"Bearer {dev_token}"}
