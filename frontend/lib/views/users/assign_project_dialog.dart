import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';

class AssignProjectDialog extends StatefulWidget {
  final int userId;
  final String? userName;
  final List<int> existingProjectIds;

  const AssignProjectDialog({
    super.key,
    required this.userId,
    this.userName,
    required this.existingProjectIds,
  });

  @override
  State<AssignProjectDialog> createState() => _AssignProjectDialogState();
}

class _AssignProjectDialogState extends State<AssignProjectDialog> {
  int? _selectedProjectId;
  String _selectedRole = 'Member';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().fetchProjects(page: 1);
    });
  }

  Future<void> _submit() async {
    if (_selectedProjectId == null) return;

    setState(() => _isSubmitting = true);
    final userVM = context.read<UserViewModel>();

    final success = await userVM.assignProject(
      widget.userId,
      _selectedProjectId!,
      roleInProject: _selectedRole,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = context.watch<ProjectViewModel>();
    final availableProjects = projectVM.projects
        .where((p) => !widget.existingProjectIds.contains(p.id))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_shared_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign to Project', style: AppTextStyles.h2(context)),
                        const SizedBox(height: 2),
                        Text(
                          widget.userName != null
                              ? 'Assign ${widget.userName} to a workspace project.'
                              : 'Add user as an active project contributor.',
                          style: AppTextStyles.caption(context),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            if (availableProjects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'All available projects are already assigned to this user.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                ),
              )
            else ...[
              Text('Select Project *', style: AppTextStyles.bodyMedium(context)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _selectedProjectId,
                hint: const Text('Choose a project...'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.folder_outlined, size: 20),
                ),
                items: availableProjects.map((p) {
                  return DropdownMenuItem<int>(
                    value: p.id,
                    child: Text(p.title),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedProjectId = v),
              ),
              const SizedBox(height: 16),

              Text('Role in Project *', style: AppTextStyles.bodyMedium(context)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'Lead', child: Text('Lead')),
                  DropdownMenuItem(value: 'Member', child: Text('Member')),
                  DropdownMenuItem(value: 'Contributor', child: Text('Contributor')),
                  DropdownMenuItem(value: 'Viewer', child: Text('Viewer')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRole = v);
                },
              ),
            ],

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting || _selectedProjectId == null ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Assign Project'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
