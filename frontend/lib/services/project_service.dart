import '../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/project_model.dart';
import 'api_client.dart';

class ProjectService {
  final ApiClient _apiClient;

  ProjectService(this._apiClient);

  Future<PaginatedResult<ProjectModel>> getProjects({
    String? search,
    ProjectStatus? status,
    ProjectPriority? priority,
    int page = 1,
    int pageSize = 10,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status != null) {
      params['status'] = status.toApiString();
    }
    if (priority != null) {
      params['priority'] = priority.toApiString();
    }

    final response = await _apiClient.get(ApiConstants.projects, queryParameters: params);
    return PaginatedResult.fromJson(
      response as Map<String, dynamic>,
      (item) => ProjectModel.fromJson(item),
    );
  }

  Future<ProjectModel> getProjectById(int id) async {
    final response = await _apiClient.get(ApiConstants.projectDetail(id));
    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProjectModel> createProject({
    required String title,
    String? description,
    ProjectStatus status = ProjectStatus.planning,
    ProjectPriority priority = ProjectPriority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    double budgetHours = 0.0,
    List<int>? memberIds,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'status': status.toApiString(),
      'priority': priority.toApiString(),
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'budget_hours': budgetHours,
      if (memberIds != null && memberIds.isNotEmpty) 'member_ids': memberIds,
    };

    final response = await _apiClient.post(ApiConstants.projects, body: body);
    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProjectModel> updateProject({
    required int id,
    String? title,
    String? description,
    ProjectStatus? status,
    ProjectPriority? priority,
    DateTime? startDate,
    DateTime? dueDate,
    double? budgetHours,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (status != null) body['status'] = status.toApiString();
    if (priority != null) body['priority'] = priority.toApiString();
    if (startDate != null) body['start_date'] = startDate.toIso8601String();
    if (dueDate != null) body['due_date'] = dueDate.toIso8601String();
    if (budgetHours != null) body['budget_hours'] = budgetHours;

    final response = await _apiClient.put(ApiConstants.projectDetail(id), body: body);
    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteProject(int id) async {
    await _apiClient.delete(ApiConstants.projectDetail(id));
  }

  Future<ProjectMemberModel> addMember({
    required int projectId,
    required int userId,
    String roleInProject = 'Member',
  }) async {
    final response = await _apiClient.post(
      ApiConstants.projectMembers(projectId),
      body: {
        'user_id': userId,
        'role_in_project': roleInProject,
      },
    );
    return ProjectMemberModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> removeMember({required int projectId, required int userId}) async {
    await _apiClient.delete(ApiConstants.removeMember(projectId, userId));
  }
}
