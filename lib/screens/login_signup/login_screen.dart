import 'package:flutter/material.dart';
import 'package:prostock/screens/login_signup/forgot_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:prostock/utils/app_constants.dart';
import '../../providers/auth_provider.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
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
                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider.login(
                                _emailController.text,
                                _passwordController.text,
                              );

                              if (success) {
                                // Check if the widget is still mounted
                                final userRole = authProvider.userRole;
                                if (!context.mounted) return;
                                if (userRole == UserRole.admin) {
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/admin');
                                } else {
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/user');
                                }
                              } else {
                                if (!mounted) return;
                                final errorMessage =
                                    authProvider.error ?? 'Login failed';
                                setState(() {
                                  if (errorMessage.contains('user-not-found') ||
                                      errorMessage.contains('invalid-email')) {
                                    _emailError =
                                        'Invalid email or user not found.';
                                  } else if (errorMessage.contains(
                                    'wrong-password',
                                  )) {
                                    _passwordError = 'Incorrect password.';
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
                          horizontal: UiConstants.spacingSmall),
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
                          vertical: UiConstants.spacingMedium),
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
