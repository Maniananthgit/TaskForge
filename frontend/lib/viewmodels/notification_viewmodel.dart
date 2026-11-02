import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepository;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  NotificationViewModel(this._notificationRepository);

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _notificationRepository.getNotifications(unreadOnly: unreadOnly);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _notificationRepository.markAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        final current = _notifications[index];
        _notifications[index] = NotificationModel(
          id: current.id,
          userId: current.userId,
          title: current.title,
          message: current.message,
          notificationType: current.notificationType,
          isRead: true,
          linkUrl: current.linkUrl,
          createdAt: current.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationRepository.markAllAsRead();
      _notifications = _notifications
          .map((n) => NotificationModel(
                id: n.id,
                userId: n.userId,
                title: n.title,
                message: n.message,
                notificationType: n.notificationType,
                isRead: true,
                linkUrl: n.linkUrl,
                createdAt: n.createdAt,
              ))
          .toList();
      notifyListeners();
    } catch (_) {}
  }
}
