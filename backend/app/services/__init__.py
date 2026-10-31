from app.services.auth_service import auth_service
from app.services.project_service import project_service
from app.services.task_service import task_service
from app.services.comment_service import comment_service
from app.services.notification_service import notification_service
from app.services.dashboard_service import dashboard_service

__all__ = [
    "auth_service",
    "project_service",
    "task_service",
    "comment_service",
    "notification_service",
    "dashboard_service",
]
