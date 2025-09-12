import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';
import '../../utils/password_helper.dart';

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
  bool _isPasswordVisible = false; // New state for password visibility
  String? _usernameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: const Text(
            'A verification email has been sent to your email address. Please verify your email to login.'),
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
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.white70,
                    errorText: _usernameError,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.white70,
                    errorText: _emailError,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.white70,
                    helperText:
                        'Password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one number, and one special character.',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    errorText: _passwordError,
                  ),
                  obscureText: !_isPasswordVisible,
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
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                                _usernameError = null;
                                _emailError = null;
                                _passwordError = null;
                              });
                              final authProvider =
                                  context.read<AuthProvider>();
                              final success = await authProvider.createUser(
                                _usernameController.text,
                                _emailController.text,
                                _passwordController.text,
                                _selectedRole,
                              );

                              if (success) {
                                if (context.mounted) {
                                  _showVerificationDialog();
                                }
                              } else {
                                if (!mounted) return;
                                final errorMessage = authProvider.error ?? 'Signup failed';
                                setState(() {
                                  if (errorMessage.contains('Username already exists')) {
                                    _usernameError = 'Username already exists.';
                                  } else if (errorMessage.contains('email-already-in-use') ||
                                      errorMessage.contains('invalid-email')) {
                                    _emailError = 'Invalid email or email already in use.';
                                  } else if (errorMessage.contains('weak-password')) {
                                    _passwordError = 'The password is too weak.';
                                  } else {
                                    _showErrorSnackBar(errorMessage);
                                  }
                                });
                              }
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
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
                        : const Text('Sign Up', style: TextStyle(fontSize: 18)),
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
