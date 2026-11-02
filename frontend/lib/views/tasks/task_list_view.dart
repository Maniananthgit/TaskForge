import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/task_model.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import 'task_create_dialog.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskViewModel>().fetchTasks(page: 1);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const TaskCreateDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => taskVM.fetchTasks(page: taskVM.currentPage),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workspace Tasks', style: AppTextStyles.h1(context)),
                      const SizedBox(height: 4),
                      Text(
                        'Track work items, prioritize execution, and log progress.',
                        style: AppTextStyles.subtitle(context),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('New Task'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter Bar Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search tasks by title or description...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          taskVM.setFilter(search: null);
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (val) {
                                taskVM.setFilter(search: val.trim().isEmpty ? null : val.trim());
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              FilterChip(
                                label: const Text('Overdue Only'),
                                selected: taskVM.overdueOnly,
                                selectedColor: AppColors.danger.withOpacity(0.2),
                                checkmarkColor: AppColors.danger,
                                onSelected: (selected) {
                                  taskVM.setFilter(overdueOnly: selected);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Status Choice Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All Tasks'),
                              selected: taskVM.statusFilter == null,
                              onSelected: (_) => taskVM.setFilter(status: null),
                            ),
                            const SizedBox(width: 8),
                            ...TaskStatus.values.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(s.displayName),
                                  selected: taskVM.statusFilter == s,
                                  onSelected: (selected) {
                                    taskVM.setFilter(status: selected ? s : null);
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Task List Content
              if (taskVM.isLoading && taskVM.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: LoadingView(message: 'Loading tasks...'),
                )
              else if (taskVM.errorMessage != null && taskVM.tasks.isEmpty)
                ErrorView(
                  message: taskVM.errorMessage!,
                  onRetry: () => taskVM.fetchTasks(page: 1),
                )
              else if (taskVM.tasks.isEmpty)
                EmptyView(
                  title: 'No Tasks Found',
                  message: 'Create a new task to start organizing your work.',
                  icon: Icons.task_alt_rounded,
                  buttonText: 'Create Task',
                  onButtonPressed: _showCreateDialog,
                )
              else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                const SizedBox(height: 24),

                // Pagination
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${taskVM.tasks.length} of ${taskVM.totalTasks} tasks',
                      style: AppTextStyles.caption(context),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: taskVM.currentPage > 1
                              ? () => taskVM.fetchTasks(page: taskVM.currentPage - 1)
                              : null,
                          child: const Text('Previous'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Page ${taskVM.currentPage} of ${taskVM.totalPages}',
                            style: AppTextStyles.bodyBold(context),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: taskVM.currentPage < taskVM.totalPages
                              ? () => taskVM.fetchTasks(page: taskVM.currentPage + 1)
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
