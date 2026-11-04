from datetime import datetime, timezone
from typing import Optional, List, Tuple
from sqlalchemy.orm import Session, joinedload, selectinload
from sqlalchemy import or_, and_
from app.models.task import Task
from app.models.task_history import TaskHistory
from app.models.enums import TaskStatus, TaskPriority
from app.repositories.base import BaseRepository


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TaskRepository(BaseRepository[Task]):
    def __init__(self):
        super().__init__(Task)

    def filter_tasks(
        self,
        db: Session,
        *,
        project_id: Optional[int] = None,
        assignee_id: Optional[int] = None,
        status: Optional[TaskStatus] = None,
        priority: Optional[TaskPriority] = None,
        search: Optional[str] = None,
        overdue_only: bool = False,
        allowed_project_ids: Optional[List[int]] = None,
        client_visible_only: bool = False,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[Task], int]:
        query = db.query(Task)

        if allowed_project_ids is not None:
            query = query.filter(Task.project_id.in_(allowed_project_ids))

        if client_visible_only:
            query = query.filter(Task.is_client_visible.is_(True))

        if project_id:
            query = query.filter(Task.project_id == project_id)

        if assignee_id:
            query = query.filter(Task.assignee_id == assignee_id)

        if status:
            query = query.filter(Task.status == status)

        if priority:
            query = query.filter(Task.priority == priority)

        if overdue_only:
            now = utcnow()
            query = query.filter(
                and_(
                    Task.due_date.isnot(None),
                    Task.due_date < now,
                    Task.status != TaskStatus.DONE
                )
            )

        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Task.title.ilike(search_pattern),
                    Task.description.ilike(search_pattern)
                )
            )

        total = query.count()
        tasks = (
            query.options(
                joinedload(Task.assignee),
                joinedload(Task.creator),
                selectinload(Task.comments)
            )
            .order_by(Task.due_date.asc().nullslast(), Task.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )
        return tasks, total

    def log_change(
        self,
        db: Session,
        *,
        task_id: int,
        changed_by_id: int,
        field_changed: str,
        old_value: Optional[str],
        new_value: Optional[str]
    ) -> TaskHistory:
        history_entry = TaskHistory(
            task_id=task_id,
            changed_by_id=changed_by_id,
            field_changed=field_changed,
            old_value=str(old_value) if old_value is not None else None,
            new_value=str(new_value) if new_value is not None else None,
            changed_at=utcnow()
        )
        db.add(history_entry)
        db.commit()
        db.refresh(history_entry)
        return history_entry


task_repo = TaskRepository()
