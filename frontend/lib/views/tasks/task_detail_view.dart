import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/task_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';

class TaskDetailView extends StatefulWidget {
  final int taskId;

  const TaskDetailView({super.key, required this.taskId});

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskViewModel>().fetchTaskDetail(widget.taskId);
      context.read<ProjectViewModel>().fetchAvailableUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingComment = true);
    final taskVM = context.read<TaskViewModel>();
    final success = await taskVM.addComment(widget.taskId, text);
    setState(() => _isPostingComment = false);

    if (success) {
      _commentController.clear();
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.read<TaskViewModel>().deleteTask(widget.taskId);
              if (success && mounted) {
                context.go('/tasks');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();
    final projectVM = context.watch<ProjectViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.currentUser;
    final task = taskVM.selectedTask;

    if (taskVM.isLoading && task == null) {
      return const Scaffold(body: LoadingView(message: 'Loading task details...'));
    }

    if (taskVM.errorMessage != null && task == null) {
      return Scaffold(
        body: ErrorView(
          message: taskVM.errorMessage!,
          onRetry: () => taskVM.fetchTaskDetail(widget.taskId),
        ),
      );
    }

    if (task == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

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
                  onPressed: () => context.go('/tasks'),
                ),
                const SizedBox(width: 8),
                Text('Tasks', style: AppTextStyles.subtitle(context)),
                const Text(' / '),
                Text('Task #${task.id}', style: AppTextStyles.bodyBold(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Main Task Information Card
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
                                  StatusBadge.forTaskStatus(task.status.name),
                                  const SizedBox(width: 8),
                                  PriorityBadge(priority: task.priority.name),
                                  if (task.isOverdue) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'OVERDUE',
                                        style: TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(task.title, style: AppTextStyles.h1(context).copyWith(fontSize: 24)),
                              if (task.description != null && task.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(task.description!, style: AppTextStyles.body(context)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          onPressed: _confirmDelete,
                          tooltip: 'Delete Task',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Quick Status & Assignee Bar
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Change Status: ', style: AppTextStyles.bodyBold(context)),
                            const SizedBox(width: 8),
                            DropdownButton<TaskStatus>(
                              value: task.status,
                              underline: const SizedBox.shrink(),
                              items: TaskStatus.values.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(s.displayName),
                                );
                              }).toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null) {
                                  taskVM.updateStatus(id: task.id, status: newStatus);
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Assign Employee: ', style: AppTextStyles.bodyBold(context)),
                            const SizedBox(width: 8),
                            DropdownButton<int?>(
                              value: task.assigneeId,
                              underline: const SizedBox.shrink(),
                              hint: const Text('Unassigned'),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                                ...projectVM.availableUsers.map((u) {
                                  return DropdownMenuItem<int?>(
                                    value: u.id,
                                    child: Text('${u.fullName} (${u.role.displayName})'),
                                  );
                                }),
                              ],
                              onChanged: (newAssigneeId) async {
                                final success = await taskVM.updateTask(
                                  id: task.id,
                                  assigneeId: newAssigneeId,
                                );
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Task assignee updated successfully.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Metadata Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.person_outline_rounded,
                            label: 'Assignee',
                            value: task.assignee?.fullName ?? 'Unassigned',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.calendar_today_outlined,
                            label: 'Due Date',
                            value: DateFormatter.formatShortDate(task.dueDate),
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.timer_outlined,
                            label: 'Estimated / Actual',
                            value: '${task.estimatedHours}h / ${task.actualHours}h',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            context,
                            icon: Icons.account_circle_outlined,
                            label: 'Creator',
                            value: task.creator?.fullName ?? 'System',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tab Bar: Comments & Discussion vs Audit History
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Comments (${taskVM.comments.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Audit History (${task.history.length})'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Content
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Discussion & Comments
                  Column(
                    children: [
                      // Input bar
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: const InputDecoration(
                                    hintText: 'Write a comment or post an update...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _postComment(),
                                ),
                              ),
                              IconButton(
                                icon: _isPostingComment
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded, color: AppColors.primary),
                                onPressed: _isPostingComment ? null : _postComment,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: taskVM.comments.isEmpty
                            ? const Center(child: Text('No comments yet. Start the discussion!'))
                            : ListView.builder(
                                itemCount: taskVM.comments.length,
                                itemBuilder: (context, idx) {
                                  final comment = taskVM.comments[idx];
                                  final isMe = comment.authorId == user?.id;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor: AppColors.primary.withOpacity(0.2),
                                                    child: Text(
                                                      comment.author?.fullName.isNotEmpty == true
                                                          ? comment.author!.fullName[0].toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.primary,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    comment.author?.fullName ?? 'User',
                                                    style: AppTextStyles.bodyBold(context),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    DateFormatter.formatTimeAgo(comment.createdAt),
                                                    style: AppTextStyles.caption(context),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 6),
                                                    IconButton(
                                                      icon: const Icon(Icons.close_rounded, size: 16),
                                                      onPressed: () {
                                                        taskVM.deleteComment(comment.id);
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(comment.content, style: AppTextStyles.body(context)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // Tab 2: Audit History Timeline
                  task.history.isEmpty
                      ? const Center(child: Text('No history logged yet'))
                      : ListView.builder(
                          itemCount: task.history.length,
                          itemBuilder: (context, idx) {
                            final h = task.history[idx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.timeline_rounded, size: 18, color: AppColors.primary),
                                ),
                                title: Text(
                                  'Changed ${h.fieldChanged.toUpperCase()}',
                                  style: AppTextStyles.bodyBold(context),
                                ),
                                subtitle: Text(
                                  '${h.oldValue != null ? "From '${h.oldValue}' to " : ""}\'${h.newValue ?? "None"}\'',
                                  style: AppTextStyles.caption(context),
                                ),
                                trailing: Text(
                                  DateFormatter.formatTimeAgo(h.changedAt),
                                  style: AppTextStyles.caption(context),
                                ),
                              ),
                            );
                          },
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
