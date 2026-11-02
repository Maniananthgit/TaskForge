import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import 'edit_user_dialog.dart';
import 'assign_project_dialog.dart';

class UserDetailView extends StatefulWidget {
  final int userId;

  const UserDetailView({super.key, required this.userId});

  @override
  State<UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<UserDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserViewModel>().loadUserDetail(widget.userId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      case UserRole.developer:
        return AppColors.info;
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

  void _showAssignProjectDialog(UserModel user) async {
    final existingIds = user.assignedProjects.map((p) => p.projectId).toList();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AssignProjectDialog(
        userId: user.id,
        existingProjectIds: existingIds,
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project assigned successfully.'),
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final userVM = context.read<UserViewModel>();
                    final ok = await userVM.updateUserRole(user.id, selected);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userVM.successMessage ?? 'Role updated.'),
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
                  child: const Text('Confirm Change'),
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
                  Text('Select the operational account status for ${user.fullName}:'),
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final userVM = context.read<UserViewModel>();
                    final ok = await userVM.updateUserStatus(user.id, selected);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userVM.successMessage ?? 'Status updated.'),
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
                  child: const Text('Confirm Status'),
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
        title: const Text('Deactivate & Archive User?'),
        content: Text(
          'Are you sure you want to delete ${user.fullName} (${user.email})? '
          'Their assigned projects and tasks will be preserved, but they will no longer be able to log in.',
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
                context.go('/users');
              }
            },
            child: const Text('Archive User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userVM = context.watch<UserViewModel>();
    final user = userVM.selectedUser;

    if (userVM.isLoading && user == null) {
      return const Scaffold(body: LoadingView(message: 'Loading user details...'));
    }

    if (user == null) {
      return Scaffold(
        body: ErrorView(
          message: userVM.errorMessage ?? 'User not found.',
          onRetry: () => userVM.loadUserDetail(widget.userId),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button Row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/users'),
                ),
                const SizedBox(width: 8),
                Text('Back to User Management', style: AppTextStyles.bodyMedium(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Top Profile Banner Card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(user.fullName, style: AppTextStyles.h1(context)),
                                const SizedBox(width: 12),
                                // Role Badge
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
                                const SizedBox(width: 8),
                                // Status Badge
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
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(user.email, style: AppTextStyles.bodyMedium(context)),
                                if (user.phoneNumber != null) ...[
                                  const SizedBox(width: 16),
                                  const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(user.phoneNumber!, style: AppTextStyles.bodyMedium(context)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (user.department != null) ...[
                                  const Icon(Icons.business_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(user.department!, style: AppTextStyles.caption(context)),
                                  const SizedBox(width: 16),
                                ],
                                if (user.jobTitle != null) ...[
                                  const Icon(Icons.work_outline_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(user.jobTitle!, style: AppTextStyles.caption(context)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Quick Action Buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit Profile'),
                            onPressed: () => _showEditDialog(user),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text('Change Role'),
                            onPressed: () => _showRoleChangeDialog(user),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.toggle_on_outlined, size: 16),
                            label: const Text('Status'),
                            onPressed: () => _showStatusChangeDialog(user),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.vpn_key_outlined, size: 16),
                            label: const Text('Reset Password'),
                            onPressed: () => _handleResetPassword(user),
                          ),
                          if (user.status == UserStatus.pendingInvitation)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                              icon: const Icon(Icons.mail_outline_rounded, size: 16, color: Colors.white),
                              label: const Text('Resend Invite', style: TextStyle(color: Colors.white)),
                              onPressed: () async {
                                final ok = await userVM.resendInvitation(user.id);
                                if (ok && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('New invitation token generated and dispatched.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                            tooltip: 'Archive User',
                            onPressed: () => _handleSoftDelete(user),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Invitation Banner
                  if (user.status == UserStatus.pendingInvitation) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Invitation pending acceptance. Token expires at: '
                              '${user.invitationExpiresAt?.toLocal().toString().split('.')[0] ?? '24 hours from issue'}',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tabs Header
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('Assigned Projects (${userVM.selectedUserProjects.length})'),
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Security & Activity Audit (${userVM.selectedUserAuditLogs.length})'),
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
                  // 1. Projects Tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Project Memberships', style: AppTextStyles.h2(context)),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Assign to Project'),
                            onPressed: () => _showAssignProjectDialog(user),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (userVM.selectedUserProjects.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text('No projects currently assigned.', style: AppTextStyles.bodyMedium(context)),
                              const SizedBox(height: 6),
                              Text('Assign this user to projects to grant workspace access.', style: AppTextStyles.caption(context)),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: userVM.selectedUserProjects.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final proj = userVM.selectedUserProjects[index];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.folder_rounded, color: AppColors.primary, size: 22),
                                  ),
                                  title: Text(proj.projectTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Role: ${proj.roleInProject}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
                                    tooltip: 'Remove from project',
                                    onPressed: () async {
                                      final ok = await userVM.removeProject(user.id, proj.projectId);
                                      if (ok && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Removed from project.')),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  // 2. Audit Trail Tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Security & Activity Trail', style: AppTextStyles.h2(context)),
                      const SizedBox(height: 6),
                      Text('Immutable audit records for compliance and security forensics.', style: AppTextStyles.caption(context)),
                      const SizedBox(height: 16),
                      if (userVM.selectedUserAuditLogs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text('No activity records logged yet.', style: AppTextStyles.bodyMedium(context)),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: userVM.selectedUserAuditLogs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final log = userVM.selectedUserAuditLogs[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: const Icon(Icons.verified_user_rounded, size: 16, color: AppColors.primary),
                                ),
                                title: Text(
                                  'Action: ${log.action}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (log.actorName != null) Text('Performed by: ${log.actorName}'),
                                    if (log.details != null && log.details!.isNotEmpty)
                                      Text('Details: ${log.details}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                                    if (log.ipAddress != null) Text('IP: ${log.ipAddress}', style: AppTextStyles.caption(context)),
                                  ],
                                ),
                                trailing: Text(
                                  log.createdAt.toLocal().toString().split('.')[0],
                                  style: AppTextStyles.caption(context),
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
}
