"""Add four-role system, client isolation, and performance indexes

Revision ID: 002_roles_client_isolation
Revises: 001_user_mgmt
Create Date: 2026-11-04 11:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '002_roles_client_isolation'
down_revision = '001_user_mgmt'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    is_postgres = bind.dialect.name == "postgresql"

    # 1. Update PostgreSQL userrole enum if applicable
    if is_postgres:
        with bind.connect() as conn:
            conn.execute(sa.text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'employee';"))
            conn.execute(sa.text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'client';"))
            conn.commit()

    # 2. Add client_id column to projects
    with op.batch_alter_table('projects') as batch_op:
        batch_op.add_column(sa.Column('client_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True))
        batch_op.create_index('idx_projects_owner_id', ['owner_id'])
        batch_op.create_index('idx_projects_client_id', ['client_id'])

    # 3. Add is_client_visible column and performance indexes to tasks
    with op.batch_alter_table('tasks') as batch_op:
        batch_op.add_column(sa.Column('is_client_visible', sa.Boolean(), nullable=False, server_default='true'))
        batch_op.create_index('idx_tasks_creator_id', ['creator_id'])
        batch_op.create_index('idx_tasks_is_client_visible', ['is_client_visible'])
        batch_op.create_index('idx_tasks_project_status', ['project_id', 'status'])
        batch_op.create_index('idx_tasks_assignee_status', ['assignee_id', 'status'])

    # 4. Add is_internal column and index to task_comments
    with op.batch_alter_table('task_comments') as batch_op:
        batch_op.add_column(sa.Column('is_internal', sa.Boolean(), nullable=False, server_default='false'))
        batch_op.create_index('idx_task_comments_author_id', ['author_id'])
        batch_op.create_index('idx_task_comments_is_internal', ['is_internal'])

    # 5. Add index on project_members.user_id
    with op.batch_alter_table('project_members') as batch_op:
        batch_op.create_index('idx_project_members_user_id', ['user_id'])

    # 6. Add index on task_history.changed_by_id
    with op.batch_alter_table('task_history') as batch_op:
        batch_op.create_index('idx_task_history_changed_by_id', ['changed_by_id'])

    # 7. Add index on users.company
    with op.batch_alter_table('users') as batch_op:
        batch_op.create_index('idx_users_company_status', ['company', 'status'])


def downgrade():
    with op.batch_alter_table('users') as batch_op:
        batch_op.drop_index('idx_users_company_status')

    with op.batch_alter_table('task_history') as batch_op:
        batch_op.drop_index('idx_task_history_changed_by_id')

    with op.batch_alter_table('project_members') as batch_op:
        batch_op.drop_index('idx_project_members_user_id')

    with op.batch_alter_table('task_comments') as batch_op:
        batch_op.drop_index('idx_task_comments_is_internal')
        batch_op.drop_index('idx_task_comments_author_id')
        batch_op.drop_column('is_internal')

    with op.batch_alter_table('tasks') as batch_op:
        batch_op.drop_index('idx_tasks_assignee_status')
        batch_op.drop_index('idx_tasks_project_status')
        batch_op.drop_index('idx_tasks_is_client_visible')
        batch_op.drop_index('idx_tasks_creator_id')
        batch_op.drop_column('is_client_visible')

    with op.batch_alter_table('projects') as batch_op:
        batch_op.drop_index('idx_projects_client_id')
        batch_op.drop_index('idx_projects_owner_id')
        batch_op.drop_column('client_id')

