from typing import List
from sqlalchemy.orm import Session
from app.models.task_comment import TaskComment
from app.repositories.base import BaseRepository


class CommentRepository(BaseRepository[TaskComment]):
    def __init__(self):
        super().__init__(TaskComment)

    def get_by_task(self, db: Session, *, task_id: int) -> List[TaskComment]:
        return (
            db.query(TaskComment)
            .filter(TaskComment.task_id == task_id)
            .order_by(TaskComment.created_at.asc())
            .all()
        )


comment_repo = CommentRepository()
