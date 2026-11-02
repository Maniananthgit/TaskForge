from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from app.models.enums import UserRole, UserStatus


class UserBase(BaseModel):
    email: EmailStr
    full_name: str
    role: UserRole = UserRole.DEVELOPER
    status: UserStatus = UserStatus.ACTIVE
    is_active: bool = True
    phone_number: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    avatar_url: Optional[str] = None


class UserCreate(BaseModel):
    email: EmailStr
    full_name: str
    password: str = Field(..., min_length=6, description="Password with minimum 6 characters")
    role: UserRole = UserRole.DEVELOPER
    phone_number: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    avatar_url: Optional[str] = None


class UserInviteRequest(BaseModel):
    email: EmailStr
    full_name: str
    role: UserRole = UserRole.DEVELOPER
    phone_number: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    assigned_project_ids: Optional[List[int]] = None


class UserInviteResponse(BaseModel):
    user_id: int
    email: EmailStr
    full_name: str
    role: UserRole
    status: UserStatus
    invitation_expires_at: datetime
    invitation_token: Optional[str] = None
    email_delivery_status: str = "Email delivery is pending configuration (SMTP / SES)"


class AcceptInvitationRequest(BaseModel):
    token: str
    password: str = Field(..., min_length=6, description="Password with minimum 6 characters")


class PasswordResetInitiateResponse(BaseModel):
    message: str
    expires_at: datetime
    reset_token: Optional[str] = None
    email_delivery_status: str = "Email delivery is pending configuration (SMTP / SES)"


class PasswordResetConfirmRequest(BaseModel):
    token: str
    new_password: str = Field(..., min_length=6, description="New password with minimum 6 characters")


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    role: Optional[UserRole] = None
    phone_number: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    avatar_url: Optional[str] = None
    password: Optional[str] = Field(None, min_length=6)


class UserRoleUpdate(BaseModel):
    role: UserRole


class UserStatusUpdate(BaseModel):
    status: UserStatus


class UserProjectAssignment(BaseModel):
    project_id: int
    project_title: str
    role_in_project: str
    joined_at: Optional[datetime] = None


class UserProjectAssignRequest(BaseModel):
    project_id: int
    role_in_project: str = "Member"


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    full_name: str
    role: UserRole
    status: UserStatus
    is_active: bool
    phone_number: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    avatar_url: Optional[str] = None
    last_login_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserDetailResponse(UserResponse):
    assigned_projects: List[UserProjectAssignment] = []
    invitation_pending: bool = False
    invitation_expires_at: Optional[datetime] = None


class UserSummaryMetrics(BaseModel):
    total_users: int
    active_users: int
    inactive_users: int
    suspended_users: int
    pending_invitations: int
    admins_count: int
    project_managers_count: int
    developers_count: int


class UserAuditLogResponse(BaseModel):
    id: int
    actor_id: Optional[int] = None
    actor_name: Optional[str] = None
    target_user_id: int
    action: str
    details: Optional[Dict[str, Any]] = None
    ip_address: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PaginatedUsersResponse(BaseModel):
    items: List[UserResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


class TokenPayload(BaseModel):
    sub: str
    role: str
    email: str
    exp: int
    iat: int
    jti: str
    type: str
