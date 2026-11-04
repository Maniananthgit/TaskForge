import '../core/constants/api_constants.dart';
import '../models/comment_model.dart';
import 'api_client.dart';

class CommentService {
  final ApiClient _apiClient;

  CommentService(this._apiClient);

  Future<List<CommentModel>> getComments(int taskId) async {
    final response = await _apiClient.get(ApiConstants.taskComments(taskId));
    final list = response as List<dynamic>;
    return list.map((c) => CommentModel.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<CommentModel> addComment({
    required int taskId,
    required String content,
    bool isInternal = false,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.taskComments(taskId),
      body: {
        'content': content,
        'is_internal': isInternal,
      },
    );
    return CommentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteComment(int commentId) async {
    await _apiClient.delete(ApiConstants.commentDetail(commentId));
  }
}
