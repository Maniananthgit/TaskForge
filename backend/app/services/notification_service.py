from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.notification import Notification
from app.repositories.notification_repository import notification_repo
from app.core.logging import logger


class NotificationService:
    def create_notification(
        self,
        db: Session,
        *,
        user_id: int,
        title: str,
        message: str,
        notification_type: str = "info",
        link_url: Optional[str] = None
    ) -> Notification:
        notif = notification_repo.create(
            db,
            obj_in={
                "user_id": user_id,
                "title": title,
                "message": message,
                "notification_type": notification_type,
                "link_url": link_url,
                "is_read": False
            }
        )
        logger.info(f"Notification sent to user {user_id}: {title}")
        return notif

    def get_user_notifications(
        self, db: Session, *, user_id: int, unread_only: bool = False
    ) -> List[Notification]:
        return notification_repo.get_by_user(db, user_id=user_id, unread_only=unread_only)

    def mark_as_read(self, db: Session, *, notification_id: int, user_id: int) -> Notification:
        notif = notification_repo.get(db, id=notification_id)
        if notif and notif.user_id == user_id:
            notif.is_read = True
            db.add(notif)
            db.commit()
            db.refresh(notif)
        return notif

    def mark_all_as_read(self, db: Session, *, user_id: int) -> int:
        return notification_repo.mark_all_as_read(db, user_id=user_id)


notification_service = NotificationService()
