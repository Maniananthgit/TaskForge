class ApiConstants {
  // Configurable base URL via --dart-define=API_BASE_URL=...
  // - Local dev: http://127.0.0.1:8000/api/v1
  // - Production Cloud Run / Firebase: passed via --dart-define or defaults to /api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String rsaPublicKey = '/auth/rsa-public-key';

  // Users & User Management
  static const String users = '/users/';
  static const String userMetrics = '/users/metrics';
  static const String userInvite = '/users/invite';
  static const String acceptInvitation = '/users/accept-invitation';
  static const String confirmPasswordReset = '/users/confirm-password-reset';
  static String userDetail(int id) => '/users/$id';
  static String updateUserRole(int id) => '/users/$id/role';
  static String updateUserStatus(int id) => '/users/$id/status';
  static String resendInvitation(int id) => '/users/$id/resend-invitation';
  static String resetPassword(int id) => '/users/$id/reset-password';
  static String restoreUser(int id) => '/users/$id/restore';
  static String userProjects(int id) => '/users/$id/projects';
  static String removeUserProject(int userId, int projectId) => '/users/$userId/projects/$projectId';
  static String userActivity(int id) => '/users/$id/activity';

  // Projects
  static const String projects = '/projects/';
  static String projectDetail(int id) => '/projects/$id';
  static String projectMembers(int id) => '/projects/$id/members';
  static String removeMember(int projectId, int userId) => '/projects/$projectId/members/$userId';

  // Tasks
  static const String tasks = '/tasks/';
  static String taskDetail(int id) => '/tasks/$id';
  static String taskStatus(int id) => '/tasks/$id/status';
  static String taskComments(int id) => '/tasks/$id/comments';
  static String commentDetail(int id) => '/comments/$id';

  // Notifications
  static const String notifications = '/notifications/';
  static String markNotificationRead(int id) => '/notifications/$id/read';
  static const String markAllNotificationsRead = '/notifications/mark-all-read';

  // Dashboard
  static const String dashboardMetrics = '/dashboard/metrics';

  // Health
  static const String health = '/health';
  static const String readiness = '/readiness';
}
