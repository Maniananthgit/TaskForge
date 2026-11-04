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
from app.core.permissions import (
    is_admin,
    is_client,
    can_view_project,
    can_view_task,
    can_create_task,
    can_update_task,
    can_update_task_status,
    can_delete_task,
    can_view_comment
)


def is_overdue_check(due_date: Optional[datetime], status: TaskStatus) -> bool:
    if not due_date or status == TaskStatus.DONE:
        return False
    now = datetime.now(timezone.utc)
    target = due_date.replace(tzinfo=timezone.utc) if due_date.tzinfo is None else due_date
    return target < now


class TaskService:
    def _to_response(self, task: Task, current_user: Optional[User] = None) -> TaskResponse:
        is_overdue = is_overdue_check(task.due_date, task.status)
        
        # If client, count only client-visible comments
        if current_user and is_client(current_user):
            visible_comments = [c for c in (task.comments or []) if not getattr(c, "is_internal", False)]
            comments_count = len(visible_comments)
        else:
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
            is_client_visible=getattr(task, "is_client_visible", True),
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
        allowed_project_ids = None
        client_visible_only = False

        if not is_admin(current_user):
            # Restrict to projects the current user has access to
            accessible_projects, _ = project_repo.filter_projects(
                db, user_id=current_user.id, limit=10000
            )
            allowed_project_ids = [p.id for p in accessible_projects]

            if is_client(current_user):
                client_visible_only = True

            # If user explicitly requested a project_id they cannot access, return empty
            if project_id and project_id not in allowed_project_ids:
                return [], 0

        tasks, total = task_repo.filter_tasks(
            db,
            project_id=project_id,
            assignee_id=assignee_id,
            status=status,
            priority=priority,
            search=search,
            overdue_only=overdue_only,
            allowed_project_ids=allowed_project_ids,
            client_visible_only=client_visible_only,
            skip=skip,
            limit=limit
        )

        responses = [self._to_response(t, current_user=current_user) for t in tasks]
        return responses, total

    def get_task_by_id(self, db: Session, *, task_id: int, current_user: User) -> TaskDetailResponse:
        task = task_repo.get(db, id=task_id)
        if not task:
            raise EntityNotFoundException("Task", task_id)

        # IDOR prevention: Validate user has access to this task and project
        if not can_view_task(current_user, task):
            raise PermissionDeniedException("You are not authorized to view this task.")

        base_res = self._to_response(task, current_user=current_user)

        # Filter comments for client isolation
        raw_comments = task.comments or []
        if is_client(current_user):
            filtered_comments = [c for c in raw_comments if not getattr(c, "is_internal", False)]
        else:
            filtered_comments = raw_comments

        return TaskDetailResponse(
            **base_res.model_dump(),
            comments=filtered_comments,
            history=task.history or []
        )

    def create_task(self, db: Session, *, task_in: TaskCreate, current_user: User) -> Task:
        project = project_repo.get(db, id=task_in.project_id)
        if not project:
            raise EntityNotFoundException("Project", task_in.project_id)

        # Validate permission
        if not can_create_task(current_user, project):
            raise PermissionDeniedException("You do not have permission to create tasks in this project.")

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

        # Validate permission
        if not can_update_task(current_user, task):
            raise PermissionDeniedException("You do not have permission to edit this task.")

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

        # Validate permission
        if not can_update_task_status(current_user, task):
            raise PermissionDeniedException("You are not authorized to update the status of this task.")

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

        if not can_delete_task(current_user, task):
            raise PermissionDeniedException("You do not have permission to delete this task.")

        task_repo.remove(db, id=task_id)


task_service = TaskService()
