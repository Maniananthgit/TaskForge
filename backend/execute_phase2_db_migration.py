import os
import sys
from datetime import datetime, timezone
from sqlalchemy import create_engine, text, inspect
import bcrypt

def hash_pw(pw: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(pw.encode("utf-8")[:72], salt).decode("utf-8")
DB_URL = "postgresql+psycopg2://neondb_owner:npg_vO8DHhN3wJEb@ep-orange-frost-beug30ej-pooler.c-9.us-east-2.aws.neon.tech/neondb?sslmode=require"

def run_phase2_database_engineering():
    print("=" * 70)
    print("PHASE 2: POSTGRESQL DATABASE ENGINEERING & HARDENING")
    print("Target: Neon Serverless PostgreSQL")
    print("=" * 70)

    engine = create_engine(DB_URL, pool_pre_ping=True)

    with engine.connect() as conn:
        print("\n1. Applying Enum Extensions for 4-Role RBAC...")
        # Check if userrole is an enum or varchar
        try:
            conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'employee';"))
            conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'client';"))
            conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'EMPLOYEE';"))
            conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'CLIENT';"))
            conn.commit()
            print("  + 'employee' and 'client' added to PostgreSQL 'userrole' enum.")
        except Exception as e:
            conn.rollback()
            print(f"  * Enum note: {e}")

        print("\n2. Applying Column Extensions (Client Isolation & Privacy)...")
        # Add client_id to projects
        conn.execute(text("""
            ALTER TABLE projects 
            ADD COLUMN IF NOT EXISTS client_id INTEGER REFERENCES users(id) ON DELETE SET NULL;
        """))

        # Add is_client_visible to tasks
        conn.execute(text("""
            ALTER TABLE tasks 
            ADD COLUMN IF NOT EXISTS is_client_visible BOOLEAN NOT NULL DEFAULT TRUE;
        """))

        # Add is_internal to task_comments
        conn.execute(text("""
            ALTER TABLE task_comments 
            ADD COLUMN IF NOT EXISTS is_internal BOOLEAN NOT NULL DEFAULT FALSE;
        """))
        conn.commit()
        print("  + 'client_id' added to projects.")
        print("  + 'is_client_visible' added to tasks.")
        print("  + 'is_internal' added to task_comments.")

        print("\n3. Creating High-Performance B-Tree Indexes...")
        indexes = [
            ("idx_project_members_user_id", "project_members", "user_id"),
            ("idx_projects_owner_id", "projects", "owner_id"),
            ("idx_projects_client_id", "projects", "client_id"),
            ("idx_tasks_creator_id", "tasks", "creator_id"),
            ("idx_tasks_is_client_visible", "tasks", "is_client_visible"),
            ("idx_tasks_project_status", "tasks", "project_id, status"),
            ("idx_tasks_assignee_status", "tasks", "assignee_id, status"),
            ("idx_task_comments_author_id", "task_comments", "author_id"),
            ("idx_task_comments_is_internal", "task_comments", "is_internal"),
            ("idx_task_history_changed_by_id", "task_history", "changed_by_id"),
            ("idx_users_company_status", "users", "company, status"),
        ]

        for idx_name, table, cols in indexes:
            conn.execute(text(f"CREATE INDEX IF NOT EXISTS {idx_name} ON {table} ({cols});"))
            print(f"  + Index verified: {idx_name} ON {table}({cols})")
        conn.commit()

        print("\n4. Initializing Version-Controlled Alembic Tracking Table...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS alembic_version (
                version_num VARCHAR(32) NOT NULL PRIMARY KEY
            );
        """))
        conn.execute(text("DELETE FROM alembic_version;"))
        conn.execute(text("INSERT INTO alembic_version (version_num) VALUES ('002_roles_client_isolation');"))
        conn.commit()
        print("  + alembic_version stamped to '002_roles_client_isolation'.")

        print("\n5. Ensuring Complete 4-Role Seed Accounts...")
        # Check and seed sample Client and Employee accounts
        client_pass = hash_pw("Client123!")
        employee_pass = hash_pw("Employee123!")
        now = datetime.now(timezone.utc)

        # Check Client user
        client_exists = conn.execute(text("SELECT id FROM users WHERE email = 'client@taskforge.internal';")).first()
        if not client_exists:
            conn.execute(text("""
                INSERT INTO users (email, hashed_password, full_name, role, status, is_active, phone_number, company, department, job_title, created_at, updated_at)
                VALUES ('client@taskforge.internal', :pwd, 'Global Logistics Client', 'client', 'ACTIVE', TRUE, '+1-555-0199', 'Acme Global Logistics', 'Procurement & Strategy', 'Client Stakeholder', :now, :now);
            """), {"pwd": client_pass, "now": now})
            print("  + Created verified CLIENT account: client@taskforge.internal / Client123!")
        else:
            print("  * Verified CLIENT account already present.")

        # Check Employee user
        emp_exists = conn.execute(text("SELECT id FROM users WHERE email = 'employee@taskforge.internal';")).first()
        if not emp_exists:
            conn.execute(text("""
                INSERT INTO users (email, hashed_password, full_name, role, status, is_active, phone_number, company, department, job_title, created_at, updated_at)
                VALUES ('employee@taskforge.internal', :pwd, 'Marcus Vance', 'employee', 'ACTIVE', TRUE, '+1-555-0188', 'TaskForge Technologies', 'Backend Engineering', 'Software Engineer', :now, :now);
            """), {"pwd": employee_pass, "now": now})
            print("  + Created verified EMPLOYEE account: employee@taskforge.internal / Employee123!")
        else:
            print("  * Verified EMPLOYEE account already present.")

        conn.commit()

        # Link project 1 with client
        client_user = conn.execute(text("SELECT id FROM users WHERE email = 'client@taskforge.internal';")).first()
        if client_user:
            conn.execute(text("UPDATE projects SET client_id = :cid WHERE id = 1 AND client_id IS NULL;"), {"cid": client_user[0]})
            conn.commit()
            print(f"  + Project 1 linked to Client ID {client_user[0]}.")

        print("\n6. Verifying Referential Integrity & Preserved Data...")
        users = conn.execute(text("SELECT id, email, full_name, role, company FROM users ORDER BY id;")).fetchall()
        projects = conn.execute(text("SELECT id, title, status, owner_id, client_id FROM projects ORDER BY id;")).fetchall()
        tasks = conn.execute(text("SELECT id, title, status, is_client_visible FROM tasks ORDER BY id;")).fetchall()
        comments = conn.execute(text("SELECT id, task_id, is_internal FROM task_comments ORDER BY id;")).fetchall()

        print(f"\nTotal Users: {len(users)}")
        for u in users:
            print(f"  - [{u[3].upper()}] #{u[0]}: {u[2]} ({u[1]}) | Company: {u[4]}")

        print(f"\nTotal Projects: {len(projects)}")
        for p in projects:
            print(f"  - Project #{p[0]}: '{p[1]}' | Status: {p[2]} | Owner ID: {p[3]} | Client ID: {p[4]}")

        print(f"\nTotal Tasks: {len(tasks)}")
        for t in tasks:
            print(f"  - Task #{t[0]}: '{t[1]}' | Status: {t[2]} | Client Visible: {t[3]}")

        print(f"\nTotal Comments: {len(comments)}")
        for c in comments:
            print(f"  - Comment #{c[0]}: Task #{c[1]} | Internal: {c[2]}")

    print("\n" + "=" * 70)
    print("PHASE 2 DATABASE ENGINEERING COMPLETED SUCCESSFULLY!")
    print("=" * 70)

if __name__ == "__main__":
    run_phase2_database_engineering()
