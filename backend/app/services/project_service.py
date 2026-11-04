from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.core.exceptions import EntityNotFoundException, PermissionDeniedException, ConflictException
from app.models.project import Project
from app.models.project_member import ProjectMember
from app.models.user import User
from app.models.enums import UserRole, ProjectStatus, ProjectPriority
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectResponse, ProjectDetailResponse, ProjectMemberCreate
from app.repositories.project_repository import project_repo
from app.repositories.user_repository import user_repo
from app.core.permissions import (
    is_admin,
    can_view_project,
    can_create_project,
    can_update_project,
    can_delete_project,
    can_manage_project_members
)


class ProjectService:
    def get_projects(
        self,
        db: Session,
        *,
        current_user: User,
        search: Optional[str] = None,
        status: Optional[ProjectStatus] = None,
        priority: Optional[ProjectPriority] = None,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[ProjectResponse], int]:
        # Only Admins view all projects across the company.
        # Project Managers, Employees, and Clients are strictly scoped to their assigned projects.
        user_filter_id = None if is_admin(current_user) else current_user.id

        projects, total = project_repo.filter_projects(
            db,
            search=search,
            status=status,
            priority=priority,
            user_id=user_filter_id,
            skip=skip,
            limit=limit
        )

        responses = []
        for p in projects:
            progress = project_repo.get_progress_data(db, p.id)
            res = ProjectResponse(
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
                client_id=getattr(p, "client_id", None),
                client=getattr(p, "client", None),
                tasks_count=progress["total_tasks"],
                completed_tasks_count=progress["completed_tasks"],
                progress_percentage=progress["progress_percentage"],
                members_count=progress["members_count"],
                created_at=p.created_at,
                updated_at=p.updated_at
            )
            responses.append(res)

        return responses, total

    def get_project_by_id(self, db: Session, *, project_id: int, current_user: User) -> ProjectDetailResponse:
        project = project_repo.get(db, id=project_id)
        if not project:
            raise EntityNotFoundException("Project", project_id)

        # Centralized RBAC validation to prevent IDOR
        if not can_view_project(current_user, project):
            raise PermissionDeniedException("You are not authorized to view this project.")

        progress = project_repo.get_progress_data(db, project.id)
        return ProjectDetailResponse(
            id=project.id,
            title=project.title,
            description=project.description,
            status=project.status,
            priority=project.priority,
            start_date=project.start_date,
            due_date=project.due_date,
            budget_hours=project.budget_hours,
            owner_id=project.owner_id,
            owner=project.owner,
            client_id=getattr(project, "client_id", None),
            client=getattr(project, "client", None),
            tasks_count=progress["total_tasks"],
            completed_tasks_count=progress["completed_tasks"],
            progress_percentage=progress["progress_percentage"],
            members_count=progress["members_count"],
            created_at=project.created_at,
            updated_at=project.updated_at,
            members=project.members
        )

    def create_project(self, db: Session, *, project_in: ProjectCreate, current_user: User) -> Project:
        if not can_create_project(current_user):
            raise PermissionDeniedException("Only Admins and Project Managers can create projects.")

        project_data = project_in.model_dump(exclude={"member_ids"})
        project_data["owner_id"] = current_user.id

        project = project_repo.create(db, obj_in=project_data)

        # Add initial members if provided
        if project_in.member_ids:
            for uid in set(project_in.member_ids):
                user = user_repo.get(db, id=uid)
                if user:
                    member = ProjectMember(
                        project_id=project.id,
                        user_id=user.id,
                        role_in_project="Lead" if user.id == current_user.id else "Member"
                    )
                    db.add(member)
            db.commit()
            db.refresh(project)

        return project

    def update_project(
        self, db: Session, *, project_id: int, project_in: ProjectUpdate, current_user: User
    ) -> Project:
        project = project_repo.get(db, id=project_id)
        if not project:
            raise EntityNotFoundException("Project", project_id)

        if not can_update_project(current_user, project):
            raise PermissionDeniedException("You do not have permission to edit this project.")

        update_data = project_in.model_dump(exclude_unset=True)
        if "owner_id" in update_data and update_data["owner_id"] is not None and update_data["owner_id"] != project.owner_id:
            if not is_admin(current_user):
                raise PermissionDeniedException("Only Admins can transfer project ownership.")
        return project_repo.update(db, db_obj=project, obj_in=update_data)

    def delete_project(self, db: Session, *, project_id: int, current_user: User) -> None:
        project = project_repo.get(db, id=project_id)
        if not project:
            raise EntityNotFoundException("Project", project_id)

        if not can_delete_project(current_user, project):
            raise PermissionDeniedException("Only Admins or the Project Owner can delete this project.")

        project_repo.remove(db, id=project_id)

    def add_member(
        self, db: Session, *, project_id: int, member_in: ProjectMemberCreate, current_user: User
    ) -> ProjectMember:
        project = project_repo.get(db, id=project_id)
        if not project:
            raise EntityNotFoundException("Project", project_id)

        if not can_manage_project_members(current_user, project):
            raise PermissionDeniedException("Permission denied to manage project members.")

        user = user_repo.get(db, id=member_in.user_id)
        if not user:
            raise EntityNotFoundException("User", member_in.user_id)

        existing = (
            db.query(ProjectMember)
            .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == member_in.user_id)
            .first()
        )
        if existing:
            raise ConflictException("User is already a member of this project.")

        member = ProjectMember(
            project_id=project_id,
            user_id=member_in.user_id,
            role_in_project=member_in.role_in_project
        )
        db.add(member)
        db.commit()
        db.refresh(member)
        return member

    def remove_member(
        self, db: Session, *, project_id: int, user_id: int, current_user: User
    ) -> None:
        project = project_repo.get(db, id=project_id)
        if not project:
            raise EntityNotFoundException("Project", project_id)

        if not can_manage_project_members(current_user, project):
            raise PermissionDeniedException("Permission denied to remove members.")

        member = (
            db.query(ProjectMember)
            .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == user_id)
            .first()
        )
        if not member:
            raise EntityNotFoundException("ProjectMember", f"Project {project_id}, User {user_id}")

        db.delete(member)
        db.commit()


project_service = ProjectService()
