import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../widgets/project_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import 'project_create_dialog.dart';

class ProjectListView extends StatefulWidget {
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().fetchProjects(page: 1);
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
      builder: (_) => const ProjectCreateDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = context.watch<ProjectViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.currentUser;
    final canCreate = user?.role == UserRole.admin || user?.role == UserRole.projectManager;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => projectVM.fetchProjects(page: projectVM.currentPage),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Projects Portfolio', style: AppTextStyles.h1(context)),
                      const SizedBox(height: 4),
                      Text(
                        'Manage, track and execute enterprise project milestones.',
                        style: AppTextStyles.subtitle(context),
                      ),
                    ],
                  ),
                  if (canCreate)
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('New Project'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter Controls
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
                                hintText: 'Search projects by title or description...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          projectVM.setFilter(search: null);
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (val) {
                                projectVM.setFilter(search: val.trim().isEmpty ? null : val.trim());
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              projectVM.setFilter(
                                search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
                              );
                            },
                            icon: const Icon(Icons.filter_list_rounded, size: 18),
                            label: const Text('Filter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Status Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All Statuses'),
                              selected: projectVM.statusFilter == null,
                              onSelected: (_) => projectVM.setFilter(status: null),
                            ),
                            const SizedBox(width: 8),
                            ...ProjectStatus.values.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(s.displayName),
                                  selected: projectVM.statusFilter == s,
                                  onSelected: (selected) {
                                    projectVM.setFilter(status: selected ? s : null);
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

              // Main Project Content
              if (projectVM.isLoading && projectVM.projects.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: LoadingView(message: 'Loading projects...'),
                )
              else if (projectVM.errorMessage != null && projectVM.projects.isEmpty)
                ErrorView(
                  message: projectVM.errorMessage!,
                  onRetry: () => projectVM.fetchProjects(page: 1),
                )
              else if (projectVM.projects.isEmpty)
                EmptyView(
                  title: 'No Projects Found',
                  message: 'Get started by creating your first enterprise project.',
                  icon: Icons.folder_open_rounded,
                  buttonText: canCreate ? 'Create First Project' : null,
                  onButtonPressed: canCreate ? _showCreateDialog : null,
                )
              else ...[
                // Projects Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;
                    return GridView.builder(
                      itemCount: projectVM.projects.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: crossAxisCount == 2 ? 1.7 : 1.9,
                      ),
                      itemBuilder: (context, index) {
                        final p = projectVM.projects[index];
                        return ProjectCard(
                          project: p,
                          onTap: () => context.go('/projects/${p.id}'),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Pagination Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${projectVM.projects.length} of ${projectVM.totalProjects} projects',
                      style: AppTextStyles.caption(context),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: projectVM.currentPage > 1
                              ? () => projectVM.fetchProjects(page: projectVM.currentPage - 1)
                              : null,
                          child: const Text('Previous'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Page ${projectVM.currentPage} of ${projectVM.totalPages}',
                            style: AppTextStyles.bodyBold(context),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: projectVM.currentPage < projectVM.totalPages
                              ? () => projectVM.fetchProjects(page: projectVM.currentPage + 1)
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
