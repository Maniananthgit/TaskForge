from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.user_audit_log import UserAuditLog
from app.core.logging import logger


class AuditService:
    @staticmethod
    def log_action(
        db: Session,
        *,
        actor_id: Optional[int],
        target_user_id: int,
        action: str,
        details: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None
    ) -> UserAuditLog:
        """Create an immutable administrative audit record."""
        # Sanitize details so passwords, tokens, or JWTs are never recorded
        sanitized_details = None
        if details:
            sanitized_details = {}
            for k, v in details.items():
                if any(secret_term in k.lower() for secret_term in ["password", "token", "hash", "secret"]):
                    sanitized_details[k] = "[REDACTED]"
                else:
                    sanitized_details[k] = v

        audit_entry = UserAuditLog(
            actor_id=actor_id,
            target_user_id=target_user_id,
            action=action,
            details=sanitized_details,
            ip_address=ip_address,
        )
        db.add(audit_entry)
        db.commit()
        db.refresh(audit_entry)
        logger.info(f"[Audit] Action '{action}' by actor {actor_id} on target user {target_user_id}")
        return audit_entry


audit_service = AuditService()
