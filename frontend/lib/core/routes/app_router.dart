import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_navigation_shell.dart';
import '../../views/auth/login_view.dart';
import '../../views/auth/register_view.dart';
import '../../views/dashboard/dashboard_view.dart';
import '../../views/projects/project_list_view.dart';
import '../../views/projects/project_detail_view.dart';
import '../../views/tasks/task_list_view.dart';
import '../../views/tasks/task_detail_view.dart';
import '../../views/notifications/notifications_view.dart';
import '../../views/profile/profile_view.dart';
import '../../views/users/user_management_view.dart';
import '../../views/users/user_detail_view.dart';

class AppRouter {
  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: authViewModel,
      redirect: (context, state) {
        final status = authViewModel.status;
        final isAuth = authViewModel.isAuthenticated;
        final loc = state.matchedLocation;

        if (status == AuthStatus.uninitialized || status == AuthStatus.loading) {
          return null;
        }

        final isAuthRoute = loc == '/login' || loc == '/register';

        if (!isAuth && !isAuthRoute) {
          return '/login';
        }

        if (isAuth && isAuthRoute) {
          return '/dashboard';
        }

        // Admin-only route guard
        if (loc.startsWith('/users')) {
          final user = authViewModel.currentUser;
          if (user == null || user.role != UserRole.admin) {
            return '/dashboard';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginView(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterView(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final loc = state.matchedLocation;
            int selectedIndex = 0;
            if (loc.startsWith('/projects')) {
              selectedIndex = 1;
            } else if (loc.startsWith('/tasks')) {
              selectedIndex = 2;
            } else if (loc.startsWith('/notifications')) {
              selectedIndex = 3;
            } else if (loc.startsWith('/profile')) {
              selectedIndex = 4;
            } else if (loc.startsWith('/users')) {
              selectedIndex = 5;
            }
            return AppNavigationShell(
              selectedIndex: selectedIndex,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardView(),
            ),
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectListView(),
            ),
            GoRoute(
              path: '/projects/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return ProjectDetailView(projectId: id);
              },
            ),
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TaskListView(),
            ),
            GoRoute(
              path: '/tasks/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return TaskDetailView(taskId: id);
              },
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsView(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileView(),
            ),
            GoRoute(
              path: '/users',
              builder: (context, state) => const UserManagementView(),
            ),
            GoRoute(
              path: '/users/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return UserDetailView(userId: id);
              },
            ),
          ],
        ),
      ],
    );
  }
}
