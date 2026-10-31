from celery import Celery
from app.core.config import settings

celery_app = Celery(
    "taskforge_worker",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.worker.tasks"]
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=300,
    beat_schedule={
        "check-overdue-tasks-hourly": {
            "task": "app.worker.tasks.check_overdue_tasks_job",
            "schedule": 3600.0,  # every hour
        },
    }
)
