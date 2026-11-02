import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'services/storage_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';
import 'services/task_service.dart';
import 'services/comment_service.dart';
import 'services/notification_service.dart';
import 'services/dashboard_service.dart';
import 'services/user_service.dart';
import 'repositories/auth_repository.dart';
import 'repositories/project_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/dashboard_repository.dart';
import 'repositories/user_repository.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/project_viewmodel.dart';
import 'viewmodels/task_viewmodel.dart';
import 'viewmodels/notification_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'viewmodels/user_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate Core Services
  final storageService = StorageService();
  final apiClient = ApiClient(storageService);

  final authService = AuthService(apiClient, storageService);
  final projectService = ProjectService(apiClient);
  final taskService = TaskService(apiClient);
  final commentService = CommentService(apiClient);
  final notificationService = NotificationService(apiClient);
  final dashboardService = DashboardService(apiClient);
  final userService = UserService(apiClient);

  // Instantiate Repositories
  final authRepository = AuthRepository(authService, storageService);
  final projectRepository = ProjectRepository(projectService);
  final taskRepository = TaskRepository(taskService, commentService);
  final notificationRepository = NotificationRepository(notificationService);
  final dashboardRepository = DashboardRepository(dashboardService);
  final userRepository = UserRepository(userService);

  runApp(
    TaskForgeApp(
      authRepository: authRepository,
      projectRepository: projectRepository,
      taskRepository: taskRepository,
      notificationRepository: notificationRepository,
      dashboardRepository: dashboardRepository,
      userRepository: userRepository,
      userService: userService,
    ),
  );
}

class TaskForgeApp extends StatefulWidget {
  final AuthRepository authRepository;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final NotificationRepository notificationRepository;
  final DashboardRepository dashboardRepository;
  final UserRepository userRepository;
  final UserService userService;

  const TaskForgeApp({
    super.key,
    required this.authRepository,
    required this.projectRepository,
    required this.taskRepository,
    required this.notificationRepository,
    required this.dashboardRepository,
    required this.userRepository,
    required this.userService,
  });

  @override
  State<TaskForgeApp> createState() => _TaskForgeAppState();
}

class _TaskForgeAppState extends State<TaskForgeApp> {
  late final AuthViewModel _authViewModel;
  late final ProjectViewModel _projectViewModel;
  late final TaskViewModel _taskViewModel;
  late final NotificationViewModel _notificationViewModel;
  late final DashboardViewModel _dashboardViewModel;
  late final ThemeViewModel _themeViewModel;
  late final UserViewModel _userViewModel;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(widget.authRepository);
    _projectViewModel = ProjectViewModel(widget.projectRepository, widget.userService);
    _taskViewModel = TaskViewModel(widget.taskRepository);
    _notificationViewModel = NotificationViewModel(widget.notificationRepository);
    _dashboardViewModel = DashboardViewModel(widget.dashboardRepository);
    _themeViewModel = ThemeViewModel();
    _userViewModel = UserViewModel(widget.userRepository);

    _router = AppRouter.createRouter(_authViewModel);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
        ChangeNotifierProvider<ProjectViewModel>.value(value: _projectViewModel),
        ChangeNotifierProvider<TaskViewModel>.value(value: _taskViewModel),
        ChangeNotifierProvider<NotificationViewModel>.value(value: _notificationViewModel),
        ChangeNotifierProvider<DashboardViewModel>.value(value: _dashboardViewModel),
        ChangeNotifierProvider<ThemeViewModel>.value(value: _themeViewModel),
        ChangeNotifierProvider<UserViewModel>.value(value: _userViewModel),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVM, _) {
          return MaterialApp.router(
            title: 'TaskForge — Enterprise Project Management',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeVM.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
