from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.schemas.user import UserResponse


class TaskHistoryResponse(BaseModel):
    id: int
    task_id: int
    changed_by_id: Optional[int] = None
    changed_by: Optional[UserResponse] = None
    field_changed: str
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    changed_at: datetime

    model_config = ConfigDict(from_attributes=True)
