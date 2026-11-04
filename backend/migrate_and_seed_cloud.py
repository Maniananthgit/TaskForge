"""
Cloud Database Setup & Migration Script for TaskForge
Usage:
    python backend/migrate_and_seed_cloud.py "postgresql://user:password@ep-xyz.neon.tech/neondb?sslmode=require"
Or:
    Set DATABASE_URL in backend/.env and run:
    python backend/migrate_and_seed_cloud.py
"""
import sys
import os

# Add parent directory to path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from datetime import datetime, timedelta, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

def setup_and_seed(database_url: str):
    print("=" * 60)
    print("TaskForge Cloud PostgreSQL Setup & Seeder")
    print("=" * 60)

    # Normalize PostgreSQL URL for psycopg2
    clean_url = database_url.strip()
    if clean_url.startswith("postgres://"):
        clean_url = clean_url.replace("postgres://", "postgresql+psycopg2://", 1)
    elif clean_url.startswith("postgresql://") and not clean_url.startswith("postgresql+"):
        clean_url = clean_url.replace("postgresql://", "postgresql+psycopg2://", 1)

    print(f"Connecting to database...")

    try:
        engine = create_engine(clean_url, pool_pre_ping=True)
        connection = engine.connect()
        connection.close()
        print("Connected to PostgreSQL successfully!")
    except Exception as e:
        print(f"Connection failed: {e}")
        return False

    # Import models and Base
    from app.core.database import Base
    from app.models.user import User
    from app.models.project import Project
    from app.models.project_member import ProjectMember
    from app.models.task import Task
    from app.models.enums import UserRole, UserStatus, ProjectStatus, ProjectPriority, TaskStatus, TaskPriority
    from app.core.security import get_password_hash

    # 1. Create all tables
    print("Creating all tables in cloud database...")
    Base.metadata.create_all(bind=engine)
    print("All database tables created successfully!")

    # 2. Seed initial enterprise records
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()

    try:
        now = datetime.now(timezone.utc)
        print("Seeding users...")
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
                    department=u_data["department"],
                    job_title=u_data["job_title"],
                    last_login_at=now,
                )
                db.add(user)
                db.flush()
                user_map[u_data["email"]] = user
                print(f"  + Added user: {u_data['full_name']} ({u_data['email']})")
            else:
                user_map[u_data["email"]] = existing
                print(f"  = User exists: {u_data['full_name']}")

        admin_user = user_map.get("admin@taskforge.internal")
        pm_user = user_map.get("pm@taskforge.internal")
        dev_user = user_map.get("dev@taskforge.internal")

        # 2. Projects
        if admin_user and db.query(Project).count() == 0:
            print("Seeding projects...")
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
            print("  + Created 4 enterprise projects")

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
            print("  + Assigned project members")

            # 4. Tasks
            if dev_user and pm_user:
                print("Seeding tasks...")
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
                print("  + Created 4 enterprise tasks")

        db.commit()
        total_users = db.query(User).count()
        total_projects = db.query(Project).count()
        total_tasks = db.query(Task).count()

        print("=" * 60)
        print(f"DATABASE SEED VERIFICATION:")
        print(f"  Total Users in Cloud DB:    {total_users}")
        print(f"  Total Projects in Cloud DB: {total_projects}")
        print(f"  Total Tasks in Cloud DB:    {total_tasks}")
        print("=" * 60)
        print("Success! All data is permanently stored in the Cloud PostgreSQL Database.")
        return True
    except Exception as e:
        print(f"Error seeding database: {e}")
        db.rollback()
        return False
    finally:
        db.close()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_url = sys.argv[1]
    else:
        from app.core.config import settings
        target_url = settings.DATABASE_URL

    setup_and_seed(target_url)
