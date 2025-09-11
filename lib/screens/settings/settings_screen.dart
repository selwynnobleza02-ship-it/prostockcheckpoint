import 'package:prostock/widgets/sync_failure_dialog.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:flutter/material.dart';
import 'package:prostock/providers/theme_provider.dart';
import 'package:prostock/screens/settings/components/about_screen.dart';
import 'package:prostock/screens/settings/components/user_management_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'components/change_password_screen.dart';
import 'components/printer_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            onTap: () {
              _showThemeDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Printer Settings'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrinterSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('User Management'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          Consumer<SyncFailureProvider>(
            builder: (context, syncFailureProvider, child) {
              return ListTile(
                leading: Badge(
                  isLabelVisible: syncFailureProvider.failures.isNotEmpty,
                  label: Text(syncFailureProvider.failures.length.toString()),
                  child: const Icon(Icons.sync_problem_outlined),
                ),
                title: const Text('Sync Failures'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SyncFailureDialog(),
                  );
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              final authProvider = context.read<AuthProvider>();
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Theme'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setThemeMode(ThemeMode.light);
                Navigator.of(context).pop();
              },
              child: const Text('Light'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setThemeMode(ThemeMode.dark);
                Navigator.of(context).pop();
              },
              child: const Text('Dark'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setThemeMode(ThemeMode.system);
                Navigator.of(context).pop();
              },
              child: const Text('System Default'),
            ),
          ],
        );
      },
    );
  }
}
