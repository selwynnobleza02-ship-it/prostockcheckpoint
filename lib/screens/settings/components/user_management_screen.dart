import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/models/user_role.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/screens/settings/components/system_monitoring_widget.dart';
import 'package:prostock/screens/settings/components/app_update_widget.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return StreamBuilder<List<AppUser>>(
                    stream: authProvider.getAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: \${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      final users = snapshot.data!;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            title: Text(user.email),
                            subtitle: Text(
                              user.role.toString().split('.').last,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editUserRole(context, user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteUser(context, user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.vpn_key),
                                  onPressed: () =>
                                      _resetPassword(context, user),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              const SystemMonitoringWidget(),
              const SizedBox(height: 20),
              const AppUpdateWidget(),
            ],
          ),
        ),
      ),
    );
  }

  void _editUserRole(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) {
        UserRole selectedRole = user.role;
        return AlertDialog(
          title: const Text('Edit User Role'),
          content: DropdownButton<UserRole>(
            value: selectedRole,
            onChanged: (UserRole? newValue) {
              if (newValue != null) {
                selectedRole = newValue;
              }
            },
            items: UserRole.values.map((UserRole role) {
              return DropdownMenuItem<UserRole>(
                value: role,
                child: Text(role.toString().split('.').last),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final authProvider = context.read<AuthProvider>();
                authProvider.updateUserRole(user, selectedRole);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteUser(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete \${user.email}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final authProvider = context.read<AuthProvider>();
                authProvider.deleteUser(user);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _resetPassword(BuildContext context, AppUser user) async {
    final authProvider = context.read<AuthProvider>();
    final error = await authProvider.sendPasswordResetEmail(user.email);
    if (!context.mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'Password reset email sent to \${user.email}'
                : 'Failed to send password reset email: $error',
          ),
        ),
      );
    }
  }
}
