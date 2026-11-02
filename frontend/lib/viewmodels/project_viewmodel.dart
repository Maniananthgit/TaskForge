import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../repositories/project_repository.dart';
import '../services/user_service.dart';

class ProjectViewModel extends ChangeNotifier {
  final ProjectRepository _projectRepository;
  final UserService _userService;

  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<UserModel> _availableUsers = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filter State
  String? _searchQuery;
  ProjectStatus? _statusFilter;
  ProjectPriority? _priorityFilter;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalProjects = 0;

  ProjectViewModel(this._projectRepository, this._userService);

  List<ProjectModel> get projects => _projects;
  ProjectModel? get selectedProject => _selectedProject;
  List<UserModel> get availableUsers => _availableUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalProjects => _totalProjects;
  ProjectStatus? get statusFilter => _statusFilter;
  ProjectPriority? get priorityFilter => _priorityFilter;

  void setFilter({ProjectStatus? status, ProjectPriority? priority, String? search}) {
    _statusFilter = status;
    _priorityFilter = priority;
    _searchQuery = search;
    _currentPage = 1;
    fetchProjects();
  }

  void clearFilters() {
    _statusFilter = null;
    _priorityFilter = null;
    _searchQuery = null;
    _currentPage = 1;
    fetchProjects();
  }

  Future<void> fetchProjects({int page = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    notifyListeners();

    try {
      final result = await _projectRepository.getProjects(
        search: _searchQuery,
        status: _statusFilter,
        priority: _priorityFilter,
        page: _currentPage,
        pageSize: 10,
      );
      _projects = result.items;
      _totalProjects = result.total;
      _totalPages = result.totalPages;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProjectDetail(int projectId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedProject = await _projectRepository.getProjectById(projectId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAvailableUsers() async {
    try {
      _availableUsers = await _userService.getUsers();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> createProject({
    required String title,
    String? description,
    ProjectStatus status = ProjectStatus.planning,
    ProjectPriority priority = ProjectPriority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    double budgetHours = 0.0,
    List<int>? memberIds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _projectRepository.createProject(
        title: title,
        description: description,
        status: status,
        priority: priority,
        startDate: startDate,
        dueDate: dueDate,
        budgetHours: budgetHours,
        memberIds: memberIds,
      );
      await fetchProjects(page: 1);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProject({
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
      final updated = await _projectRepository.updateProject(
        id: id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        startDate: startDate,
        dueDate: dueDate,
        budgetHours: budgetHours,
      );
      _selectedProject = updated;
      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProject(int id) async {
    try {
      await _projectRepository.deleteProject(id);
      _projects.removeWhere((p) => p.id == id);
      if (_selectedProject?.id == id) {
        _selectedProject = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addMember({
    required int projectId,
    required int userId,
    String role = 'Member',
  }) async {
    try {
      await _projectRepository.addMember(
        projectId: projectId,
        userId: userId,
        roleInProject: role,
      );
      await fetchProjectDetail(projectId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember({required int projectId, required int userId}) async {
    try {
      await _projectRepository.removeMember(projectId: projectId, userId: userId);
      await fetchProjectDetail(projectId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
