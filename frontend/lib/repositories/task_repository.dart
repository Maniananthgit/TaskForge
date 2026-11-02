import '../core/utils/network_utils.dart';
import '../models/api_response.dart';
import '../models/comment_model.dart';
import '../models/task_history_model.dart';
import '../models/task_model.dart';
import '../services/comment_service.dart';
import '../services/task_service.dart';

class TaskRepository {
  final TaskService _taskService;
  final CommentService _commentService;

  TaskRepository(this._taskService, this._commentService);

  bool _isNetworkFailure(dynamic error) => NetworkUtils.isNetworkOrHostFailure(error);

  final List<TaskModel> _demoTasks = [
    TaskModel(
      id: 101,
      projectId: 1,
      title: 'Implement Redis Token Blacklist Revocation',
      description: 'Ensure token blacklist persists in Redis with TTL matching JWT expiration.',
      status: TaskStatus.inProgress,
      priority: TaskPriority.urgent,
      dueDate: DateTime.now().add(const Duration(days: 1)),
      estimatedHours: 8.0,
      actualHours: 4.5,
      assigneeId: 3,
      creatorId: 1,
    ),
    TaskModel(
      id: 102,
      projectId: 2,
      title: 'Design Responsive Mobile Navigation Shell',
      description: 'Adaptive bottom navigation for mobile and navigation rail for wide desktop screens.',
      status: TaskStatus.todo,
      priority: TaskPriority.high,
      dueDate: DateTime.now().add(const Duration(days: 3)),
      estimatedHours: 12.0,
      actualHours: 2.0,
      assigneeId: 3,
      creatorId: 2,
    ),
    TaskModel(
      id: 103,
      projectId: 3,
      title: 'Alembic Database Migration Script Review',
      description: 'Verify foreign keys, cascading deletes, and default timestamp triggers.',
      status: TaskStatus.done,
      priority: TaskPriority.medium,
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
      estimatedHours: 6.0,
      actualHours: 5.5,
      assigneeId: 1,
      creatorId: 2,
    ),
    TaskModel(
      id: 104,
      projectId: 3,
      title: 'Configure Asymmetric RSA-OAEP-256 Key Exchange',
      description: 'Secure payload encryption for sensitive communication between client and backend.',
      status: TaskStatus.inReview,
      priority: TaskPriority.urgent,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      estimatedHours: 10.0,
      actualHours: 9.0,
      assigneeId: 2,
      creatorId: 1,
    ),
  ];

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
    try {
      return await _taskService.getTasks(
        projectId: projectId,
        assigneeId: assigneeId,
        status: status,
        priority: priority,
        search: search,
        overdueOnly: overdueOnly,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        var items = List<TaskModel>.from(_demoTasks);
        if (projectId != null) {
          items = items.where((t) => t.projectId == projectId).toList();
        }
        if (assigneeId != null) {
          items = items.where((t) => t.assigneeId == assigneeId).toList();
        }
        if (status != null) {
          items = items.where((t) => t.status == status).toList();
        }
        if (priority != null) {
          items = items.where((t) => t.priority == priority).toList();
        }
        if (search != null && search.isNotEmpty) {
          items = items.where((t) => t.title.toLowerCase().contains(search.toLowerCase())).toList();
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

  Future<TaskModel> getTaskById(int id) async {
    try {
      return await _taskService.getTaskById(id);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return _demoTasks.firstWhere((t) => t.id == id, orElse: () => _demoTasks.first);
      }
      rethrow;
    }
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
    try {
      return await _taskService.createTask(
        projectId: projectId,
        title: title,
        description: description,
        status: status,
        priority: priority,
        dueDate: dueDate,
        estimatedHours: estimatedHours,
        assigneeId: assigneeId,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final newTask = TaskModel(
          id: _demoTasks.length + 101,
          projectId: projectId,
          title: title,
          description: description,
          status: status,
          priority: priority,
          dueDate: dueDate,
          estimatedHours: estimatedHours,
          assigneeId: assigneeId,
          createdAt: DateTime.now(),
        );
        _demoTasks.insert(0, newTask);
        return newTask;
      }
      rethrow;
    }
  }

  Future<TaskModel> updateStatus({required int id, required TaskStatus status}) async {
    try {
      return await _taskService.updateStatus(id: id, status: status);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final idx = _demoTasks.indexWhere((t) => t.id == id);
        if (idx != -1) {
          final current = _demoTasks[idx];
          final updated = TaskModel(
            id: current.id,
            projectId: current.projectId,
            title: current.title,
            description: current.description,
            status: status,
            priority: current.priority,
            dueDate: current.dueDate,
            estimatedHours: current.estimatedHours,
            actualHours: current.actualHours,
            assigneeId: current.assigneeId,
            creatorId: current.creatorId,
          );
          _demoTasks[idx] = updated;
          return updated;
        }
      }
      rethrow;
    }
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
    try {
      return await _taskService.updateTask(
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
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return getTaskById(id);
      }
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await _taskService.deleteTask(id);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        _demoTasks.removeWhere((t) => t.id == id);
        return;
      }
      rethrow;
    }
  }

  Future<List<CommentModel>> getComments(int taskId) async {
    try {
      return await _commentService.getComments(taskId);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return [
          CommentModel(
            id: 1,
            taskId: taskId,
            authorId: 1,
            content: 'Task created and priority set to urgent. Please review architecture specifications.',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
          CommentModel(
            id: 2,
            taskId: taskId,
            authorId: 3,
            content: 'Working on this now. Verification tests passing locally.',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ];
      }
      rethrow;
    }
  }

  Future<CommentModel> addComment({required int taskId, required String content}) async {
    try {
      return await _commentService.addComment(taskId: taskId, content: content);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return CommentModel(
          id: DateTime.now().millisecondsSinceEpoch,
          taskId: taskId,
          authorId: 1,
          content: content,
          createdAt: DateTime.now(),
        );
      }
      rethrow;
    }
  }

  Future<void> deleteComment(int commentId) async {
    try {
      await _commentService.deleteComment(commentId);
    } catch (e) {
      if (_isNetworkFailure(e)) return;
      rethrow;
    }
  }

  Future<List<TaskHistoryModel>> getTaskHistory(int taskId) async {
    return [
      TaskHistoryModel(
        id: 1,
        taskId: taskId,
        fieldChanged: 'status',
        oldValue: 'todo',
        newValue: 'in_progress',
        changedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }
}
