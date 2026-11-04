"""Centralized Authorization & Permission Matrix for TaskForge.

Four-Role Matrix:
1. ADMIN:
   - Full system access.
   - Manage all users, assign roles, manage system settings.
   - View, create, update, delete all projects and project members.
   - View, create, update, delete all tasks.
   - View public and internal comments.

2. PROJECT MANAGER:
   - View only assigned/owned projects.
   - Create projects.
   - Update and manage members for assigned projects.
   - Create, update, assign, and delete tasks within authorized projects.
   - View public and internal comments within authorized projects.
   - Cannot tamper with unassigned projects or users outside their scope.

3. EMPLOYEE (and legacy DEVELOPER):
   - View assigned projects (where user is a member or owner).
   - View tasks within assigned projects.
   - Update task status for assigned tasks.
   - Add task comments and submit progress updates.
   - View internal and public comments on authorized tasks.
   - Cannot create projects, reassign tasks across projects, or delete projects.

4. CLIENT:
   - View only authorized projects (where user is designated client_id or member).
   - View client-visible tasks (task.is_client_visible == True).
   - View only public comments (comment.is_internal == False).
   - Post public comments/feedback on authorized tasks.
   - Strictly forbidden from viewing internal comments, internal tasks, or company settings.
"""

from typing import List, Optional
from app.models.user import User
from app.models.project import Project
from app.models.task import Task
from app.models.task_comment import TaskComment
from app.models.enums import UserRole
from app.core.exceptions import PermissionDeniedException


def is_admin(user: User) -> bool:
    return user.role == UserRole.ADMIN


def is_pm(user: User) -> bool:
    return user.role in [UserRole.ADMIN, UserRole.PROJECT_MANAGER]


def is_employee(user: User) -> bool:
    return user.role in [UserRole.EMPLOYEE, UserRole.DEVELOPER]


def is_client(user: User) -> bool:
    return user.role == UserRole.CLIENT


# =========================================================================
# Project Permissions
# =========================================================================

def can_view_project(user: User, project: Project) -> bool:
    """Validate whether user has permission to view the project."""
    if is_admin(user):
        return True

    # Project owner
    if project.owner_id == user.id:
        return True

    # Designated client
    if getattr(project, "client_id", None) == user.id:
        return True

    # Project member check
    if any(m.user_id == user.id for m in project.members):
        return True

    return False


def can_create_project(user: User) -> bool:
    """Only Admins and Project Managers can create projects."""
    return user.role in [UserRole.ADMIN, UserRole.PROJECT_MANAGER]


def can_update_project(user: User, project: Project) -> bool:
    """Admin or Project Owner can update project details."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER and project.owner_id == user.id:
        return True
    return False


def can_delete_project(user: User, project: Project) -> bool:
    """Only Admins or Project Owner (PM) can delete a project."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER and project.owner_id == user.id:
        return True
    return False


def can_manage_project_members(user: User, project: Project) -> bool:
    """Only Admins or assigned Project Managers (owner/member) can manage team."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER:
        return project.owner_id == user.id or any(m.user_id == user.id for m in project.members)
    return False


# =========================================================================
# Task Permissions
# =========================================================================

def can_view_task(user: User, task: Task) -> bool:
    """User must have project access, and if Client, task must be client-visible."""
    if not can_view_project(user, task.project):
        return False

    if is_client(user):
        return getattr(task, "is_client_visible", True)

    return True


def can_create_task(user: User, project: Project) -> bool:
    """Admins and assigned Project Managers can create tasks in the project."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER:
        return project.owner_id == user.id or any(m.user_id == user.id for m in project.members)
    return False


def can_update_task(user: User, task: Task) -> bool:
    """Admins and assigned Project Managers can edit task properties."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER:
        return task.project.owner_id == user.id or any(m.user_id == user.id for m in task.project.members)
    return False


def can_update_task_status(user: User, task: Task) -> bool:
    """Admins, assigned PMs, or assigned Employees can update task status."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER:
        return task.project.owner_id == user.id or any(m.user_id == user.id for m in task.project.members)
    if is_employee(user):
        return task.assignee_id == user.id or task.creator_id == user.id
    return False


def can_delete_task(user: User, task: Task) -> bool:
    """Admins and assigned PMs can delete tasks."""
    if is_admin(user):
        return True
    if user.role == UserRole.PROJECT_MANAGER:
        return task.project.owner_id == user.id or any(m.user_id == user.id for m in task.project.members)
    if is_employee(user):
        # Employees may only delete tasks they personally created in the project
        return task.creator_id == user.id
    return False


# =========================================================================
# Comment Permissions
# =========================================================================

def can_view_comment(user: User, comment: TaskComment, task: Task) -> bool:
    """Clients cannot view internal comments; user must have task view access."""
    if not can_view_task(user, task):
        return False
    if is_client(user) and getattr(comment, "is_internal", False):
        return False
    return True


def can_create_comment(user: User, task: Task, is_internal: bool = False) -> bool:
    """Clients cannot post internal comments, only public comments on authorized tasks."""
    if not can_view_task(user, task):
        return False
    if is_client(user) and is_internal:
        return False
    return True


def can_delete_comment(user: User, comment: TaskComment) -> bool:
    """Only Admins or comment authors can delete comments."""
    if is_admin(user):
        return True
    return comment.author_id == user.id
