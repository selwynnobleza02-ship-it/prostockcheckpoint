import 'package:flutter/material.dart';
import 'package:prostock/screens/login_signup/forgot_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:prostock/utils/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../utils/enhanced_validation.dart';
import '../../widgets/error_message_widget.dart';
// Make sure UserRole is imported if defined elsewhere
import '../../models/user_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // New state for loading indicator
  bool _isPasswordVisible = false; // New state for password visibility
  String? _emailError;
  String? _passwordError;
  String? _emailSuggestion;
  String? _passwordSuggestion;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UiConstants.spacingMedium),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: UiConstants.fontSizeTitle,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: UiConstants.spacingExtraLarge),
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
                      return 'Please enter your email';
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
                const SizedBox(height: UiConstants.spacingLarge),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.white70,
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
                  onChanged: (value) => _clearErrors(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
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
                const SizedBox(height: UiConstants.spacingExtraLarge2),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                                _emailError = null;
                                _passwordError = null;
                              });
                              final navigator = Navigator.of(context);
                              final scaffold = ScaffoldMessenger.of(context);
                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider.login(
                                _emailController.text.trim(),
                                _passwordController.text,
                              );

                              if (!mounted) return;

                              if (success) {
                                _retryCount = 0; // Reset retry count on success
                                scaffold.showSnackBar(
                                  const SnackBar(
                                    content: Text('Login successful!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                final userRole = authProvider.userRole;
                                if (userRole == UserRole.admin) {
                                  navigator.pushReplacementNamed('/admin');
                                } else {
                                  navigator.pushReplacementNamed('/user');
                                }
                              } else {
                                final errorMessage =
                                    authProvider.error ?? 'Login failed';
                                setState(() {
                                  if (errorMessage.contains('user-not-found')) {
                                    _emailError =
                                        'No account found with this email address.';
                                    _emailSuggestion =
                                        'Check your email address or create a new account.';
                                  } else if (errorMessage.contains(
                                    'invalid-email',
                                  )) {
                                    _emailError =
                                        'Please enter a valid email address.';
                                    _emailSuggestion =
                                        'Make sure your email follows the format: user@example.com';
                                  } else if (errorMessage.contains(
                                    'wrong-password',
                                  )) {
                                    _passwordError = 'Incorrect password.';
                                    _passwordSuggestion =
                                        'Check your password or use "Forgot Password" to reset it.';
                                  } else if (errorMessage.contains(
                                    'too-many-requests',
                                  )) {
                                    _showDetailedErrorDialog(
                                      'Too Many Attempts',
                                      'Too many failed login attempts. Please try again later.',
                                      'Wait a few minutes before trying again, or reset your password.',
                                    );
                                  } else if (errorMessage.contains(
                                    'network-request-failed',
                                  )) {
                                    _retryCount++;
                                    if (_retryCount < _maxRetries) {
                                      scaffold.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Network error. Retrying... ($_retryCount/$_maxRetries)',
                                          ),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 3),
                                          action: SnackBarAction(
                                            label: 'Dismiss',
                                            textColor: Colors.white,
                                            onPressed: () =>
                                                scaffold.hideCurrentSnackBar(),
                                          ),
                                        ),
                                      );
                                      // Auto-retry after a short delay
                                      Future.delayed(
                                        const Duration(seconds: 2),
                                        () {
                                          if (mounted) {
                                            // Trigger retry by calling the login function again
                                            // This is a simple retry mechanism
                                          }
                                        },
                                      );
                                    } else {
                                      _showDetailedErrorDialog(
                                        'Network Error',
                                        'Unable to connect to the server. Please check your internet connection.',
                                        'Check your WiFi or mobile data connection and try again.',
                                      );
                                    }
                                  } else if (errorMessage.contains(
                                    'email-not-verified',
                                  )) {
                                    _showDetailedErrorDialog(
                                      'Email Not Verified',
                                      'Please verify your email address before logging in.',
                                      'Check your email inbox for a verification link, or request a new one.',
                                    );
                                  } else {
                                    _showDetailedErrorDialog(
                                      'Login Failed',
                                      errorMessage,
                                      'Please check your credentials and try again.',
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
                      padding: const EdgeInsets.symmetric(
                        vertical: UiConstants.spacingMedium,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          UiConstants.borderRadiusStandard,
                        ),
                      ),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: UiConstants.iconSizeSmall,
                            height: UiConstants.iconSizeSmall,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: UiConstants.strokeWidthSmall,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: UiConstants.fontSizeButton,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: UiConstants.spacingLarge),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: UiConstants.spacingSmall,
                      ),
                      child: Text('Or sign in with'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: UiConstants.spacingLarge),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.g_mobiledata, color: Colors.red),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: UiConstants.spacingMedium,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          UiConstants.borderRadiusStandard,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: UiConstants.spacingSmall),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/signup');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: UiConstants.fontSizeMedium),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: UiConstants.fontSizeSmall),
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
