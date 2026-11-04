from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Request, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_roles
from app.models.user import User
from app.models.enums import UserRole, UserStatus
from app.schemas.user import (
    UserResponse, UserDetailResponse, UserUpdate,
    UserRoleUpdate, UserStatusUpdate, UserInviteRequest,
    UserInviteResponse, AcceptInvitationRequest,
    PasswordResetInitiateResponse, PasswordResetConfirmRequest,
    UserProjectAssignment, UserProjectAssignRequest,
    UserSummaryMetrics, UserAuditLogResponse,
    PaginatedUsersResponse
)
from app.services.user_service import user_service

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/metrics", response_model=UserSummaryMetrics)
def get_user_summary_metrics(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint to retrieve user counts by status and system role."""
    return user_service.get_summary_metrics(db)


@router.get("/", response_model=PaginatedUsersResponse)
def list_users(
    query: Optional[str] = Query(None, description="Search by full name or email"),
    search: Optional[str] = Query(None, description="Alternative alias for query/search"),
    role: Optional[UserRole] = Query(None, description="Filter by system role"),
    status_filter: Optional[UserStatus] = Query(None, alias="status", description="Filter by account status"),
    project_id: Optional[int] = Query(None, description="Filter by assigned project ID"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    include_deleted: bool = Query(False, description="Include soft-deleted accounts (admin view)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List users with server-side pagination, multi-criteria filtering, and search."""
    if current_user.role == UserRole.CLIENT:
        from app.core.exceptions import PermissionDeniedException
        raise PermissionDeniedException("Clients are not permitted to list organization users.")

    # Only Admin can view soft-deleted records
    can_include_deleted = include_deleted and current_user.role == UserRole.ADMIN
    search_term = search if search is not None else query

    users, total = user_service.get_users_paginated(
        db,
        skip=skip,
        limit=limit,
        search=search_term,
        role=role,
        status=status_filter,
        project_id=project_id,
        include_deleted=can_include_deleted
    )
    total_pages = (total + limit - 1) // limit if total > 0 else 1
    page = (skip // limit) + 1

    return PaginatedUsersResponse(
        items=users,
        total=total,
        page=page,
        page_size=limit,
        total_pages=total_pages
    )


@router.post("/invite", response_model=UserInviteResponse, status_code=status.HTTP_201_CREATED)
def invite_new_user(
    invite_in: UserInviteRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: invite a new user via single-use hashed token with project assignments."""
    ip = request.client.host if request.client else None
    return user_service.invite_user(db, current_admin=current_user, invite_in=invite_in, ip_address=ip)


@router.post("/accept-invitation", response_model=UserResponse)
def accept_invitation(
    accept_in: AcceptInvitationRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    """Public endpoint: accept an invitation, set an initial password, and activate account."""
    ip = request.client.host if request.client else None
    return user_service.accept_invitation(
        db,
        token=accept_in.token,
        password=accept_in.password,
        ip_address=ip
    )


@router.post("/confirm-password-reset", response_model=UserResponse)
def confirm_password_reset(
    reset_in: PasswordResetConfirmRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    """Public endpoint: complete password reset using a single-use verification token."""
    ip = request.client.host if request.client else None
    return user_service.confirm_password_reset(
        db,
        token=reset_in.token,
        new_password=reset_in.new_password,
        ip_address=ip
    )


@router.get("/{user_id}", response_model=UserDetailResponse)
def get_user_detail(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive user profile with project assignments, status, and last login."""
    if current_user.role != UserRole.ADMIN and current_user.id != user_id:
        from app.core.exceptions import PermissionDeniedException
        raise PermissionDeniedException("You are not authorized to view other user details.")
    return user_service.get_user_detail(db, user_id=user_id)


@router.put("/{user_id}", response_model=UserResponse)
def update_user_profile(
    user_id: int,
    update_in: UserUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: update user profile attributes (full name, phone, department, title)."""
    ip = request.client.host if request.client else None
    return user_service.update_user_profile(
        db,
        current_admin=current_user,
        user_id=user_id,
        update_in=update_in,
        ip_address=ip
    )


@router.patch("/{user_id}/role", response_model=UserResponse)
def change_user_role(
    user_id: int,
    role_in: UserRoleUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: change user role with safeguards against self-demotion & last admin removal."""
    ip = request.client.host if request.client else None
    return user_service.update_user_role(
        db,
        current_admin=current_user,
        user_id=user_id,
        role_in=role_in,
        ip_address=ip
    )


@router.patch("/{user_id}/status", response_model=UserResponse)
def change_user_status(
    user_id: int,
    status_in: UserStatusUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: update account status (Active, Inactive, Suspended)."""
    ip = request.client.host if request.client else None
    return user_service.update_user_status(
        db,
        current_admin=current_user,
        user_id=user_id,
        status_in=status_in,
        ip_address=ip
    )


@router.delete("/{user_id}", response_model=UserResponse)
def soft_delete_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: soft-delete user preserving all historical task, comment, and audit data."""
    ip = request.client.host if request.client else None
    return user_service.soft_delete_user(
        db,
        current_admin=current_user,
        user_id=user_id,
        ip_address=ip
    )


@router.post("/{user_id}/restore", response_model=UserResponse)
def restore_soft_deleted_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: restore an eligible soft-deleted account back to Inactive."""
    ip = request.client.host if request.client else None
    return user_service.restore_user(
        db,
        current_admin=current_user,
        user_id=user_id,
        ip_address=ip
    )


@router.post("/{user_id}/resend-invitation", response_model=UserInviteResponse)
def resend_invitation(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: revoke previous invitations and issue a fresh 24h invitation token."""
    ip = request.client.host if request.client else None
    return user_service.resend_invitation(
        db,
        current_admin=current_user,
        user_id=user_id,
        ip_address=ip
    )


@router.post("/{user_id}/reset-password", response_model=PasswordResetInitiateResponse)
def initiate_password_reset(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: generate secure single-use password reset token and dispatch reset email."""
    ip = request.client.host if request.client else None
    return user_service.initiate_password_reset(
        db,
        current_admin=current_user,
        user_id=user_id,
        ip_address=ip
    )


@router.get("/{user_id}/projects", response_model=List[UserProjectAssignment])
def get_user_projects(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all projects assigned to the specified user."""
    detail = user_service.get_user_detail(db, user_id=user_id)
    return detail.assigned_projects


@router.post("/{user_id}/projects", response_model=UserProjectAssignment, status_code=status.HTTP_201_CREATED)
def assign_user_to_project(
    user_id: int,
    assignment_in: UserProjectAssignRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: assign user to a project with role validation and duplicate prevention."""
    ip = request.client.host if request.client else None
    member = user_service.assign_user_to_project(
        db,
        current_admin=current_user,
        user_id=user_id,
        project_id=assignment_in.project_id,
        role_in_project=assignment_in.role_in_project,
        ip_address=ip
    )
    from app.models.project import Project
    proj = db.query(Project).filter(Project.id == member.project_id).first()
    return UserProjectAssignment(
        project_id=member.project_id,
        project_title=proj.title if proj else str(member.project_id),
        role_in_project=member.role_in_project,
        joined_at=member.joined_at
    )


@router.delete("/{user_id}/projects/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_user_from_project(
    user_id: int,
    project_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: remove user from a project without deleting historical task records."""
    ip = request.client.host if request.client else None
    user_service.remove_user_from_project(
        db,
        current_admin=current_user,
        user_id=user_id,
        project_id=project_id,
        ip_address=ip
    )
    return None


@router.get("/{user_id}/activity", response_model=List[UserAuditLogResponse])
def get_user_activity(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint: retrieve immutable chronological audit trail for the target user."""
    return user_service.get_user_activity(db, user_id=user_id)
