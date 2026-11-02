import '../core/utils/network_utils.dart';
import '../models/api_response.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/project_service.dart';

class ProjectRepository {
  final ProjectService _projectService;

  ProjectRepository(this._projectService);

  bool _isNetworkFailure(dynamic error) => NetworkUtils.isNetworkOrHostFailure(error);

  final List<ProjectModel> _demoProjects = [
    ProjectModel(
      id: 1,
      title: 'Cloud Infrastructure & Kubernetes',
      description: 'Production cloud migration to AWS & GCP with container orchestration, Redis, and PostgreSQL clusters.',
      status: ProjectStatus.inProgress,
      priority: ProjectPriority.urgent,
      startDate: DateTime.now().subtract(const Duration(days: 20)),
      dueDate: DateTime.now().add(const Duration(days: 25)),
      budgetHours: 120.0,
      ownerId: 1,
      membersCount: 4,
      tasksCount: 8,
      completedTasksCount: 5,
      progressPercentage: 62.5,
    ),
    ProjectModel(
      id: 2,
      title: 'TaskForge Flutter Web App Redesign',
      description: 'Modern, responsive Flutter enterprise UI featuring MVVM state management and dark/light themes.',
      status: ProjectStatus.inProgress,
      priority: ProjectPriority.high,
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      dueDate: DateTime.now().add(const Duration(days: 15)),
      budgetHours: 80.0,
      ownerId: 2,
      membersCount: 3,
      tasksCount: 6,
      completedTasksCount: 2,
      progressPercentage: 33.3,
    ),
    ProjectModel(
      id: 3,
      title: 'PostgreSQL RBAC Security Hardening',
      description: 'Strict role-based access checks, JWT asymmetric token signing, and encryption at rest.',
      status: ProjectStatus.completed,
      priority: ProjectPriority.high,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      budgetHours: 40.0,
      ownerId: 1,
      membersCount: 2,
      tasksCount: 4,
      completedTasksCount: 4,
      progressPercentage: 100.0,
    ),
  ];

  Future<PaginatedResult<ProjectModel>> getProjects({
    String? search,
    ProjectStatus? status,
    ProjectPriority? priority,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      return await _projectService.getProjects(
        search: search,
        status: status,
        priority: priority,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        var items = List<ProjectModel>.from(_demoProjects);
        if (search != null && search.isNotEmpty) {
          items = items.where((p) => p.title.toLowerCase().contains(search.toLowerCase())).toList();
        }
        if (status != null) {
          items = items.where((p) => p.status == status).toList();
        }
        if (priority != null) {
          items = items.where((p) => p.priority == priority).toList();
        }
        return PaginatedResult(
          items: items,
          total: items.length,
          page: page,
          pageSize: pageSize,
          totalPages: 1,
        );
      }
      rethrow;
    }
  }

  Future<ProjectModel> getProjectById(int id) async {
    try {
      return await _projectService.getProjectById(id);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return _demoProjects.firstWhere(
          (p) => p.id == id,
          orElse: () => _demoProjects.first,
        );
      }
      rethrow;
    }
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
    try {
      return await _projectService.createProject(
        title: title,
        description: description,
        status: status,
        priority: priority,
        startDate: startDate,
        dueDate: dueDate,
        budgetHours: budgetHours,
        memberIds: memberIds,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final newProject = ProjectModel(
          id: _demoProjects.length + 1,
          title: title,
          description: description,
          status: status,
          priority: priority,
          startDate: startDate ?? DateTime.now(),
          dueDate: dueDate,
          budgetHours: budgetHours,
          ownerId: 1,
          membersCount: (memberIds?.length ?? 0) + 1,
          tasksCount: 0,
          completedTasksCount: 0,
          progressPercentage: 0.0,
        );
        _demoProjects.insert(0, newProject);
        return newProject;
      }
      rethrow;
    }
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
    try {
      return await _projectService.updateProject(
        id: id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        startDate: startDate,
        dueDate: dueDate,
        budgetHours: budgetHours,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return getProjectById(id);
      }
      rethrow;
    }
  }

  Future<void> deleteProject(int id) async {
    try {
      await _projectService.deleteProject(id);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        _demoProjects.removeWhere((p) => p.id == id);
        return;
      }
      rethrow;
    }
  }

  Future<ProjectMemberModel> addMember({
    required int projectId,
    required int userId,
    String roleInProject = 'Member',
  }) async {
    try {
      return await _projectService.addMember(
        projectId: projectId,
        userId: userId,
        roleInProject: roleInProject,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return ProjectMemberModel(
          id: 99,
          projectId: projectId,
          userId: userId,
          roleInProject: roleInProject,
          joinedAt: DateTime.now(),
          user: UserModel(
            id: userId,
            email: 'member@taskforge.internal',
            fullName: 'Team Member',
            role: UserRole.developer,
            isActive: true,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> removeMember({required int projectId, required int userId}) async {
    try {
      await _projectService.removeMember(projectId: projectId, userId: userId);
    } catch (e) {
      if (_isNetworkFailure(e)) return;
      rethrow;
    }
  }
}
