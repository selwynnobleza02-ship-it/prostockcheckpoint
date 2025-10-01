import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';
import '../../utils/enhanced_password_validator.dart';
import '../../utils/enhanced_validation.dart';
import '../../widgets/password_strength_indicator.dart';
import '../../widgets/error_message_widget.dart';

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
  String? _usernameSuggestion;
  String? _emailSuggestion;
  String? _passwordSuggestion;
  bool _showPasswordStrength = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _usernameSuggestion = null;
      _emailSuggestion = null;
      _passwordSuggestion = null;
    });
  }

  void _showDetailedErrorDialog(
    String title,
    String message,
    String? suggestion,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600]),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (suggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
                  onChanged: (value) {
                    _clearErrors();
                    // Real-time validation
                    if (value.isNotEmpty) {
                      final validation = EnhancedValidation.validateUsername(
                        value,
                      );
                      if (!validation.isValid) {
                        setState(() {
                          _usernameError = validation.errorMessage;
                          _usernameSuggestion = validation.suggestion;
                        });
                      }
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    final validation = EnhancedValidation.validateUsername(
                      value,
                    );
                    if (!validation.isValid) {
                      return validation.errorMessage;
                    }
                    return null;
                  },
                ),
                // Username suggestion widget
                if (_usernameSuggestion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: InfoMessageWidget(
                      message: _usernameSuggestion!,
                      onDismiss: () {
                        setState(() {
                          _usernameSuggestion = null;
                        });
                      },
                    ),
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
                  onChanged: (value) {
                    _clearErrors();
                    // Real-time validation
                    if (value.isNotEmpty) {
                      final validation = EnhancedValidation.validateEmail(
                        value,
                      );
                      if (!validation.isValid) {
                        setState(() {
                          _emailError = validation.errorMessage;
                          _emailSuggestion = validation.suggestion;
                        });
                      }
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    final validation = EnhancedValidation.validateEmail(value);
                    if (!validation.isValid) {
                      return validation.errorMessage;
                    }
                    return null;
                  },
                ),
                // Email suggestion widget
                if (_emailSuggestion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: InfoMessageWidget(
                      message: _emailSuggestion!,
                      onDismiss: () {
                        setState(() {
                          _emailSuggestion = null;
                        });
                      },
                    ),
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
                    helperText: 'Create a strong password',
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
                  onChanged: (value) {
                    _clearErrors();
                    setState(() {
                      _showPasswordStrength = value.isNotEmpty;
                    });
                    // Real-time validation
                    if (value.isNotEmpty) {
                      final validation = EnhancedValidation.validatePassword(
                        value,
                      );
                      if (!validation.isValid) {
                        setState(() {
                          _passwordError = validation.errorMessage;
                          _passwordSuggestion = validation.suggestion;
                        });
                      }
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    final validation = EnhancedValidation.validatePassword(
                      value,
                    );
                    if (!validation.isValid) {
                      return validation.errorMessage;
                    }
                    if (!EnhancedPasswordValidator.isPasswordValid(value)) {
                      return 'Password does not meet all requirements';
                    }
                    return null;
                  },
                ),
                // Password strength indicator
                if (_showPasswordStrength)
                  PasswordStrengthCard(
                    password: _passwordController.text,
                    isVisible: _showPasswordStrength,
                  ),
                // Password suggestion widget
                if (_passwordSuggestion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: InfoMessageWidget(
                      message: _passwordSuggestion!,
                      onDismiss: () {
                        setState(() {
                          _passwordSuggestion = null;
                        });
                      },
                    ),
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
                                setState(() {
                                  if (errorMessage.contains(
                                    'Username already exists',
                                  )) {
                                    _usernameError = 'Username already exists.';
                                    _usernameSuggestion =
                                        'Try a different username or add numbers/underscores.';
                                  } else if (errorMessage.contains(
                                    'email-already-in-use',
                                  )) {
                                    _emailError = 'Email is already in use.';
                                    _emailSuggestion =
                                        'This email is already registered. Try logging in or use a different email.';
                                  } else if (errorMessage.contains(
                                    'invalid-email',
                                  )) {
                                    _emailError =
                                        'Please enter a valid email address.';
                                    _emailSuggestion =
                                        'Make sure your email follows the format: user@example.com';
                                  } else if (errorMessage.contains(
                                    'weak-password',
                                  )) {
                                    _passwordError = 'Password is too weak.';
                                    _passwordSuggestion =
                                        'Use a stronger password with uppercase, lowercase, numbers, and special characters.';
                                  } else if (errorMessage.contains(
                                    'network-request-failed',
                                  )) {
                                    _showDetailedErrorDialog(
                                      'Network Error',
                                      'Unable to connect to the server. Please check your internet connection.',
                                      'Check your WiFi or mobile data connection and try again.',
                                    );
                                  } else if (errorMessage.contains(
                                    'operation-not-allowed',
                                  )) {
                                    _showDetailedErrorDialog(
                                      'Signup Disabled',
                                      'Account creation is currently disabled.',
                                      'Please contact support for assistance.',
                                    );
                                  } else {
                                    _showDetailedErrorDialog(
                                      'Signup Failed',
                                      errorMessage,
                                      'Please check your information and try again.',
                                    );
                                  }
                                });
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
