import '../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  Future<List<NotificationModel>> getNotifications({bool unreadOnly = false}) async {
    final response = await _apiClient.get(
      ApiConstants.notifications,
      queryParameters: {'unread_only': unreadOnly},
    );
    final list = response as List<dynamic>;
    return list.map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<void> markAsRead(int notificationId) async {
    await _apiClient.patch(ApiConstants.markNotificationRead(notificationId));
  }

  Future<void> markAllAsRead() async {
    await _apiClient.post(ApiConstants.markAllNotificationsRead);
  }
}
