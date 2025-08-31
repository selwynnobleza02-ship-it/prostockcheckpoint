import 'package:flutter/material.dart';
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
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.white70,
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
                    onPressed:
                        _isLoading // Disable button when loading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                final authProvider = context
                                    .read<AuthProvider>();
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
                                  _showErrorSnackBar(
                                    authProvider.error ?? 'Login failed',
                                  );
                                }
                              } finally {
                                if (!mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
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
                    child:
                        _isLoading // Show loading indicator
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
