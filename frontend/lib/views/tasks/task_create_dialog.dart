import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../models/task_model.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class TaskCreateDialog extends StatefulWidget {
  final int? preselectedProjectId;
  final int? preselectedAssigneeId;

  const TaskCreateDialog({super.key, this.preselectedProjectId, this.preselectedAssigneeId});

  @override
  State<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<TaskCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _hoursController = TextEditingController(text: '4.0');
  int? _selectedProjectId;
  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.medium;
  int? _selectedAssigneeId;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.preselectedProjectId;
    _selectedAssigneeId = widget.preselectedAssigneeId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pVM = context.read<ProjectViewModel>();
      if (pVM.projects.isEmpty) {
        await pVM.fetchProjects();
      }
      await pVM.fetchAvailableUsers();
      if (mounted) {
        if (_selectedProjectId == null && pVM.projects.isNotEmpty) {
          setState(() => _selectedProjectId = pVM.projects.first.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project')),
      );
      return;
    }

    final taskVM = context.read<TaskViewModel>();
    final hours = double.tryParse(_hoursController.text) ?? 0.0;

    final success = await taskVM.createTask(
      projectId: _selectedProjectId!,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      status: _status,
      priority: _priority,
      dueDate: _dueDate,
      estimatedHours: hours,
      assigneeId: _selectedAssigneeId,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = context.watch<ProjectViewModel>();
    final taskVM = context.watch<TaskViewModel>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
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
                    Text('Create Task', style: AppTextStyles.h2(context)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Project Selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Project *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedProjectId ?? (projectVM.projects.isNotEmpty ? projectVM.projects.first.id : null),
                      hint: const Text('Select Project'),
                      items: projectVM.projects.map((p) {
                        return DropdownMenuItem(value: p.id, child: Text(p.title));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedProjectId = val),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _titleController,
                  label: 'Task Title *',
                  hintText: 'e.g. Implement OAuth2 Refresh Interceptor',
                  validator: (v) => Validators.requiredField(v, message: 'Task title is required'),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descController,
                  label: 'Description',
                  hintText: 'Acceptance criteria and technical notes...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Status & Priority
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<TaskStatus>(
                            value: _status,
                            items: TaskStatus.values.map((s) {
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
                          DropdownButtonFormField<TaskPriority>(
                            value: _priority,
                            items: TaskPriority.values.map((p) {
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

                // Assignee & Due Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assignee (Employee)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int?>(
                            value: _selectedAssigneeId,
                            hint: const Text('Unassigned'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                              ...projectVM.availableUsers.map((u) {
                                return DropdownMenuItem<int?>(
                                  value: u.id,
                                  child: Text('${u.fullName} (${u.role.displayName})'),
                                );
                              }),
                            ],
                            onChanged: (val) => setState(() => _selectedAssigneeId = val),
                          ),
                        ],
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
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Text(
                              _dueDate != null
                                  ? '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'
                                  : 'Select date',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 3)),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _dueDate = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _hoursController,
                  label: 'Estimated Hours',
                  keyboardType: TextInputType.number,
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
                      text: 'Create Task',
                      isLoading: taskVM.isLoading,
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
