import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/password_helper.dart';
import '../../../widgets/enhanced_text_field.dart';
import '../../../widgets/password_strength_checklist.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String _newPassword = '';
  String _confirmPassword = '';
  bool _showNewPasswordChecklist = false;
  bool _showConfirmPasswordValidation = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onNewPasswordChanged() {
    setState(() {
      _newPassword = _newPasswordController.text;
      _showNewPasswordChecklist = _newPassword.isNotEmpty;
    });
    _validateForm();
  }

  void _onConfirmPasswordChanged() {
    setState(() {
      _confirmPassword = _confirmPasswordController.text;
      _showConfirmPasswordValidation = _confirmPassword.isNotEmpty;
    });
    _validateForm();
  }

  void _validateForm() {
    final isCurrentPasswordValid = _currentPasswordController.text.isNotEmpty;
    final isNewPasswordValid =
        PasswordHelper.isPasswordStrong(_newPassword) &&
        _newPassword != _currentPasswordController.text;
    final isConfirmPasswordValid = _confirmPassword == _newPassword;

    setState(() {
      _isFormValid =
          isCurrentPasswordValid &&
          isNewPasswordValid &&
          isConfirmPasswordValid;
    });
  }

  void _clearError() {
    if (_error != null) {
      setState(() {
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Password Security',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Change your account password to keep your account secure. Follow the password guidelines below.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Current Password Field
              Text(
                'Current Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              EnhancedTextField(
                controller: _currentPasswordController,
                labelText: 'Enter current password',
                prefixIcon: Icons.lock,
                isPassword: true,
                showValidationIcon: false,
                onChanged: (value) {
                  _clearError();
                  _validateForm();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Current password is required';
                  }
                  return null;
                },
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: 24),

              // New Password Section
              Text(
                'New Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              EnhancedTextField(
                controller: _newPasswordController,
                labelText: 'Create a new secure password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                showValidationIcon: false,
                onChanged: (value) {
                  _clearError();
                  _onNewPasswordChanged();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters long';
                  }
                  if (!PasswordHelper.isPasswordStrong(value)) {
                    return 'Password does not meet security requirements';
                  }
                  if (value == _currentPasswordController.text) {
                    return 'New password must be different from current password';
                  }
                  return null;
                },
                keyboardType: TextInputType.visiblePassword,
              ),

              // Password Strength Checklist
              if (_showNewPasswordChecklist) ...[
                const SizedBox(height: 8),
                PasswordStrengthChecklist(
                  password: _newPassword,
                  isVisible: true,
                ),
              ],
              const SizedBox(height: 24),

              // Confirm Password Section
              Text(
                'Confirm New Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              EnhancedTextField(
                controller: _confirmPasswordController,
                labelText: 'Re-enter your new password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                showValidationIcon: false,
                onChanged: (value) {
                  _clearError();
                  _onConfirmPasswordChanged();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                keyboardType: TextInputType.visiblePassword,
              ),

              // Confirm Password Validation
              if (_showConfirmPasswordValidation) ...[
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _confirmPassword == _newPassword
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _confirmPassword == _newPassword
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _confirmPassword == _newPassword
                            ? Icons.check_circle
                            : Icons.error,
                        size: 16,
                        color: _confirmPassword == _newPassword
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _confirmPassword == _newPassword
                            ? 'Passwords match'
                            : 'Passwords do not match',
                        style: TextStyle(
                          fontSize: 12,
                          color: _confirmPassword == _newPassword
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Error Display
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !_isFormValid
                      ? null
                      : _changePassword,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _isFormValid
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    foregroundColor: _isFormValid
                        ? Theme.of(context).colorScheme.onPrimary
                        : Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After changing your password, you may need to log in again with your new password on other devices.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'No user is currently signed in. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Password changed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Clear form
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _newPassword = '';
          _confirmPassword = '';
          _showNewPasswordChecklist = false;
          _showConfirmPasswordValidation = false;
          _isFormValid = false;
        });

        // Navigate back
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage =
              'The current password you entered is incorrect. Please check your password and try again.';
          break;
        case 'weak-password':
          errorMessage =
              'The new password you entered is too weak. Please use a stronger password.';
          break;
        case 'requires-recent-login':
          errorMessage =
              'For security reasons, please log out and log in again before changing your password.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error occurred. Please check your internet connection and try again.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many failed attempts. Please wait a moment and try again.';
          break;
        default:
          errorMessage =
              'Failed to change password. Please try again or contact support if the problem persists.';
      }

      if (mounted) {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'An unexpected error occurred. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }
}
