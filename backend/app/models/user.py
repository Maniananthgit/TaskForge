from sqlalchemy import Column, Integer, String, Boolean, Enum, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin
from app.models.enums import UserRole, UserStatus


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.DEVELOPER, nullable=False)
    status = Column(Enum(UserStatus), default=UserStatus.ACTIVE, nullable=False, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    phone_number = Column(String(50), nullable=True)
    company = Column(String(100), default="TaskForge Technologies", nullable=True)
    department = Column(String(100), nullable=True)
    job_title = Column(String(100), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True, index=True)

    # Relationships
    owned_projects = relationship("Project", back_populates="owner", cascade="all, delete-orphan")
    project_memberships = relationship("ProjectMember", back_populates="user", cascade="all, delete-orphan")
    created_tasks = relationship("Task", foreign_keys="Task.creator_id", back_populates="creator")
    assigned_tasks = relationship("Task", foreign_keys="Task.assignee_id", back_populates="assignee")
    comments = relationship("TaskComment", back_populates="author", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    invitations = relationship("UserInvitation", foreign_keys="UserInvitation.user_id", back_populates="user", cascade="all, delete-orphan")
    sent_invitations = relationship("UserInvitation", foreign_keys="UserInvitation.invited_by_id", back_populates="invited_by")
    password_reset_tokens = relationship("PasswordResetToken", back_populates="user", cascade="all, delete-orphan")
    audit_logs = relationship("UserAuditLog", foreign_keys="UserAuditLog.target_user_id", back_populates="target_user", cascade="all, delete-orphan")
    actions_performed = relationship("UserAuditLog", foreign_keys="UserAuditLog.actor_id", back_populates="actor")

    def __repr__(self):
        return f"<User id={self.id} email='{self.email}' role='{self.role}' status='{self.status}'>"
