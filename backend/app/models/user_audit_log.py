from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON, func
from sqlalchemy.orm import relationship
from app.core.database import Base


class UserAuditLog(Base):
    __tablename__ = "user_audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    actor_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    action = Column(String(100), nullable=False, index=True)
    details = Column(JSON, nullable=True)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False, index=True)

    # Relationships
    actor = relationship("User", foreign_keys=[actor_id], back_populates="actions_performed")
    target_user = relationship("User", foreign_keys=[target_user_id], back_populates="audit_logs")
