import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);
    final authVM = context.read<AuthViewModel>();

    final success = await authVM.updateProfile(
      fullName: _nameController.text.trim(),
      password: _passwordController.text.trim().isNotEmpty ? _passwordController.text : null,
    );
    setState(() => _isUpdating = false);

    if (success && mounted) {
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final themeVM = context.watch<ThemeViewModel>();
    final user = authVM.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account & Security Settings', style: AppTextStyles.h1(context)),
            const SizedBox(height: 4),
            Text(
              'Manage your enterprise credentials, roles, and visual preferences.',
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 24),

            // Profile Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(user?.fullName ?? 'User', style: AppTextStyles.h2(context)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                ),
                                child: Text(
                                  user?.role.displayName.toUpperCase() ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '', style: AppTextStyles.subtitle(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Edit Profile Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Information', style: AppTextStyles.h3(context)),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'New Password (Optional)',
                      hintText: 'Leave blank to keep current password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Save Changes',
                      isLoading: _isUpdating,
                      onPressed: _handleUpdate,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Enterprise Security Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enterprise Security Architecture', style: AppTextStyles.h3(context)),
                    const SizedBox(height: 12),
                    _buildSecurityRow(
                      icon: Icons.vpn_key_rounded,
                      title: 'Authentication Standard',
                      value: 'JWT Access & Refresh Tokens (with Redis Blacklist)',
                      color: AppColors.success,
                    ),
                    const Divider(height: 20),
                    _buildSecurityRow(
                      icon: Icons.shield_rounded,
                      title: 'Role-Based Access Control',
                      value: 'RBAC Active: ${user?.role.displayName}',
                      color: AppColors.primary,
                    ),
                    const Divider(height: 20),
                    _buildSecurityRow(
                      icon: Icons.lock_person_rounded,
                      title: 'Cryptographic Engine',
                      value: 'RSA-OAEP-256 Asymmetric Keypair & Bcrypt',
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preferences & Sign Out Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode Aesthetics'),
                      subtitle: const Text('Toggle between sleek dark and clean light themes'),
                      value: themeVM.isDarkMode,
                      onChanged: (_) => themeVM.toggleTheme(),
                    ),
                    const Divider(height: 16),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                      title: const Text('Sign Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Invalidate current JWT session and clear local tokens'),
                      onTap: () {
                        authVM.logout();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
