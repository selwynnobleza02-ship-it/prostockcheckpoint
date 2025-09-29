import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/models/user_role.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/screens/settings/components/app_update_widget.dart';
import 'package:prostock/screens/settings/components/create_user_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _showInactiveUsers = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _showCreateUserDialog(context),
                  tooltip: 'Add New User',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // SECURITY CHECK - Only admins can access user management
          if (!authProvider.isAdmin) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You do not have permission to access this page.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'User Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Switch(
                            value: _showInactiveUsers,
                            onChanged: (value) {
                              setState(() {
                                _showInactiveUsers = value;
                              });
                            },
                          ),
                          const Text('Show Inactive'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<AppUser>>(
                    stream: authProvider.getAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      final allUsers = snapshot.data!;
                      final users = _showInactiveUsers
                          ? allUsers
                          : allUsers.where((user) => user.isActive).toList();

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isCurrentUser =
                              user.id == authProvider.currentUser?.id;
                          final isLastAdmin =
                              user.role == UserRole.admin &&
                              allUsers
                                      .where(
                                        (u) =>
                                            u.role == UserRole.admin &&
                                            u.isActive,
                                      )
                                      .length ==
                                  1;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: !user.isActive ? Colors.grey[100] : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: user.role == UserRole.admin
                                    ? Colors.blue
                                    : Colors.grey,
                                child: Icon(
                                  user.role == UserRole.admin
                                      ? Icons.admin_panel_settings
                                      : Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                user.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.email),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: user.role == UserRole.admin
                                              ? Colors.blue.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          user.role.displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: user.role == UserRole.admin
                                                ? Colors.blue
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'You',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (!user.isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Inactive',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isCurrentUser) ...[
                                    if (user.isActive) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () =>
                                            _editUserRole(context, user),
                                        tooltip: 'Edit Role',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isLastAdmin
                                              ? Icons.block
                                              : Icons.delete,
                                          color: isLastAdmin
                                              ? Colors.grey
                                              : null,
                                        ),
                                        onPressed: isLastAdmin
                                            ? null
                                            : () => _deleteUser(context, user),
                                        tooltip: isLastAdmin
                                            ? 'Cannot delete last admin'
                                            : 'Deactivate User',
                                      ),
                                    ] else ...[
                                      IconButton(
                                        icon: const Icon(Icons.restore),
                                        onPressed: () =>
                                            _restoreUser(context, user),
                                        tooltip: 'Restore User',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever),
                                        onPressed: () =>
                                            _hardDeleteUser(context, user),
                                        tooltip: 'Permanently Delete',
                                      ),
                                    ],
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.vpn_key),
                                    onPressed: () =>
                                        _resetPassword(context, user),
                                    tooltip: 'Reset Password',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const AppUpdateWidget(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _editUserRole(BuildContext context, AppUser user) async {
    UserRole selectedRole = user.role;
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Role for ${user.username}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Current role: ${user.role.displayName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Select New Role',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (UserRole? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedRole = newValue;
                        });
                      }
                    },
                    items: UserRole.values.map((UserRole role) {
                      return DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.displayName),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedRole != user.role
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Update Role'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedRole != user.role) {
      final success = await authProvider.updateUserRole(user, selectedRole);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'User role updated successfully'
                  : 'Failed to update user role',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _deleteUser(BuildContext context, AppUser user) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete this user?'),
              const SizedBox(height: 8),
              Text(
                'Username: ${user.username}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Email: ${user.email}'),
              Text('Role: ${user.role.displayName}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone!',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete User'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final success = await authProvider.deleteUser(user);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'User deleted successfully' : 'Failed to delete user',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _resetPassword(BuildContext context, AppUser user) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send password reset email to:'),
              const SizedBox(height: 8),
              Text(
                user.email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The user will receive an email with instructions to reset their password.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send Reset Email'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final error = await authProvider.sendPasswordResetEmail(user.email);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              error == null
                  ? 'Password reset email sent to ${user.email}'
                  : 'Failed to send password reset email: $error',
            ),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _restoreUser(BuildContext context, AppUser user) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to restore this user?'),
              const SizedBox(height: 8),
              Text(
                'Username: ${user.username}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Email: ${user.email}'),
              Text('Role: ${user.role.displayName}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore User'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final success = await authProvider.restoreUser(user);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'User restored successfully' : 'Failed to restore user',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _hardDeleteUser(BuildContext context, AppUser user) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permanently Delete User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to PERMANENTLY delete this user?'),
              const SizedBox(height: 8),
              Text(
                'Username: ${user.username}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Email: ${user.email}'),
              Text('Role: ${user.role.displayName}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is IRREVERSIBLE! The user will be permanently removed from the system.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Forever'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final success = await authProvider.hardDeleteUser(user);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'User permanently deleted' : 'Failed to delete user',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateUserDialog(),
    );
  }
}
