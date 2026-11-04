from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict
from app.models.enums import ProjectStatus, ProjectPriority
from app.schemas.user import UserResponse


class ProjectMemberCreate(BaseModel):
    user_id: int
    role_in_project: str = "Member"  # Lead, Member, Observer


class ProjectMemberResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    role_in_project: str
    joined_at: datetime
    user: Optional[UserResponse] = None

    model_config = ConfigDict(from_attributes=True)


class ProjectBase(BaseModel):
    title: str = Field(..., max_length=255)
    description: Optional[str] = None
    status: ProjectStatus = ProjectStatus.PLANNING
    priority: ProjectPriority = ProjectPriority.MEDIUM
    start_date: Optional[datetime] = None
    due_date: Optional[datetime] = None
    budget_hours: float = 0.0
    client_id: Optional[int] = None


class ProjectCreate(ProjectBase):
    member_ids: Optional[List[int]] = None


class ProjectUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[ProjectStatus] = None
    priority: Optional[ProjectPriority] = None
    start_date: Optional[datetime] = None
    due_date: Optional[datetime] = None
    budget_hours: Optional[float] = None
    client_id: Optional[int] = None
    owner_id: Optional[int] = None


class ProjectResponse(ProjectBase):
    id: int
    owner_id: int
    owner: Optional[UserResponse] = None
    client_id: Optional[int] = None
    client: Optional[UserResponse] = None
    tasks_count: int = 0
    completed_tasks_count: int = 0
    progress_percentage: float = 0.0
    members_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProjectDetailResponse(ProjectResponse):
    members: List[ProjectMemberResponse] = []

    model_config = ConfigDict(from_attributes=True)
