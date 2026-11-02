import '../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/task_model.dart';
import 'api_client.dart';

class TaskService {
  final ApiClient _apiClient;

  TaskService(this._apiClient);

  Future<PaginatedResult<TaskModel>> getTasks({
    int? projectId,
    int? assigneeId,
    TaskStatus? status,
    TaskPriority? priority,
    String? search,
    bool overdueOnly = false,
    int page = 1,
    int pageSize = 10,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'overdue_only': overdueOnly,
    };
    if (projectId != null) params['project_id'] = projectId;
    if (assigneeId != null) params['assignee_id'] = assigneeId;
    if (status != null) params['status'] = status.toApiString();
    if (priority != null) params['priority'] = priority.toApiString();
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

    final response = await _apiClient.get(ApiConstants.tasks, queryParameters: params);
    return PaginatedResult.fromJson(
      response as Map<String, dynamic>,
      (item) => TaskModel.fromJson(item),
    );
  }

  Future<TaskModel> getTaskById(int id) async {
    final response = await _apiClient.get(ApiConstants.taskDetail(id));
    return TaskModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TaskModel> createTask({
    required int projectId,
    required String title,
    String? description,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    double estimatedHours = 0.0,
    int? assigneeId,
  }) async {
    final body = {
      'project_id': projectId,
      'title': title,
      'description': description,
      'status': status.toApiString(),
      'priority': priority.toApiString(),
      'due_date': dueDate?.toIso8601String(),
      'estimated_hours': estimatedHours,
      'assignee_id': assigneeId,
    };

    final response = await _apiClient.post(ApiConstants.tasks, body: body);
    return TaskModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TaskModel> updateTask({
    required int id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    double? estimatedHours,
    double? actualHours,
    int? assigneeId,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (status != null) body['status'] = status.toApiString();
    if (priority != null) body['priority'] = priority.toApiString();
    if (dueDate != null) body['due_date'] = dueDate.toIso8601String();
    if (estimatedHours != null) body['estimated_hours'] = estimatedHours;
    if (actualHours != null) body['actual_hours'] = actualHours;
    if (assigneeId != null) body['assignee_id'] = assigneeId;

    final response = await _apiClient.put(ApiConstants.taskDetail(id), body: body);
    return TaskModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TaskModel> updateStatus({required int id, required TaskStatus status}) async {
    final response = await _apiClient.patch(
      ApiConstants.taskStatus(id),
      body: {'status': status.toApiString()},
    );
    return TaskModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteTask(int id) async {
    await _apiClient.delete(ApiConstants.taskDetail(id));
  }
}
