from typing import List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.notification import NotificationResponse
from app.schemas.common import MessageResponse
from app.services.notification_service import notification_service

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/", response_model=List[NotificationResponse])
def get_my_notifications(
    unread_only: bool = Query(False, description="Filter unread notifications only"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve logged in user's notifications."""
    return notification_service.get_user_notifications(
        db, user_id=current_user.id, unread_only=unread_only
    )


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_as_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark a notification as read."""
    return notification_service.mark_as_read(
        db, notification_id=notification_id, user_id=current_user.id
    )


@router.post("/mark-all-read", response_model=MessageResponse)
def mark_all_notifications_as_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark all notifications for the authenticated user as read."""
    count = notification_service.mark_all_as_read(db, user_id=current_user.id)
    return MessageResponse(message=f"{count} notifications marked as read.")
