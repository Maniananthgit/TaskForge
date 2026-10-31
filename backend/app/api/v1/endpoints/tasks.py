import math
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.enums import TaskStatus, TaskPriority
from app.schemas.task import (
    TaskCreate, TaskUpdate, TaskStatusUpdate, TaskResponse, TaskDetailResponse
)
from app.schemas.common import PaginatedResponse, MessageResponse
from app.services.task_service import task_service

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("/", response_model=PaginatedResponse[TaskResponse])
def get_tasks(
    project_id: Optional[int] = Query(None, description="Filter by project ID"),
    assignee_id: Optional[int] = Query(None, description="Filter by assigned user"),
    status: Optional[TaskStatus] = Query(None, description="Filter by task status"),
    priority: Optional[TaskPriority] = Query(None, description="Filter by priority"),
    search: Optional[str] = Query(None, description="Search in task title/desc"),
    overdue_only: bool = Query(False, description="Filter overdue tasks only"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Items per page"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve filtered, sorted and paginated tasks."""
    skip = (page - 1) * page_size
    items, total = task_service.get_tasks(
        db,
        current_user=current_user,
        project_id=project_id,
        assignee_id=assignee_id,
        status=status,
        priority=priority,
        search=search,
        overdue_only=overdue_only,
        skip=skip,
        limit=page_size
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 1

    return PaginatedResponse[TaskResponse](
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages
    )


@router.post("/", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(
    task_in: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new task under a project."""
    task = task_service.create_task(db, task_in=task_in, current_user=current_user)
    return task_service.get_task_by_id(db, task_id=task.id, current_user=current_user)


@router.get("/{task_id}", response_model=TaskDetailResponse)
def get_task_detail(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get full task details including threaded comments and change audit history."""
    return task_service.get_task_by_id(db, task_id=task_id, current_user=current_user)


@router.put("/{task_id}", response_model=TaskResponse)
def update_task(
    task_id: int,
    task_in: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update task properties."""
    task = task_service.update_task(
        db, task_id=task_id, task_in=task_in, current_user=current_user
    )
    return task_service.get_task_by_id(db, task_id=task.id, current_user=current_user)


@router.patch("/{task_id}/status", response_model=TaskResponse)
def update_task_status(
    task_id: int,
    status_in: TaskStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Quick update task status (Backlog -> Todo -> In Progress -> In Review -> Done)."""
    task = task_service.update_status(
        db, task_id=task_id, status_in=status_in, current_user=current_user
    )
    return task_service.get_task_by_id(db, task_id=task.id, current_user=current_user)


@router.delete("/{task_id}", response_model=MessageResponse)
def delete_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a task."""
    task_service.delete_task(db, task_id=task_id, current_user=current_user)
    return MessageResponse(message="Task deleted successfully.")
