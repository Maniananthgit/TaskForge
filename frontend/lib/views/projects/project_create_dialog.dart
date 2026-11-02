import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../models/project_model.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProjectCreateDialog extends StatefulWidget {
  const ProjectCreateDialog({super.key});

  @override
  State<ProjectCreateDialog> createState() => _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends State<ProjectCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController(text: '80.0');
  ProjectStatus _status = ProjectStatus.planning;
  ProjectPriority _priority = ProjectPriority.medium;
  DateTime? _dueDate;
  final List<int> _selectedMemberIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().fetchAvailableUsers();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<ProjectViewModel>();
    final budget = double.tryParse(_budgetController.text) ?? 0.0;

    final success = await vm.createProject(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      status: _status,
      priority: _priority,
      dueDate: _dueDate,
      budgetHours: budget,
      memberIds: _selectedMemberIds,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = context.watch<ProjectViewModel>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Create New Project', style: AppTextStyles.h2(context)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _titleController,
                  label: 'Project Title *',
                  hintText: 'e.g. Mobile Banking App Redesign',
                  validator: (v) => Validators.requiredField(v, message: 'Project title is required'),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descController,
                  label: 'Description',
                  hintText: 'Objectives, scope, and deliverables...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<ProjectStatus>(
                            value: _status,
                            items: ProjectStatus.values.map((s) {
                              return DropdownMenuItem(value: s, child: Text(s.displayName));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<ProjectPriority>(
                            value: _priority,
                            items: ProjectPriority.values.map((p) {
                              return DropdownMenuItem(value: p, child: Text(p.displayName));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _priority = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _budgetController,
                        label: 'Estimated Budget (Hours)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.calendar_month_outlined, size: 18),
                            label: Text(
                              _dueDate != null
                                  ? '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'
                                  : 'Select date',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 14)),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                              );
                              if (picked != null) setState(() => _dueDate = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Assign Members Multi-select
                const Text('Assign Team Members', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                if (projectVM.availableUsers.isEmpty)
                  Text('No team members found', style: AppTextStyles.caption(context))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: projectVM.availableUsers.map((u) {
                      final isSelected = _selectedMemberIds.contains(u.id);
                      return FilterChip(
                        label: Text('${u.fullName} (${u.role.displayName})'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedMemberIds.add(u.id);
                            } else {
                              _selectedMemberIds.remove(u.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    CustomButton(
                      text: 'Create Project',
                      isLoading: projectVM.isLoading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
