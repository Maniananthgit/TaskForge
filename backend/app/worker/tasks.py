from datetime import datetime, timezone
from app.worker.celery_app import celery_app
from app.core.database import SessionLocal
from app.models.task import Task
from app.models.enums import TaskStatus
from app.services.notification_service import notification_service
from app.core.logging import logger


@celery_app.task(name="app.worker.tasks.send_notification_email")
def send_notification_email(recipient_email: str, subject: str, body: str) -> dict:
    """Asynchronous worker task to dispatch emails."""
    logger.info(f"[Celery] Sending notification email to {recipient_email}: {subject}")
    # Integration point with enterprise SMTP/AWS SES
    return {"status": "sent", "recipient": recipient_email, "subject": subject}


@celery_app.task(name="app.worker.tasks.check_overdue_tasks_job")
def check_overdue_tasks_job() -> dict:
    """Scheduled task to detect overdue items and trigger automated notifications."""
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        overdue_tasks = (
            db.query(Task)
            .filter(
                Task.due_date.isnot(None),
                Task.due_date < now,
                Task.status != TaskStatus.DONE
            )
            .all()
        )

        notified_count = 0
        for task in overdue_tasks:
            if task.assignee_id:
                notification_service.create_notification(
                    db,
                    user_id=task.assignee_id,
                    title="Task Overdue Warning",
                    message=f"Task '{task.title}' was due on {task.due_date.strftime('%Y-%m-%d')}.",
                    notification_type="deadline_approaching",
                    link_url=f"/tasks/{task.id}"
                )
                notified_count += 1

        logger.info(f"[Celery] Overdue task scan completed. Processed {notified_count} notifications.")
        return {"overdue_found": len(overdue_tasks), "notified": notified_count}
    finally:
        db.close()
