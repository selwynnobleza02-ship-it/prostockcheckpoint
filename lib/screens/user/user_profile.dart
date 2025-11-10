import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/models/user_role.dart';
import 'package:prostock/providers/theme_provider.dart';
import 'package:prostock/screens/settings/components/change_password_screen.dart';
import 'package:prostock/screens/user/profile/components/profile_action.dart';

class UserProfile extends StatelessWidget {
  const UserProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.teal.withValues(alpha: 0.3)
                          : Colors.teal[100],
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.teal[200]
                            : Colors.teal[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      authProvider.username ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (authProvider.userRole ?? UserRole.user) ==
                                UserRole.admin
                            ? Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : Colors.blue.withValues(alpha: 0.1)
                            : Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (authProvider.userRole ?? UserRole.user).displayName,
                        style: TextStyle(
                          color:
                              (authProvider.userRole ?? UserRole.user) ==
                                  UserRole.admin
                              ? Theme.of(context).brightness == Brightness.dark
                                    ? Colors.blue[300]
                                    : Colors.blue
                              : Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ProfileAction(
                title: 'Change Password',
                subtitle: 'Update your account password',
                icon: Icons.lock,
                onTap: () => _showChangePasswordDialog(context),
              ),
              const SizedBox(height: 12),
              ProfileAction(
                title: 'Appearance',
                subtitle: 'Customize app theme',
                icon: Icons.palette_outlined,
                onTap: () => _showAppearanceDialog(context),
              ),
              const SizedBox(height: 12),
              ProfileAction(
                title: 'Help & Support',
                subtitle: 'Get help with using the app',
                icon: Icons.help,
                onTap: () => _showHelpDialog(context),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For assistance, please contact your system administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAppearanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        return AlertDialog(
          title: const Text('Appearance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context: context,
                title: 'Light Mode',
                icon: Icons.light_mode,
                isSelected: themeProvider.themeMode == ThemeMode.light,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context: context,
                title: 'Dark Mode',
                icon: Icons.dark_mode,
                isSelected: themeProvider.themeMode == ThemeMode.dark,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.dark);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context: context,
                title: 'System Default',
                icon: Icons.brightness_auto,
                isSelected: themeProvider.themeMode == ThemeMode.system,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.1)
              : isDarkMode
              ? Colors.grey[800]
              : null,
          border: isSelected
              ? Border.all(color: primaryColor)
              : Border.all(
                  color: isDarkMode
                      ? Colors.grey[700]!.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryColor : null),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : null,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: primaryColor),
          ],
        ),
      ),
    );
  }
}
