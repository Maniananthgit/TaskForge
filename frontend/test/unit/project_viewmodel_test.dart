import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge_app/models/api_response.dart';
import 'package:taskforge_app/models/project_model.dart';
import 'package:taskforge_app/models/user_model.dart';
import 'package:taskforge_app/repositories/project_repository.dart';
import 'package:taskforge_app/services/user_service.dart';
import 'package:taskforge_app/viewmodels/project_viewmodel.dart';

class MockProjectRepository implements ProjectRepository {
  List<ProjectModel> projects = [];

  @override
  Future<PaginatedResult<ProjectModel>> getProjects({
    String? search,
    ProjectStatus? status,
    ProjectPriority? priority,
    int page = 1,
    int pageSize = 10,
  }) async {
    var filtered = projects;
    if (status != null) {
      filtered = filtered.where((p) => p.status == status).toList();
    }
    return PaginatedResult(
      items: filtered,
      total: filtered.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<ProjectModel> getProjectById(int id) async {
    return projects.firstWhere((p) => p.id == id);
  }

  @override
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
    final newP = ProjectModel(
      id: projects.length + 1,
      title: title,
      description: description,
      status: status,
      priority: priority,
      startDate: startDate,
      dueDate: dueDate,
      budgetHours: budgetHours,
      ownerId: 1,
    );
    projects.add(newP);
    return newP;
  }

  @override
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
    final idx = projects.indexWhere((p) => p.id == id);
    final updated = ProjectModel(
      id: id,
      title: title ?? projects[idx].title,
      description: description ?? projects[idx].description,
      status: status ?? projects[idx].status,
      priority: priority ?? projects[idx].priority,
      budgetHours: budgetHours ?? projects[idx].budgetHours,
      ownerId: projects[idx].ownerId,
    );
    projects[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteProject(int id) async {
    projects.removeWhere((p) => p.id == id);
  }

  @override
  Future<ProjectMemberModel> addMember({
    required int projectId,
    required int userId,
    String roleInProject = 'Member',
  }) async {
    return ProjectMemberModel(
      id: 1,
      projectId: projectId,
      userId: userId,
      roleInProject: roleInProject,
    );
  }

  @override
  Future<void> removeMember({required int projectId, required int userId}) async {}
}

class MockUserService implements UserService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<UserModel>> getUsers({String? query, UserRole? role}) async {
    return [
      UserModel(id: 1, email: 'admin@taskforge.internal', fullName: 'Admin', role: UserRole.admin),
      UserModel(id: 2, email: 'dev@taskforge.internal', fullName: 'Developer', role: UserRole.developer),
    ];
  }
}

void main() {
  group('ProjectViewModel Unit Tests', () {
    late MockProjectRepository mockProjectRepo;
    late MockUserService mockUserService;
    late ProjectViewModel viewModel;

    setUp(() {
      mockProjectRepo = MockProjectRepository();
      mockUserService = MockUserService();

      mockProjectRepo.projects = [
        ProjectModel(
          id: 1,
          title: 'Infrastructure Migration',
          status: ProjectStatus.inProgress,
          priority: ProjectPriority.urgent,
          ownerId: 1,
        ),
        ProjectModel(
          id: 2,
          title: 'Flutter Mobile App',
          status: ProjectStatus.planning,
          priority: ProjectPriority.high,
          ownerId: 1,
        ),
      ];

      viewModel = ProjectViewModel(mockProjectRepo, mockUserService);
    });

    test('fetchProjects loads projects correctly', () async {
      await viewModel.fetchProjects();

      expect(viewModel.projects.length, 2);
      expect(viewModel.totalProjects, 2);
      expect(viewModel.isLoading, false);
      expect(viewModel.errorMessage, isNull);
    });

    test('Filtering by status filters project items', () async {
      viewModel.setFilter(status: ProjectStatus.inProgress);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(viewModel.projects.length, 1);
      expect(viewModel.projects.first.title, 'Infrastructure Migration');
    });

    test('createProject adds project and refreshes list', () async {
      final success = await viewModel.createProject(
        title: 'New Microservice',
        description: 'FastAPI auth microservice',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
      );

      expect(success, true);
      expect(viewModel.projects.length, 3);
      expect(viewModel.projects.any((p) => p.title == 'New Microservice'), true);
    });

    test('deleteProject removes project from list', () async {
      await viewModel.fetchProjects();
      expect(viewModel.projects.length, 2);

      final success = await viewModel.deleteProject(1);
      expect(success, true);
      expect(viewModel.projects.length, 1);
      expect(viewModel.projects.any((p) => p.id == 1), false);
    });
  });
}
