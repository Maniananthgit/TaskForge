import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';

class EditUserDialog extends StatefulWidget {
  final UserModel user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _departmentController;
  late final TextEditingController _jobTitleController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phoneNumber ?? '');
    _departmentController = TextEditingController(text: widget.user.department ?? '');
    _jobTitleController = TextEditingController(text: widget.user.jobTitle ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final userVM = context.read<UserViewModel>();

    final success = await userVM.updateUserProfile(
      widget.user.id,
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      department: _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : null,
      jobTitle: _jobTitleController.text.trim().isNotEmpty ? _jobTitleController.text.trim() : null,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
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
                        child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit User Profile', style: AppTextStyles.h2(context)),
                          const SizedBox(height: 2),
                          Text(widget.user.email, style: AppTextStyles.caption(context)),
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

              // Fields
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
              const SizedBox(height: 16),

              Row(
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
                            hintText: 'Engineering',
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
                            hintText: 'Lead Developer',
                            prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('Phone Number', style: AppTextStyles.bodyMedium(context)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: '+1 555-0100',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
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
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes'),
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
