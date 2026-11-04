import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/comment_model.dart';
import '../repositories/task_repository.dart';

class TaskViewModel extends ChangeNotifier {
  final TaskRepository _taskRepository;

  List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filters
  int? _projectIdFilter;
  int? _assigneeIdFilter;
  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;
  String? _searchQuery;
  bool _overdueOnly = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalTasks = 0;

  TaskViewModel(this._taskRepository);

  List<TaskModel> get tasks => _tasks;
  TaskModel? get selectedTask => _selectedTask;
  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalTasks => _totalTasks;
  TaskStatus? get statusFilter => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;
  bool get overdueOnly => _overdueOnly;

  void setFilter({
    int? projectId,
    int? assigneeId,
    TaskStatus? status,
    TaskPriority? priority,
    String? search,
    bool? overdueOnly,
  }) {
    if (projectId != null) _projectIdFilter = projectId;
    if (assigneeId != null) _assigneeIdFilter = assigneeId;
    _statusFilter = status;
    _priorityFilter = priority;
    _searchQuery = search;
    if (overdueOnly != null) _overdueOnly = overdueOnly;
    _currentPage = 1;
    fetchTasks();
  }

  void clearFilters() {
    _statusFilter = null;
    _priorityFilter = null;
    _searchQuery = null;
    _overdueOnly = false;
    _currentPage = 1;
    fetchTasks();
  }

  Future<void> fetchTasks({int page = 1, int? projectId}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    if (projectId != null) _projectIdFilter = projectId;
    notifyListeners();

    try {
      final result = await _taskRepository.getTasks(
        projectId: _projectIdFilter,
        assigneeId: _assigneeIdFilter,
        status: _statusFilter,
        priority: _priorityFilter,
        search: _searchQuery,
        overdueOnly: _overdueOnly,
        page: _currentPage,
        pageSize: 10,
      );
      _tasks = result.items;
      _totalTasks = result.total;
      _totalPages = result.totalPages;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTaskDetail(int taskId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedTask = await _taskRepository.getTaskById(taskId);
      _comments = _selectedTask?.comments ?? [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask({
    required int projectId,
    required String title,
    String? description,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    double estimatedHours = 0.0,
    int? assigneeId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _taskRepository.createTask(
        projectId: projectId,
        title: title,
        description: description,
        status: status,
        priority: priority,
        dueDate: dueDate,
        estimatedHours: estimatedHours,
        assigneeId: assigneeId,
      );
      await fetchTasks(page: 1, projectId: _projectIdFilter);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStatus({required int id, required TaskStatus status}) async {
    try {
      final updated = await _taskRepository.updateStatus(id: id, status: status);
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = updated;
      }
      if (_selectedTask?.id == id) {
        await fetchTaskDetail(id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask({
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
    try {
      final updated = await _taskRepository.updateTask(
        id: id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        dueDate: dueDate,
        estimatedHours: estimatedHours,
        actualHours: actualHours,
        assigneeId: assigneeId,
      );
      _selectedTask = updated;
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      await _taskRepository.deleteTask(id);
      _tasks.removeWhere((t) => t.id == id);
      if (_selectedTask?.id == id) {
        _selectedTask = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addComment(int taskId, String content, {bool isInternal = false}) async {
    if (content.trim().isEmpty) return false;
    try {
      final newComment = await _taskRepository.addComment(
        taskId: taskId,
        content: content,
        isInternal: isInternal,
      );
      _comments.insert(0, newComment);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      await _taskRepository.deleteComment(commentId);
      _comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
