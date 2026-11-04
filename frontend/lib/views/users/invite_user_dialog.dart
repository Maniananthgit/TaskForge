import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';

class InviteUserDialog extends StatefulWidget {
  const InviteUserDialog({super.key});

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController(text: 'TaskForge Technologies');
  final _departmentController = TextEditingController();
  final _jobTitleController = TextEditingController();

  UserRole _selectedRole = UserRole.developer;
  final List<int> _selectedProjectIds = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().fetchProjects(page: 1);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _departmentController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final userVM = context.read<UserViewModel>();

    final success = await userVM.inviteUser(
      email: _emailController.text.trim(),
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
      phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
      department: _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : null,
      jobTitle: _jobTitleController.text.trim().isNotEmpty ? _jobTitleController.text.trim() : null,
      assignedProjectIds: _selectedProjectIds.isNotEmpty ? _selectedProjectIds : null,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectVM = context.watch<ProjectViewModel>();
    final projects = projectVM.projects;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 750),
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                        child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite Team Member', style: AppTextStyles.h2(context)),
                          const SizedBox(height: 2),
                          Text(
                            'Send a secure invitation link to join the organization.',
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

              // Form Body (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name & Email Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Full Name *', style: AppTextStyles.bodyMedium(context)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Jane Doe',
                                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Email Address *', style: AppTextStyles.bodyMedium(context)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    hintText: 'user@company.com',
                                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Email is required';
                                    if (!v.contains('@') || !v.contains('.')) return 'Invalid email address';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Role Selector
                      Text('System Role *', style: AppTextStyles.bodyMedium(context)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<UserRole>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 20),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: UserRole.developer,
                            child: Row(
                              children: [
                                const Icon(Icons.code_rounded, size: 18, color: AppColors.info),
                                const SizedBox(width: 8),
                                Text(UserRole.developer.displayName),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRole.projectManager,
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_ind_outlined, size: 18, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Text(UserRole.projectManager.displayName),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRole.admin,
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(UserRole.admin.displayName),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedRole = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Company / Organization
                      Text('Company / Organization', style: AppTextStyles.bodyMedium(context)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _companyController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. TaskForge Technologies',
                          prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Department & Job Title Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Department', style: AppTextStyles.bodyMedium(context)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _departmentController,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Engineering',
                                    prefixIcon: Icon(Icons.business_outlined, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Job Title', style: AppTextStyles.bodyMedium(context)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _jobTitleController,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Senior Architect',
                                    prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      Text('Phone Number', style: AppTextStyles.bodyMedium(context)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          hintText: '+1 555-0199',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Assign Projects Section
                      if (projects.isNotEmpty) ...[
                        Text('Assign to Projects (Optional)', style: AppTextStyles.bodyMedium(context)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(10),
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          ),
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: projects.length,
                            itemBuilder: (context, index) {
                              final proj = projects[index];
                              final isChecked = _selectedProjectIds.contains(proj.id);
                              return CheckboxListTile(
                                dense: true,
                                title: Text(proj.title, style: AppTextStyles.bodyMedium(context)),
                                subtitle: Text(proj.status.displayName, style: AppTextStyles.caption(context)),
                                value: isChecked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProjectIds.add(proj.id);
                                    } else {
                                      _selectedProjectIds.remove(proj.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Sending Invite...' : 'Send Invitation'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
