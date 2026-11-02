import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge_app/models/api_response.dart';
import 'package:taskforge_app/models/task_model.dart';
import 'package:taskforge_app/models/comment_model.dart';
import 'package:taskforge_app/models/task_history_model.dart';
import 'package:taskforge_app/repositories/task_repository.dart';
import 'package:taskforge_app/viewmodels/task_viewmodel.dart';

class MockTaskRepository implements TaskRepository {
  List<TaskModel> tasks = [];
  List<CommentModel> comments = [];

  @override
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
    return PaginatedResult(
      items: tasks,
      total: tasks.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<TaskModel> getTaskById(int id) async {
    return tasks.firstWhere((t) => t.id == id);
  }

  @override
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
    final t = TaskModel(
      id: tasks.length + 1,
      projectId: projectId,
      title: title,
      status: status,
      priority: priority,
      dueDate: dueDate,
      estimatedHours: estimatedHours,
      assigneeId: assigneeId,
    );
    tasks.add(t);
    return t;
  }

  @override
  Future<TaskModel> updateStatus({required int id, required TaskStatus status}) async {
    final idx = tasks.indexWhere((t) => t.id == id);
    final current = tasks[idx];
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
    );
    tasks[idx] = updated;
    return updated;
  }

  @override
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
    final idx = tasks.indexWhere((t) => t.id == id);
    return tasks[idx];
  }

  @override
  Future<void> deleteTask(int id) async {
    tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<CommentModel>> getComments(int taskId) async {
    return comments;
  }

  @override
  Future<CommentModel> addComment({required int taskId, required String content}) async {
    final c = CommentModel(id: comments.length + 1, taskId: taskId, authorId: 1, content: content);
    comments.add(c);
    return c;
  }

  @override
  Future<void> deleteComment(int commentId) async {
    comments.removeWhere((c) => c.id == commentId);
  }

  @override
  Future<List<TaskHistoryModel>> getTaskHistory(int taskId) async {
    return [];
  }
}

void main() {
  group('TaskViewModel Unit Tests', () {
    late MockTaskRepository mockRepo;
    late TaskViewModel viewModel;

    setUp(() {
      mockRepo = MockTaskRepository();
      mockRepo.tasks = [
        TaskModel(
          id: 1,
          projectId: 10,
          title: 'Implement JWT refresh',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
        ),
      ];
      viewModel = TaskViewModel(mockRepo);
    });

    test('fetchTasks retrieves task items', () async {
      await viewModel.fetchTasks();

      expect(viewModel.tasks.length, 1);
      expect(viewModel.tasks.first.title, 'Implement JWT refresh');
    });

    test('updateStatus modifies task status and triggers notifyListeners', () async {
      await viewModel.fetchTasks();
      final success = await viewModel.updateStatus(id: 1, status: TaskStatus.done);

      expect(success, true);
      expect(viewModel.tasks.first.status, TaskStatus.done);
    });

    test('createTask appends task to list', () async {
      final success = await viewModel.createTask(
        projectId: 10,
        title: 'Write pytest tests',
        status: TaskStatus.inProgress,
        priority: TaskPriority.medium,
      );

      expect(success, true);
      expect(viewModel.tasks.length, 2);
      expect(viewModel.tasks.any((t) => t.title == 'Write pytest tests'), true);
    });

    test('addComment inserts discussion comment', () async {
      final success = await viewModel.addComment(1, 'Great progress on this!');

      expect(success, true);
      expect(viewModel.comments.length, 1);
      expect(viewModel.comments.first.content, 'Great progress on this!');
    });
  });
}
