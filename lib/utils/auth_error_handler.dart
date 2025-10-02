import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHandler {
  static String getLoginErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address. Please check your email or create a new account.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support for assistance.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a few minutes before trying again.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection and try again.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your email and password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  static String getSignupErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email address is already registered. Please use a different email or try logging in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password with at least 8 characters, including uppercase, lowercase, numbers, and special characters.';
      case 'operation-not-allowed':
        return 'Account creation is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a few minutes before trying again.';
      default:
        return e.message ?? 'Account creation failed. Please try again.';
    }
  }

  static String getPasswordResetErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address. Please check your email or create a new account.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many password reset requests. Please wait before trying again.';
      default:
        return e.message ?? 'Password reset failed. Please try again.';
    }
  }

  static Map<String, String> getFieldSpecificError(FirebaseAuthException e) {
    final Map<String, String> errors = {};

    switch (e.code) {
      case 'user-not-found':
      case 'invalid-email':
        errors['email'] = 'Invalid email or user not found';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        errors['password'] = 'Incorrect password';
        break;
      case 'email-already-in-use':
        errors['email'] = 'This email is already registered';
        break;
      case 'weak-password':
        errors['password'] = 'Password is too weak';
        break;
    }

    return errors;
  }
}
