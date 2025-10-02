import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';
import '../../utils/password_helper.dart';
import '../../widgets/enhanced_text_field.dart';
import '../../widgets/password_strength_checklist.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.user;
  bool _isLoading = false;
  bool _showPasswordChecklist = false;
  String _currentPassword = '';
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _currentPassword = _passwordController.text;
      _showPasswordChecklist = _currentPassword.isNotEmpty;
    });
    _validateForm();
  }

  void _validateForm() {
    final isUsernameValid = _usernameController.text.trim().length >= 3;
    final isEmailValid = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_emailController.text.trim());
    final isPasswordValid = PasswordHelper.isPasswordStrong(_currentPassword);

    setState(() {
      _isFormValid = isUsernameValid && isEmailValid && isPasswordValid;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: const Text(
          'A verification email has been sent to your email address. Please verify your email to login.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 40),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return EnhancedTextField(
                      controller: _usernameController,
                      labelText: 'Username',
                      prefixIcon: Icons.person,
                      errorText: authProvider.fieldErrors['username'],
                      onChanged: (value) {
                        authProvider.clearFieldErrors();
                        _validateForm();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (value.trim().length < 3) {
                          return 'Username must be at least 3 characters long';
                        }
                        if (!RegExp(
                          r'^[a-zA-Z0-9_]+$',
                        ).hasMatch(value.trim())) {
                          return 'Username can only contain letters, numbers, and underscores';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return EnhancedTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      errorText: authProvider.fieldErrors['email'],
                      onChanged: (value) {
                        authProvider.clearFieldErrors();
                        _validateForm();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EnhancedTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          prefixIcon: Icons.lock,
                          isPassword: true,
                          errorText: authProvider.fieldErrors['password'],
                          showValidationIcon: false,
                          onChanged: (value) {
                            authProvider.clearFieldErrors();
                            _onPasswordChanged();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (!PasswordHelper.isPasswordStrong(value)) {
                              return 'Password is not strong enough.';
                            }
                            return null;
                          },
                        ),
                        PasswordStrengthChecklist(
                          password: _currentPassword,
                          isVisible: _showPasswordChecklist,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_pin_rounded),
                    filled: true,
                    fillColor: Colors.white70,
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem<UserRole>(
                      value: role,
                      child: Text(role.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || !_isFormValid
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                              });

                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider.createUser(
                                _usernameController.text.trim(),
                                _emailController.text.trim(),
                                _passwordController.text,
                                _selectedRole,
                              );

                              if (!mounted) return;

                              if (success) {
                                _showVerificationDialog();
                              } else {
                                final errorMessage =
                                    authProvider.error ?? 'Signup failed';
                                _showErrorSnackBar(errorMessage);
                              }

                              setState(() {
                                _isLoading = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isFormValid
                                ? 'Create Account'
                                : 'Complete Form to Continue',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/login');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                  ),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
