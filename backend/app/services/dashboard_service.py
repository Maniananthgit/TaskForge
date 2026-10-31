from datetime import datetime, timezone
from typing import List
from sqlalchemy.orm import Session
from sqlalchemy import and_
from app.models.project import Project
from app.models.task import Task
from app.models.user import User
from app.models.enums import TaskStatus, TaskPriority, ProjectStatus, UserRole
from app.schemas.dashboard import (
    DashboardMetricsResponse,
    ProjectProgressMetric,
    StatusCountMetric,
    PriorityCountMetric
)
from app.schemas.project import ProjectResponse
from app.schemas.task import TaskResponse
from app.repositories.project_repository import project_repo


def is_overdue(due_date, status) -> bool:
    if not due_date or status == TaskStatus.DONE:
        return False
    now = datetime.now(timezone.utc)
    target = due_date.replace(tzinfo=timezone.utc) if due_date.tzinfo is None else due_date
    return target < now


class DashboardService:
    def get_metrics(self, db: Session, *, current_user: User) -> DashboardMetricsResponse:

        # Total projects query (if Developer, filter to relevant projects)
        if current_user.role in [UserRole.ADMIN, UserRole.PROJECT_MANAGER]:
            all_projects = db.query(Project).all()
            all_tasks = db.query(Task).all()
        else:
            projects_data, _ = project_repo.filter_projects(db, user_id=current_user.id, limit=500)
            all_projects = projects_data
            project_ids = [p.id for p in all_projects]
            all_tasks = db.query(Task).filter(Task.project_id.in_(project_ids)).all() if project_ids else []

        total_projects = len(all_projects)
        total_tasks = len(all_tasks)
        active_tasks = sum(1 for t in all_tasks if t.status in [TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.IN_REVIEW])
        completed_tasks = sum(1 for t in all_tasks if t.status == TaskStatus.DONE)
        overdue_tasks = sum(1 for t in all_tasks if is_overdue(t.due_date, t.status))

        # Personal metrics
        my_tasks = [t for t in all_tasks if t.assignee_id == current_user.id]
        my_tasks_count = len(my_tasks)
        my_completed = sum(1 for t in my_tasks if t.status == TaskStatus.DONE)
        my_overdue = sum(1 for t in my_tasks if is_overdue(t.due_date, t.status))

        # Project progress
        progress_metrics: List[ProjectProgressMetric] = []
        for p in all_projects[:10]:
            p_tasks = [t for t in all_tasks if t.project_id == p.id]
            p_total = len(p_tasks)
            p_completed = sum(1 for t in p_tasks if t.status == TaskStatus.DONE)
            p_percent = round((p_completed / p_total * 100), 1) if p_total > 0 else 0.0

            progress_metrics.append(
                ProjectProgressMetric(
                    project_id=p.id,
                    project_title=p.title,
                    total_tasks=p_total,
                    completed_tasks=p_completed,
                    progress_percentage=p_percent,
                    status=p.status.value if hasattr(p.status, 'value') else str(p.status),
                    due_date=p.due_date.isoformat() if p.due_date else None
                )
            )

        # Tasks by status
        status_counts = []
        for s in TaskStatus:
            count = sum(1 for t in all_tasks if t.status == s)
            status_counts.append(StatusCountMetric(status=s.value, count=count))

        # Tasks by priority
        priority_counts = []
        for pr in TaskPriority:
            count = sum(1 for t in all_tasks if t.priority == pr)
            priority_counts.append(PriorityCountMetric(priority=pr.value, count=count))

        # Recent tasks
        recent_tasks = sorted(all_tasks, key=lambda x: x.created_at, reverse=True)[:5]
        recent_task_responses = [
            TaskResponse(
                id=t.id,
                project_id=t.project_id,
                title=t.title,
                description=t.description,
                status=t.status,
                priority=t.priority,
                due_date=t.due_date,
                estimated_hours=t.estimated_hours,
                actual_hours=t.actual_hours,
                creator_id=t.creator_id,
                creator=t.creator,
                assignee_id=t.assignee_id,
                assignee=t.assignee,
                is_overdue=is_overdue(t.due_date, t.status),
                comments_count=len(t.comments) if t.comments else 0,
                created_at=t.created_at,
                updated_at=t.updated_at
            )
            for t in recent_tasks
        ]

        # Recent projects
        recent_projects = sorted(all_projects, key=lambda x: x.created_at, reverse=True)[:5]
        recent_project_responses = [
            ProjectResponse(
                id=p.id,
                title=p.title,
                description=p.description,
                status=p.status,
                priority=p.priority,
                start_date=p.start_date,
                due_date=p.due_date,
                budget_hours=p.budget_hours,
                owner_id=p.owner_id,
                owner=p.owner,
                tasks_count=len([t for t in all_tasks if t.project_id == p.id]),
                completed_tasks_count=len([t for t in all_tasks if t.project_id == p.id and t.status == TaskStatus.DONE]),
                progress_percentage=round((len([t for t in all_tasks if t.project_id == p.id and t.status == TaskStatus.DONE]) / len([t for t in all_tasks if t.project_id == p.id]) * 100), 1) if [t for t in all_tasks if t.project_id == p.id] else 0.0,
                members_count=len(p.members) if p.members else 0,
                created_at=p.created_at,
                updated_at=p.updated_at
            )
            for p in recent_projects
        ]

        return DashboardMetricsResponse(
            total_projects=total_projects,
            total_tasks=total_tasks,
            active_tasks=active_tasks,
            completed_tasks=completed_tasks,
            overdue_tasks=overdue_tasks,
            my_tasks_count=my_tasks_count,
            my_completed_tasks_count=my_completed,
            my_overdue_tasks_count=my_overdue,
            project_progress=progress_metrics,
            tasks_by_status=status_counts,
            tasks_by_priority=priority_counts,
            recent_tasks=recent_task_responses,
            recent_projects=recent_project_responses
        )


dashboard_service = DashboardService()
