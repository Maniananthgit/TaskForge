from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user, require_roles
from app.core.exceptions import EntityNotFoundException
from app.models.user import User
from app.models.enums import UserRole
from app.schemas.user import UserResponse, UserUpdate
from app.repositories.user_repository import user_repo

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/", response_model=List[UserResponse])
def list_users(
    query: Optional[str] = Query(None, description="Search by name or email"),
    role: Optional[UserRole] = Query(None, description="Filter by role"),
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List users for assignment, team management, and directory lookup."""
    if query:
        return user_repo.search_users(db, query=query, skip=skip, limit=limit)
    if role:
        return user_repo.get_by_role(db, role=role)
    return user_repo.get_multi(db, skip=skip, limit=limit)


@router.get("/{user_id}", response_model=UserResponse)
def get_user_by_id(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get user by ID."""
    user = user_repo.get(db, id=user_id)
    if not user:
        raise EntityNotFoundException("User", user_id)
    return user


@router.put("/{user_id}", response_model=UserResponse)
def admin_update_user(
    user_id: int,
    update_in: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN]))
):
    """Admin endpoint to update user roles or deactivate accounts."""
    user = user_repo.get(db, id=user_id)
    if not user:
        raise EntityNotFoundException("User", user_id)
    return user_repo.update(db, db_obj=user, obj_in=update_in.model_dump(exclude_unset=True))
