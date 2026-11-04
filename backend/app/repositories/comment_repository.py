from typing import List
from sqlalchemy.orm import Session
from app.models.task_comment import TaskComment
from app.repositories.base import BaseRepository


class CommentRepository(BaseRepository[TaskComment]):
    def __init__(self):
        super().__init__(TaskComment)

    def get_by_task(self, db: Session, *, task_id: int, client_visible_only: bool = False) -> List[TaskComment]:
        query = db.query(TaskComment).filter(TaskComment.task_id == task_id)
        if client_visible_only:
            query = query.filter(TaskComment.is_internal.is_(False))
        return (
            query
            .order_by(TaskComment.created_at.asc())
            .all()
        )


comment_repo = CommentRepository()
