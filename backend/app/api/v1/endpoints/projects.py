import math
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user, require_roles
from app.models.user import User
from app.models.enums import UserRole, ProjectStatus, ProjectPriority
from app.schemas.project import (
    ProjectCreate, ProjectUpdate, ProjectResponse, ProjectDetailResponse,
    ProjectMemberCreate, ProjectMemberResponse
)
from app.schemas.common import PaginatedResponse, MessageResponse
from app.services.project_service import project_service

router = APIRouter(prefix="/projects", tags=["Projects"])


@router.get("/", response_model=PaginatedResponse[ProjectResponse])
def get_projects(
    search: Optional[str] = Query(None, description="Search term for title/description"),
    status: Optional[ProjectStatus] = Query(None, description="Filter by status"),
    priority: Optional[ProjectPriority] = Query(None, description="Filter by priority"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Items per page"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve paginated and filtered list of projects."""
    skip = (page - 1) * page_size
    items, total = project_service.get_projects(
        db,
        current_user=current_user,
        search=search,
        status=status,
        priority=priority,
        skip=skip,
        limit=page_size
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 1

    return PaginatedResponse[ProjectResponse](
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages
    )


@router.post("/", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(
    project_in: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN, UserRole.PROJECT_MANAGER]))
):
    """Create a new project (Admin or Project Manager only)."""
    project = project_service.create_project(db, project_in=project_in, current_user=current_user)
    # Return with progress metrics
    return project_service.get_project_by_id(db, project_id=project.id, current_user=current_user)


@router.get("/{project_id}", response_model=ProjectDetailResponse)
def get_project_detail(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get project details including members and completion statistics."""
    return project_service.get_project_by_id(db, project_id=project_id, current_user=current_user)


@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: int,
    project_in: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update project details."""
    project = project_service.update_project(
        db, project_id=project_id, project_in=project_in, current_user=current_user
    )
    return project_service.get_project_by_id(db, project_id=project.id, current_user=current_user)


@router.delete("/{project_id}", response_model=MessageResponse)
def delete_project(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a project (Admin or Owner only)."""
    project_service.delete_project(db, project_id=project_id, current_user=current_user)
    return MessageResponse(message="Project deleted successfully.")


@router.post("/{project_id}/members", response_model=ProjectMemberResponse, status_code=status.HTTP_201_CREATED)
def add_project_member(
    project_id: int,
    member_in: ProjectMemberCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Assign a member to a project."""
    member = project_service.add_member(
        db, project_id=project_id, member_in=member_in, current_user=current_user
    )
    return member


@router.delete("/{project_id}/members/{user_id}", response_model=MessageResponse)
def remove_project_member(
    project_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove a member from a project."""
    project_service.remove_member(
        db, project_id=project_id, user_id=user_id, current_user=current_user
    )
    return MessageResponse(message="Member removed from project successfully.")
