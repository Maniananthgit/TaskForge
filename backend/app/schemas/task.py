from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict
from app.models.enums import TaskStatus, TaskPriority
from app.schemas.user import UserResponse
from app.schemas.comment import CommentResponse
from app.schemas.task_history import TaskHistoryResponse


class TaskBase(BaseModel):
    title: str = Field(..., max_length=255)
    description: Optional[str] = None
    status: TaskStatus = TaskStatus.TODO
    priority: TaskPriority = TaskPriority.MEDIUM
    due_date: Optional[datetime] = None
    estimated_hours: float = 0.0
    actual_hours: float = 0.0
    assignee_id: Optional[int] = None
    is_client_visible: bool = True


class TaskCreate(TaskBase):
    project_id: int


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[TaskStatus] = None
    priority: Optional[TaskPriority] = None
    due_date: Optional[datetime] = None
    estimated_hours: Optional[float] = None
    actual_hours: Optional[float] = None
    assignee_id: Optional[int] = None
    is_client_visible: Optional[bool] = None


class TaskStatusUpdate(BaseModel):
    status: TaskStatus


class TaskResponse(TaskBase):
    id: int
    project_id: int
    creator_id: Optional[int] = None
    creator: Optional[UserResponse] = None
    assignee: Optional[UserResponse] = None
    is_overdue: bool = False
    comments_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TaskDetailResponse(TaskResponse):
    comments: List[CommentResponse] = []
    history: List[TaskHistoryResponse] = []

    model_config = ConfigDict(from_attributes=True)
