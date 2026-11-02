import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../tasks/task_create_dialog.dart';

class ProjectDetailView extends StatefulWidget {
  final int projectId;

  const ProjectDetailView({super.key, required this.projectId});

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().fetchProjectDetail(widget.projectId);
      context.read<TaskViewModel>().fetchTasks(projectId: widget.projectId);
      context.read<ProjectViewModel>().fetchAvailableUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddTaskDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => TaskCreateDialog(preselectedProjectId: widget.projectId),
    );
    if (result == true && mounted) {
      context.read<TaskViewModel>().fetchTasks(projectId: widget.projectId);
      context.read<ProjectViewModel>().fetchProjectDetail(widget.projectId);
    }
  }

  void _showAddMemberDialog() {
    final projectVM = context.read<ProjectViewModel>();
    UserModel? selectedUser;
    String role = 'Member';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Team Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserModel>(
                hint: const Text('Select User'),
                items: projectVM.availableUsers.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text('${u.fullName} (${u.role.displayName})'),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedUser = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'Lead', child: Text('Lead')),
                  DropdownMenuItem(value: 'Member', child: Text('Member')),
                  DropdownMenuItem(value: 'Observer', child: Text('Observer')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => role = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedUser == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await projectVM.addMember(
                        projectId: widget.projectId,
                        userId: selectedUser!.id,
                        role: role,
                      );
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: const Text(
          'This action cannot be undone. All tasks, comments, and project associations will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.read<ProjectViewModel>().deleteProject(widget.projectId);
              if (success && mounted) {
                context.go('/projects');
              }
            },
            child: const Text('Delete Project', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = context.watch<ProjectViewModel>();
    final taskVM = context.watch<TaskViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.currentUser;
    final project = projectVM.selectedProject;

    if (projectVM.isLoading && project == null) {
      return const Scaffold(body: LoadingView(message: 'Loading project details...'));
    }

    if (projectVM.errorMessage != null && project == null) {
      return Scaffold(
        body: ErrorView(
          message: projectVM.errorMessage!,
          onRetry: () => projectVM.fetchProjectDetail(widget.projectId),
        ),
      );
    }

    if (project == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final canManage = user?.role == UserRole.admin ||
        user?.role == UserRole.projectManager ||
        project.ownerId == user?.id;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs / Back row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/projects'),
                ),
                const SizedBox(width: 8),
                Text('Projects', style: AppTextStyles.subtitle(context)),
                const Text(' / '),
                Text(project.title, style: AppTextStyles.bodyBold(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Main Project Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  StatusBadge.forProjectStatus(project.status.name),
                                  const SizedBox(width: 8),
                                  PriorityBadge(priority: project.priority.name),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(project.title, style: AppTextStyles.h1(context).copyWith(fontSize: 26)),
                              if (project.description != null && project.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(project.description!, style: AppTextStyles.body(context)),
                              ],
                            ],
                          ),
                        ),
                        if (canManage) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: _confirmDelete,
                            tooltip: 'Delete Project',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Metadata Metrics Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.person_outline_rounded,
                            label: 'Project Owner',
                            value: project.owner?.fullName ?? 'Internal',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.calendar_today_outlined,
                            label: 'Deadline',
                            value: DateFormatter.formatShortDate(project.dueDate),
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.timer_outlined,
                            label: 'Budget Allocated',
                            value: '${project.budgetHours}h',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.group_outlined,
                            label: 'Team Size',
                            value: '${project.members.length} members',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Progress Overview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Project Completion Progress', style: AppTextStyles.bodyBold(context)),
                        Text(
                          '${project.progressPercentage.toStringAsFixed(0)}% (${project.completedTasksCount}/${project.tasksCount} Tasks)',
                          style: AppTextStyles.caption(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: project.progressPercentage / 100,
                        minHeight: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          project.progressPercentage == 100 ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tab Bar: Tasks vs Team Members
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Tasks (${taskVM.tasks.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Team Members (${project.members.length})'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Content
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Tasks
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sprint Tasks', style: AppTextStyles.h3(context)),
                          ElevatedButton.icon(
                            onPressed: _showAddTaskDialog,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Task'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: taskVM.isLoading && taskVM.tasks.isEmpty
                          ? const LoadingView(message: 'Loading tasks...')
                          : taskVM.tasks.isEmpty
                              ? EmptyView(
                                  title: 'No Tasks in this Project',
                                  message: 'Create a task to assign work to members.',
                                  buttonText: 'Add First Task',
                                  onButtonPressed: _showAddTaskDialog,
                                )
                              : ListView.builder(
                                  itemCount: taskVM.tasks.length,
                                  itemBuilder: (context, idx) {
                                    final task = taskVM.tasks[idx];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: TaskCard(
                                        task: task,
                                        onTap: () => context.go('/tasks/${task.id}'),
                                        onStatusChanged: (newStatus) {
                                          taskVM.updateStatus(id: task.id, status: newStatus);
                                        },
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),

                  // Tab 2: Members
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Project Members', style: AppTextStyles.h3(context)),
                          if (canManage)
                            ElevatedButton.icon(
                              onPressed: _showAddMemberDialog,
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: const Text('Assign Member'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: project.members.isEmpty
                            ? const EmptyView(
                                title: 'No Team Members Assigned',
                                message: 'Assign developers or managers to collaborate.',
                              )
                            : ListView.builder(
                                itemCount: project.members.length,
                                itemBuilder: (context, idx) {
                                  final m = project.members[idx];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary.withOpacity(0.15),
                                        child: Text(
                                          m.user?.fullName.isNotEmpty == true
                                              ? m.user!.fullName[0].toUpperCase()
                                              : 'M',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      title: Text(m.user?.fullName ?? 'User #${m.userId}', style: AppTextStyles.bodyBold(context)),
                                      subtitle: Text(m.user?.email ?? '', style: AppTextStyles.caption(context)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Chip(
                                            label: Text(m.roleInProject, style: const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          if (canManage) ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
                                              onPressed: () {
                                                projectVM.removeMember(projectId: widget.projectId, userId: m.userId);
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.caption(context)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyBold(context)),
      ],
    );
  }
}
