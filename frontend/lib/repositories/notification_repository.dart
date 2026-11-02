import '../core/utils/network_utils.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationRepository {
  final NotificationService _notificationService;

  NotificationRepository(this._notificationService);

  bool _isNetworkFailure(dynamic error) => NetworkUtils.isNetworkOrHostFailure(error);

  final List<NotificationModel> _demoNotifications = [
    NotificationModel(
      id: 1,
      userId: 1,
      title: 'Task Assigned',
      message: 'You were assigned to "Implement Redis Token Blacklist Revocation".',
      notificationType: 'task_assigned',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    NotificationModel(
      id: 2,
      userId: 1,
      title: 'Status Updated',
      message: 'Task #103 status changed to Done.',
      notificationType: 'task_status_changed',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  Future<List<NotificationModel>> getNotifications({bool unreadOnly = false}) async {
    try {
      return await _notificationService.getNotifications(unreadOnly: unreadOnly);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        if (unreadOnly) {
          return _demoNotifications.where((n) => !n.isRead).toList();
        }
        return List<NotificationModel>.from(_demoNotifications);
      }
      rethrow;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final idx = _demoNotifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          _demoNotifications[idx] = NotificationModel(
            id: _demoNotifications[idx].id,
            userId: _demoNotifications[idx].userId,
            title: _demoNotifications[idx].title,
            message: _demoNotifications[idx].message,
            notificationType: _demoNotifications[idx].notificationType,
            isRead: true,
            createdAt: _demoNotifications[idx].createdAt,
          );
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      if (_isNetworkFailure(e)) {
        for (int i = 0; i < _demoNotifications.length; i++) {
          _demoNotifications[i] = NotificationModel(
            id: _demoNotifications[i].id,
            userId: _demoNotifications[i].userId,
            title: _demoNotifications[i].title,
            message: _demoNotifications[i].message,
            notificationType: _demoNotifications[i].notificationType,
            isRead: true,
            createdAt: _demoNotifications[i].createdAt,
          );
        }
        return;
      }
      rethrow;
    }
  }
}
