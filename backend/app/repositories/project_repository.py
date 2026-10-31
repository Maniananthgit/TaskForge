from typing import Optional, List, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from app.models.project import Project
from app.models.project_member import ProjectMember
from app.models.task import Task
from app.models.enums import ProjectStatus, ProjectPriority, TaskStatus
from app.repositories.base import BaseRepository


class ProjectRepository(BaseRepository[Project]):
    def __init__(self):
        super().__init__(Project)

    def filter_projects(
        self,
        db: Session,
        *,
        search: Optional[str] = None,
        status: Optional[ProjectStatus] = None,
        priority: Optional[ProjectPriority] = None,
        user_id: Optional[int] = None,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[Project], int]:
        query = db.query(Project)

        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Project.title.ilike(search_pattern),
                    Project.description.ilike(search_pattern)
                )
            )

        if status:
            query = query.filter(Project.status == status)

        if priority:
            query = query.filter(Project.priority == priority)

        if user_id:
            # User is either owner or member
            member_project_ids = (
                db.query(ProjectMember.project_id)
                .filter(ProjectMember.user_id == user_id)
                .subquery()
            )
            query = query.filter(
                or_(
                    Project.owner_id == user_id,
                    Project.id.in_(member_project_ids)
                )
            )

        total = query.count()
        projects = query.order_by(Project.created_at.desc()).offset(skip).limit(limit).all()
        return projects, total

    def get_progress_data(self, db: Session, project_id: int) -> dict:
        total_tasks = db.query(Task).filter(Task.project_id == project_id).count()
        completed_tasks = (
            db.query(Task)
            .filter(Task.project_id == project_id, Task.status == TaskStatus.DONE)
            .count()
        )
        members_count = (
            db.query(ProjectMember).filter(ProjectMember.project_id == project_id).count()
        )
        percentage = round((completed_tasks / total_tasks * 100), 1) if total_tasks > 0 else 0.0

        return {
            "total_tasks": total_tasks,
            "completed_tasks": completed_tasks,
            "progress_percentage": percentage,
            "members_count": members_count
        }


project_repo = ProjectRepository()
