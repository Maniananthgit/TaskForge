"""Add Admin User Management module tables and user attributes

Revision ID: 001_user_mgmt
Revises: 
Create Date: 2026-11-02 16:55:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001_user_mgmt'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # Create user_status enum if postgresql
    bind = op.get_bind()
    is_postgres = bind.dialect.name == "postgresql"

    user_status_enum = sa.Enum(
        'pending_invitation', 'active', 'inactive', 'suspended', 'deleted',
        name='userstatus'
    )
    if is_postgres:
        user_status_enum.create(bind, checkfirst=True)

    # Add columns to users table
    with op.batch_alter_table('users') as batch_op:
        batch_op.add_column(sa.Column('status', user_status_enum, nullable=False, server_default='active'))
        batch_op.add_column(sa.Column('phone_number', sa.String(50), nullable=True))
        batch_op.add_column(sa.Column('department', sa.String(100), nullable=True))
        batch_op.add_column(sa.Column('job_title', sa.String(100), nullable=True))
        batch_op.add_column(sa.Column('last_login_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.create_index('ix_users_status', ['status'])
        batch_op.create_index('ix_users_deleted_at', ['deleted_at'])

    # Create user_invitations table
    op.create_table(
        'user_invitations',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('token_hash', sa.String(255), unique=True, index=True, nullable=False),
        sa.Column('invited_by_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('accepted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)
    )

    # Create password_reset_tokens table
    op.create_table(
        'password_reset_tokens',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('token_hash', sa.String(255), unique=True, index=True, nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)
    )

    # Create user_audit_logs table
    op.create_table(
        'user_audit_logs',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('actor_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True),
        sa.Column('target_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('action', sa.String(100), nullable=False, index=True),
        sa.Column('details', sa.JSON(), nullable=True),
        sa.Column('ip_address', sa.String(45), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, index=True)
    )


def downgrade():
    op.drop_table('user_audit_logs')
    op.drop_table('password_reset_tokens')
    op.drop_table('user_invitations')

    with op.batch_alter_table('users') as batch_op:
        batch_op.drop_index('ix_users_deleted_at')
        batch_op.drop_index('ix_users_status')
        batch_op.drop_column('deleted_at')
        batch_op.drop_column('last_login_at')
        batch_op.drop_column('job_title')
        batch_op.drop_column('department')
        batch_op.drop_column('phone_number')
        batch_op.drop_column('status')

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        sa.Enum(name='userstatus').drop(bind, checkfirst=True)
