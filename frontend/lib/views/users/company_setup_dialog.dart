import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../viewmodels/user_viewmodel.dart';

class CompanySetupDialog extends StatefulWidget {
  const CompanySetupDialog({super.key});

  @override
  State<CompanySetupDialog> createState() => _CompanySetupDialogState();
}

class _CompanySetupDialogState extends State<CompanySetupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyNameController;
  late final TextEditingController _industryController;
  late final TextEditingController _websiteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final userVM = context.read<UserViewModel>();
    final firstCompany = userVM.users.isNotEmpty
        ? (userVM.users.first.company ?? 'TaskForge Technologies')
        : 'TaskForge Technologies';
    _companyNameController = TextEditingController(text: firstCompany);
    _industryController = TextEditingController(text: 'Software & Technology');
    _websiteController = TextEditingController(text: 'https://taskforge.internal');
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final userVM = context.read<UserViewModel>();
    final newCompany = _companyNameController.text.trim();

    // Update company name across users
    for (final user in userVM.users) {
      await userVM.updateUserProfile(
        user.id,
        company: newCompany,
      );
    }

    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userVM = context.watch<UserViewModel>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
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
                        child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Company & Organization Setup', style: AppTextStyles.h2(context)),
                          const SizedBox(height: 2),
                          Text(
                            'Manage enterprise organization details and workforce affiliation',
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
              const SizedBox(height: 24),

              // Company Name Field
              Text('Company / Organization Name *', style: AppTextStyles.bodyMedium(context)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Acme Corporation or TaskForge Tech',
                  prefixIcon: Icon(Icons.business_rounded, size: 20),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required' : null,
              ),
              const SizedBox(height: 16),

              // Industry & Website Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Industry Domain', style: AppTextStyles.bodyMedium(context)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _industryController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Technology & SaaS',
                            prefixIcon: Icon(Icons.category_outlined, size: 20),
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
                        Text('Website / Portal', style: AppTextStyles.bodyMedium(context)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _websiteController,
                          decoration: const InputDecoration(
                            hintText: 'https://company.com',
                            prefixIcon: Icon(Icons.language_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This company name will be applied to all current ${userVM.users.length} members and set as default for newly invited users.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveCompany,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Company Settings'),
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

