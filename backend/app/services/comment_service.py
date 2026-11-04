from typing import List
from sqlalchemy.orm import Session
from app.core.exceptions import EntityNotFoundException, PermissionDeniedException
from app.models.task_comment import TaskComment
from app.models.user import User
from app.models.enums import UserRole
from app.schemas.comment import CommentCreate
from app.repositories.comment_repository import comment_repo
from app.repositories.task_repository import task_repo
from app.services.notification_service import notification_service
from app.core.permissions import (
    is_client,
    can_view_task,
    can_create_comment,
    can_delete_comment
)


class CommentService:
    def get_comments(
        self, db: Session, *, task_id: int, current_user: User
    ) -> List[TaskComment]:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        if not can_view_task(current_user, task):
            raise PermissionDeniedException("You are not authorized to view comments for this task.")

        client_visible_only = is_client(current_user)
        return comment_repo.get_by_task(db, task_id=task_id, client_visible_only=client_visible_only)

    def add_comment(
        self, db: Session, *, task_id: int, comment_in: CommentCreate, current_user: User
    ) -> TaskComment:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        # Clients cannot post internal comments
        if not can_create_comment(current_user, task, is_internal=comment_in.is_internal):
            raise PermissionDeniedException(
                "You do not have permission to comment on this task or clients cannot post internal comments."
            )

        # Enforce that clients can never create internal comments even if payload sets True
        is_internal = False if is_client(current_user) else comment_in.is_internal

        comment_data = {
            "task_id": task_id,
            "author_id": current_user.id,
            "content": comment_in.content,
            "is_internal": is_internal
        }
        comment = comment_repo.create(db, obj_in=comment_data)

        # Notify assignee or creator about the new comment (only if internal comment is not notifying client)
        targets = {task.creator_id, task.assignee_id} - {current_user.id, None}
        for uid in targets:
            notification_service.create_notification(
                db,
                user_id=uid,
                title="New Comment on Task",
                message=f"{current_user.full_name} commented on '{task.title}': {comment_in.content[:60]}...",
                notification_type="comment_added",
                link_url=f"/tasks/{task.id}"
            )

        return comment

    def delete_comment(
        self, db: Session, *, comment_id: int, current_user: User
    ) -> None:
        comment = comment_repo.get(db, id=comment_id)
        if not comment:
            raise EntityNotFoundException("Comment", comment_id)

        if not can_delete_comment(current_user, comment):
            raise PermissionDeniedException("You can only delete your own comments.")

        comment_repo.remove(db, id=comment_id)


comment_service = CommentService()
