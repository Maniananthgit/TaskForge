from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.comment import CommentCreate, CommentResponse
from app.schemas.common import MessageResponse
from app.repositories.comment_repository import comment_repo
from app.services.comment_service import comment_service

router = APIRouter(tags=["Comments"])


@router.get("/tasks/{task_id}/comments", response_model=List[CommentResponse])
def get_task_comments(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all discussion comments for a task."""
    return comment_repo.get_by_task(db, task_id=task_id)


@router.post("/tasks/{task_id}/comments", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
def add_task_comment(
    task_id: int,
    comment_in: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Post a comment to a task."""
    return comment_service.add_comment(
        db, task_id=task_id, comment_in=comment_in, current_user=current_user
    )


@router.delete("/comments/{comment_id}", response_model=MessageResponse)
def delete_comment(
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a comment (Author or Admin only)."""
    comment_service.delete_comment(db, comment_id=comment_id, current_user=current_user)
    return MessageResponse(message="Comment deleted successfully.")
