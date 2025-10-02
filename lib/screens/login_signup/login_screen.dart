import 'package:flutter/material.dart';
import 'package:prostock/screens/login_signup/forgot_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:prostock/utils/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';
import '../../widgets/enhanced_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isEmailValid = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_emailController.text.trim());
    final isPasswordValid = _passwordController.text.isNotEmpty;

    setState(() {
      _isFormValid = isEmailValid && isPasswordValid;
    });
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
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
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
                const SizedBox(height: UiConstants.spacingLarge),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return EnhancedTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      prefixIcon: Icons.lock,
                      isPassword: true,
                      errorText: authProvider.fieldErrors['password'],
                      onChanged: (value) {
                        authProvider.clearFieldErrors();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: UiConstants.spacingExtraLarge2),
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

                              final navigator = Navigator.of(context);
                              final scaffold = ScaffoldMessenger.of(context);
                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider.login(
                                _emailController.text.trim(),
                                _passwordController.text,
                              );

                              if (!mounted) return;

                              if (success) {
                                scaffold.showSnackBar(
                                  const SnackBar(
                                    content: Text('Login successful!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
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
                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: 'Dismiss',
                                      textColor: Colors.white,
                                      onPressed: () =>
                                          scaffold.hideCurrentSnackBar(),
                                    ),
                                  ),
                                );
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
                        : Text(
                            _isFormValid ? 'Login' : 'Enter Email & Password',
                            style: const TextStyle(
                              fontSize: UiConstants.fontSizeButton,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: UiConstants.spacingLarge),
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
