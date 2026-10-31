from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.schemas.project import ProjectResponse
from app.schemas.task import TaskResponse


class ProjectProgressMetric(BaseModel):
    project_id: int
    project_title: str
    total_tasks: int
    completed_tasks: int
    progress_percentage: float
    status: str
    due_date: Optional[str] = None


class StatusCountMetric(BaseModel):
    status: str
    count: int


class PriorityCountMetric(BaseModel):
    priority: str
    count: int


class DashboardMetricsResponse(BaseModel):
    total_projects: int
    total_tasks: int
    active_tasks: int
    completed_tasks: int
    overdue_tasks: int
    my_tasks_count: int
    my_completed_tasks_count: int
    my_overdue_tasks_count: int
    project_progress: List[ProjectProgressMetric]
    tasks_by_status: List[StatusCountMetric]
    tasks_by_priority: List[PriorityCountMetric]
    recent_tasks: List[TaskResponse] = []
    recent_projects: List[ProjectResponse] = []
