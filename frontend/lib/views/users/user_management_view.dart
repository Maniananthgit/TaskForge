import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/empty_view.dart';
import 'invite_user_dialog.dart';
import 'edit_user_dialog.dart';
import 'company_setup_dialog.dart';
import '../tasks/task_create_dialog.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserViewModel>().loadUsers(page: 1, refreshMetrics: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return AppColors.success;
      case UserStatus.pendingInvitation:
        return AppColors.warning;
      case UserStatus.inactive:
        return Colors.grey;
      case UserStatus.suspended:
      case UserStatus.deleted:
        return AppColors.error;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.primary;
      case UserRole.projectManager:
        return AppColors.warning;
      case UserRole.employee:
      case UserRole.developer:
        return AppColors.info;
      case UserRole.client:
        return Colors.teal;
    }
  }

  void _showInviteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const InviteUserDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showCompanySetupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const CompanySetupDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company settings saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showEditDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditUserDialog(user: user),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User profile updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showAssignTaskDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => TaskCreateDialog(preselectedAssigneeId: user.id),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task assigned to ${user.fullName} successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showRoleChangeDialog(UserModel user) {
    UserRole selected = user.role;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Change User Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select the new authorization role for ${user.fullName}:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    value: selected,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.security_outlined),
                    ),
                    items: UserRole.values.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r.displayName));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selected = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final userVM = context.read<UserViewModel>();
                    final ok = await userVM.updateUserRole(user.id, selected);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userVM.successMessage ?? 'Role updated successfully.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (mounted && userVM.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userVM.errorMessage!),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatusChangeDialog(UserModel user) {
    UserStatus selected = user.status;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Change Account Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select the status for ${user.fullName}:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserStatus>(
                    value: selected,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.toggle_on_outlined),
                    ),
                    items: [
                      UserStatus.active,
                      UserStatus.inactive,
                      UserStatus.suspended,
                    ].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.displayName));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selected = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final userVM = context.read<UserViewModel>();
                    final ok = await userVM.updateUserStatus(user.id, selected);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userVM.successMessage ?? 'Status updated successfully.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (mounted && userVM.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userVM.errorMessage!),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleResetPassword(UserModel user) async {
    final userVM = context.read<UserViewModel>();
    final token = await userVM.resetPassword(user.id);
    if (!mounted) return;

    if (token != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.vpn_key_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Password Reset Token Generated'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A single-use password reset token has been issued for this user:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: SelectableText(
                  token,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Token expires in 24 hours. The user can reset their password via this link token.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Token'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset token copied to clipboard!')),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else if (userVM.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userVM.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleSoftDelete(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive User Account?'),
        content: Text(
          'Are you sure you want to deactivate and soft-delete ${user.fullName} (${user.email})? '
          'Their assigned projects and tasks will remain intact.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final userVM = context.read<UserViewModel>();
              final ok = await userVM.softDeleteUser(user.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User account archived.')),
                );
              }
            },
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTextStyles.caption(context)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: AppTextStyles.h1(context).copyWith(fontSize: 26, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AppTextStyles.caption(context).copyWith(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userVM = context.watch<UserViewModel>();
    final metrics = userVM.metrics;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => userVM.loadUsers(page: userVM.currentPage, refreshMetrics: true),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text('Admin Console — User & Company Setup', style: AppTextStyles.h1(context)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Setup, add, update, and delete enterprise members, authorization roles, and company settings.',
                        style: AppTextStyles.bodyMedium(context).copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showCompanySetupDialog,
                        icon: const Icon(Icons.apartment_rounded, size: 18),
                        label: const Text('Company Setup'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showInviteDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('+ Add New User'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Metrics Row
              if (isDesktop)
                Row(
                  children: [
                    _buildMetricCard(
                      context: context,
                      title: 'Total Accounts',
                      value: '${metrics.totalUsers}',
                      icon: Icons.people_outline_rounded,
                      color: AppColors.primary,
                      subtitle: '${metrics.adminsCount} Admins · ${metrics.projectManagersCount} PMs · ${metrics.developersCount} Devs',
                    ),
                    const SizedBox(width: 14),
                    _buildMetricCard(
                      context: context,
                      title: 'Active Users',
                      value: '${metrics.activeUsers}',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      subtitle: 'Operational & authenticated',
                    ),
                    const SizedBox(width: 14),
                    _buildMetricCard(
                      context: context,
                      title: 'Pending Invitations',
                      value: '${metrics.pendingInvitations}',
                      icon: Icons.mail_outline_rounded,
                      color: AppColors.warning,
                      subtitle: 'Awaiting first password set',
                    ),
                    const SizedBox(width: 14),
                    _buildMetricCard(
                      context: context,
                      title: 'Inactive / Suspended',
                      value: '${metrics.inactiveUsers + metrics.suspendedUsers}',
                      icon: Icons.block_rounded,
                      color: AppColors.error,
                      subtitle: '${metrics.suspendedUsers} Suspended · ${metrics.inactiveUsers} Inactive',
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricCard(
                      context: context,
                      title: 'Total Users',
                      value: '${metrics.totalUsers}',
                      icon: Icons.people_outline_rounded,
                      color: AppColors.primary,
                    ),
                    _buildMetricCard(
                      context: context,
                      title: 'Active Users',
                      value: '${metrics.activeUsers}',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Search & Filters Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, department, or job title...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    userVM.setSearch(null);
                                  },
                                )
                              : null,
                          isDense: true,
                        ),
                        onSubmitted: (v) => userVM.setSearch(v),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Role Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<UserRole?>(
                        value: userVM.selectedRoleFilter,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.shield_outlined, size: 20),
                        ),
                        hint: const Text('All Roles'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Roles')),
                          ...UserRole.values.map(
                            (r) => DropdownMenuItem(value: r, child: Text(r.displayName)),
                          ),
                        ],
                        onChanged: (v) => userVM.setRoleFilter(v),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Status Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<UserStatus?>(
                        value: userVM.selectedStatusFilter,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.filter_list_rounded, size: 20),
                        ),
                        hint: const Text('All Statuses'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Statuses')),
                          ...[
                            UserStatus.active,
                            UserStatus.pendingInvitation,
                            UserStatus.inactive,
                            UserStatus.suspended,
                          ].map(
                            (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                          ),
                        ],
                        onChanged: (v) => userVM.setStatusFilter(v),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Refresh Button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh Users',
                      onPressed: () => userVM.loadUsers(page: userVM.currentPage, refreshMetrics: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Users Data Table Container
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    if (userVM.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: LoadingView(message: 'Loading enterprise users...'),
                      )
                    else if (userVM.users.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: EmptyView(
                          title: 'No Users Found',
                          message: 'No users found matching your criteria.',
                          buttonText: 'Clear Filters',
                          onButtonPressed: () {
                            _searchController.clear();
                            userVM.setSearch(null);
                            userVM.setRoleFilter(null);
                            userVM.setStatusFilter(null);
                          },
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          horizontalMargin: 20,
                          headingRowHeight: 48,
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 64,
                          columns: const [
                            DataColumn(label: Text('USER', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ROLE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('DEPARTMENT / TITLE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LAST LOGIN', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: userVM.users.map((user) {
                            return DataRow(
                              cells: [
                                // User Name & Email
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary.withOpacity(0.12),
                                        child: Text(
                                          user.fullName.isNotEmpty
                                              ? user.fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () => context.go('/users/${user.id}'),
                                            child: Text(
                                              user.fullName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                            ),
                                          ),
                                          Text(user.email, style: AppTextStyles.caption(context)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Role Badge
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(user.role).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      user.role.displayName,
                                      style: TextStyle(
                                        color: _getRoleColor(user.role),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                // Status Badge
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(user.status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _getStatusColor(user.status),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          user.status.displayName,
                                          style: TextStyle(
                                            color: _getStatusColor(user.status),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Department, Title & Company
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.jobTitle ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      Text(
                                        '${user.company ?? "TaskForge"} • ${user.department ?? "Engineering"}',
                                        style: AppTextStyles.caption(context),
                                      ),
                                    ],
                                  ),
                                ),

                                // Last Login
                                DataCell(
                                  Text(
                                    user.lastLoginAt != null
                                        ? user.lastLoginAt!.toLocal().toString().split('.')[0]
                                        : 'Never',
                                    style: AppTextStyles.caption(context),
                                  ),
                                ),

                                // Actions Menu with Direct Quick Action Buttons
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Direct Update / Edit Profile Button
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                        tooltip: 'Update / Edit Profile & Company',
                                        onPressed: () => _showEditDialog(user),
                                      ),
                                      // 2. Direct Assign Task Button
                                      IconButton(
                                        icon: const Icon(Icons.assignment_ind_outlined, size: 18, color: AppColors.info),
                                        tooltip: 'Assign Task',
                                        onPressed: () => _showAssignTaskDialog(user),
                                      ),
                                      // 3. Direct Role Change Button
                                      IconButton(
                                        icon: const Icon(Icons.shield_outlined, size: 18, color: AppColors.warning),
                                        tooltip: 'Change Authorization Role',
                                        onPressed: () => _showRoleChangeDialog(user),
                                      ),
                                      // 4. Direct Delete / Archive Button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                        tooltip: 'Delete / Archive User',
                                        onPressed: () => _handleSoftDelete(user),
                                      ),
                                      // 5. Overflow menu for Status, Password Reset, Audit
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                                        tooltip: 'More Setup Options',
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'details':
                                              context.go('/users/${user.id}');
                                              break;
                                            case 'assign_task':
                                              _showAssignTaskDialog(user);
                                              break;
                                            case 'edit':
                                              _showEditDialog(user);
                                              break;
                                            case 'role':
                                              _showRoleChangeDialog(user);
                                              break;
                                            case 'status':
                                              _showStatusChangeDialog(user);
                                              break;
                                            case 'resend':
                                              userVM.resendInvitation(user.id);
                                              break;
                                            case 'reset_pass':
                                              _handleResetPassword(user);
                                              break;
                                            case 'delete':
                                              _handleSoftDelete(user);
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: ListTile(
                                              leading: Icon(Icons.visibility_outlined, size: 18),
                                              title: Text('View Profile & Audit'),
                                              dense: true,
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'status',
                                            child: ListTile(
                                              leading: Icon(Icons.toggle_on_outlined, size: 18),
                                              title: Text('Change Status (Active/Inactive)'),
                                              dense: true,
                                            ),
                                          ),
                                          if (user.status == UserStatus.pendingInvitation)
                                            const PopupMenuItem(
                                              value: 'resend',
                                              child: ListTile(
                                                leading: Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.warning),
                                                title: Text('Resend Invitation'),
                                                dense: true,
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'reset_pass',
                                            child: ListTile(
                                              leading: Icon(Icons.vpn_key_outlined, size: 18),
                                              title: Text('Issue Password Reset'),
                                              dense: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                    // Pagination Footer
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${userVM.users.length} of ${userVM.totalUsers} users',
                            style: AppTextStyles.caption(context),
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                                label: const Text('Previous'),
                                onPressed: userVM.currentPage > 1
                                    ? () => userVM.setPage(userVM.currentPage - 1)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Page ${userVM.currentPage} of ${userVM.totalPages}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                label: const Text('Next'),
                                onPressed: userVM.currentPage < userVM.totalPages
                                    ? () => userVM.setPage(userVM.currentPage + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
