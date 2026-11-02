import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().fetchMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardVM = context.watch<DashboardViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (dashboardVM.isLoading && dashboardVM.metrics == null) {
      return const Scaffold(body: LoadingView(message: 'Loading workspace metrics...'));
    }

    if (dashboardVM.errorMessage != null && dashboardVM.metrics == null) {
      return Scaffold(
        body: ErrorView(
          message: dashboardVM.errorMessage!,
          onRetry: () => dashboardVM.fetchMetrics(),
        ),
      );
    }

    final m = dashboardVM.metrics;
    if (m == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => dashboardVM.fetchMetrics(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${user?.fullName.split(' ').first ?? 'User'} 👋',
                        style: AppTextStyles.h1(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here is what is happening across your enterprise projects today.',
                        style: AppTextStyles.subtitle(context),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/projects'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('View Projects'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Personal Workload Alert Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Workspace Assignments',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You have ${m.myTasksCount} assigned tasks (${m.myCompletedTasksCount} completed, ${m.myOverdueTasksCount} overdue).',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/tasks'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // KPI Metric Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 1000
                      ? 4
                      : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.1,
                    children: [
                      StatCard(
                        title: 'Total Projects',
                        value: '${m.totalProjects}',
                        icon: Icons.folder_rounded,
                        iconColor: AppColors.primary,
                        subtitle: 'Active portfolios',
                        onTap: () => context.go('/projects'),
                      ),
                      StatCard(
                        title: 'Active Tasks',
                        value: '${m.activeTasks}',
                        icon: Icons.pending_actions_rounded,
                        iconColor: AppColors.warning,
                        subtitle: 'In progress / review',
                        onTap: () => context.go('/tasks'),
                      ),
                      StatCard(
                        title: 'Completed Tasks',
                        value: '${m.completedTasks}',
                        icon: Icons.check_circle_rounded,
                        iconColor: AppColors.success,
                        subtitle: 'Sprint velocity target',
                        onTap: () => context.go('/tasks'),
                      ),
                      StatCard(
                        title: 'Overdue Tasks',
                        value: '${m.overdueTasks}',
                        icon: Icons.alarm_rounded,
                        iconColor: AppColors.danger,
                        subtitle: 'Requires immediate action',
                        onTap: () => context.go('/tasks'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Charts and Distributions Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Status Distribution Chart
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Task Status Breakdown', style: AppTextStyles.h3(context)),
                                const SizedBox(height: 6),
                                Text(
                                  'Distribution across lifecycle phases',
                                  style: AppTextStyles.subtitle(context),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 200,
                                  child: m.tasksByStatus.isEmpty
                                      ? const Center(child: Text('No task data available'))
                                      : BarChart(
                                          BarChartData(
                                            alignment: BarChartAlignment.spaceAround,
                                            maxY: (m.totalTasks > 0 ? m.totalTasks.toDouble() : 10),
                                            barTouchData: BarTouchData(enabled: true),
                                            titlesData: FlTitlesData(
                                              show: true,
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (val, meta) {
                                                    final idx = val.toInt();
                                                    if (idx < 0 || idx >= m.tasksByStatus.length) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 8),
                                                      child: Text(
                                                        m.tasksByStatus[idx].status.toUpperCase(),
                                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              leftTitles: const AxisTitles(
                                                sideTitles: SideTitles(showTitles: false),
                                              ),
                                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            ),
                                            gridData: const FlGridData(show: false),
                                            borderData: FlBorderData(show: false),
                                            barGroups: m.tasksByStatus.asMap().entries.map((entry) {
                                              return BarChartGroupData(
                                                x: entry.key,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: entry.value.count.toDouble(),
                                                    color: AppColors.primary,
                                                    width: 22,
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
                      // Project Progress Watchlist
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Project Progress', style: AppTextStyles.h3(context)),
                                    TextButton(
                                      onPressed: () => context.go('/projects'),
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (m.projectProgress.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(child: Text('No active projects')),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: m.projectProgress.take(4).length,
                                    separatorBuilder: (_, __) => const Divider(height: 20),
                                    itemBuilder: (context, idx) {
                                      final item = m.projectProgress[idx];
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.projectTitle,
                                                  style: AppTextStyles.bodyBold(context),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                '${item.progressPercentage.toStringAsFixed(0)}%',
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
                                              value: item.progressPercentage / 100,
                                              minHeight: 6,
                                              backgroundColor: isDark
                                                  ? const Color(0xFF24324D)
                                                  : const Color(0xFFE2E8F0),
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                item.progressPercentage == 100
                                                    ? AppColors.success
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Recent Tasks Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Tasks', style: AppTextStyles.h2(context).copyWith(fontSize: 20)),
                  TextButton(
                    onPressed: () => context.go('/tasks'),
                    child: const Text('View All Tasks'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (m.recentTasks.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No tasks created yet')),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: m.recentTasks.take(4).length,
                  itemBuilder: (context, idx) {
                    final task = m.recentTasks[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskCard(
                        task: task,
                        onTap: () => context.go('/tasks/${task.id}'),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
