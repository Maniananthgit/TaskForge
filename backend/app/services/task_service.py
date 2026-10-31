from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.core.exceptions import EntityNotFoundException, PermissionDeniedException
from app.models.task import Task
from app.models.project import Project
from app.models.user import User
from app.models.enums import UserRole, TaskStatus, TaskPriority
from app.schemas.task import TaskCreate, TaskUpdate, TaskStatusUpdate, TaskResponse, TaskDetailResponse
from app.repositories.task_repository import task_repo
from app.repositories.project_repository import project_repo
from app.repositories.user_repository import user_repo
from app.services.notification_service import notification_service


def is_overdue_check(due_date: Optional[datetime], status: TaskStatus) -> bool:
    if not due_date or status == TaskStatus.DONE:
        return False
    now = datetime.now(timezone.utc)
    target = due_date.replace(tzinfo=timezone.utc) if due_date.tzinfo is None else due_date
    return target < now


class TaskService:
    def _to_response(self, task: Task) -> TaskResponse:
        is_overdue = is_overdue_check(task.due_date, task.status)
        comments_count = len(task.comments) if task.comments else 0

        return TaskResponse(
            id=task.id,
            project_id=task.project_id,
            title=task.title,
            description=task.description,
            status=task.status,
            priority=task.priority,
            due_date=task.due_date,
            estimated_hours=task.estimated_hours,
            actual_hours=task.actual_hours,
            creator_id=task.creator_id,
            creator=task.creator,
            assignee_id=task.assignee_id,
            assignee=task.assignee,
            is_overdue=is_overdue,
            comments_count=comments_count,
            created_at=task.created_at,
            updated_at=task.updated_at
        )

    def get_tasks(
        self,
        db: Session,
        *,
        current_user: User,
        project_id: Optional[int] = None,
        assignee_id: Optional[int] = None,
        status: Optional[TaskStatus] = None,
        priority: Optional[TaskPriority] = None,
        search: Optional[str] = None,
        overdue_only: bool = False,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[TaskResponse], int]:
        tasks, total = task_repo.filter_tasks(
            db,
            project_id=project_id,
            assignee_id=assignee_id,
            status=status,
            priority=priority,
            search=search,
            overdue_only=overdue_only,
            skip=skip,
            limit=limit
        )

        responses = [self._to_response(t) for t in tasks]
        return responses, total

    def get_task_by_id(self, db: Session, *, task_id: int, current_user: User) -> TaskDetailResponse:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        base_res = self._to_response(task)
        return TaskDetailResponse(
            **base_res.model_dump(),
            comments=task.comments,
            history=task.history
        )

    def create_task(self, db: Session, *, task_in: TaskCreate, current_user: User) -> Task:
        project = project_repo.get(db, id=task_in.project_id)
        if not project:
            raise EntityNotFoundException("Project", task_in.project_id)

        task_data = task_in.model_dump()
        task_data["creator_id"] = current_user.id

        task = task_repo.create(db, obj_in=task_data)

        # Audit history
        task_repo.log_change(
            db,
            task_id=task.id,
            changed_by_id=current_user.id,
            field_changed="creation",
            old_value=None,
            new_value=f"Created task '{task.title}'"
        )

        # Trigger notification if assigned
        if task.assignee_id and task.assignee_id != current_user.id:
            notification_service.create_notification(
                db,
                user_id=task.assignee_id,
                title="New Task Assigned",
                message=f"You have been assigned to task: '{task.title}' in project '{project.title}'",
                notification_type="task_assigned",
                link_url=f"/tasks/{task.id}"
            )

        return task

    def update_task(
        self, db: Session, *, task_id: int, task_in: TaskUpdate, current_user: User
    ) -> Task:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        update_data = task_in.model_dump(exclude_unset=True)

        # Log specific field changes
        for field, new_val in update_data.items():
            old_val = getattr(task, field, None)
            if str(old_val) != str(new_val):
                task_repo.log_change(
                    db,
                    task_id=task.id,
                    changed_by_id=current_user.id,
                    field_changed=field,
                    old_value=str(old_val) if old_val is not None else None,
                    new_value=str(new_val) if new_val is not None else None
                )

                # Assignee change notification
                if field == "assignee_id" and new_val and new_val != current_user.id:
                    notification_service.create_notification(
                        db,
                        user_id=new_val,
                        title="Task Reassigned",
                        message=f"You have been assigned to task '{task.title}'",
                        notification_type="task_assigned",
                        link_url=f"/tasks/{task.id}"
                    )

        updated_task = task_repo.update(db, db_obj=task, obj_in=update_data)
        return updated_task

    def update_status(
        self, db: Session, *, task_id: int, status_in: TaskStatusUpdate, current_user: User
    ) -> Task:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        old_status = task.status
        new_status = status_in.status

        if old_status != new_status:
            task.status = new_status
            db.add(task)
            db.commit()
            db.refresh(task)

            task_repo.log_change(
                db,
                task_id=task.id,
                changed_by_id=current_user.id,
                field_changed="status",
                old_value=old_status.value if hasattr(old_status, 'value') else str(old_status),
                new_value=new_status.value if hasattr(new_status, 'value') else str(new_status)
            )

            # Notify creator or assignee
            recipient_id = task.creator_id if current_user.id != task.creator_id else task.assignee_id
            if recipient_id and recipient_id != current_user.id:
                notification_service.create_notification(
                    db,
                    user_id=recipient_id,
                    title="Task Status Updated",
                    message=f"Task '{task.title}' moved to {new_status.value}",
                    notification_type="status_changed",
                    link_url=f"/tasks/{task.id}"
                )

        return task

    def delete_task(self, db: Session, *, task_id: int, current_user: User) -> None:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        if current_user.role == UserRole.DEVELOPER and task.creator_id != current_user.id:
            raise PermissionDeniedException("Only the Task Creator, Project Manager, or Admin can delete this task.")

        task_repo.remove(db, id=task_id)


task_service = TaskService()
