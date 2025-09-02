import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHelper {
  static const int _saltLength = 32;

  /// Generates a random salt for password hashing
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(
      _saltLength,
      (i) => random.nextInt(256),
    );
    return base64.encode(saltBytes);
  }

  /// Hashes a password with a salt using SHA-256
  static String hashPassword(String password, [String? salt]) {
    salt ??= _generateSalt();
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return '${digest.toString()}:$salt';
  }

  /// Verifies a password against a hashed password
  static bool verifyPassword(String password, String hashedPassword) {
    try {
      final parts = hashedPassword.split(':');
      if (parts.length != 2) return false;

      final salt = parts[1];

      final testHash = hashPassword(password, salt);
      return testHash == hashedPassword;
    } catch (e) {
      return false;
    }
  }

  /// Validates password strength
  static bool isPasswordStrong(String password) {
    if (password.length < 8) return false;

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  /// Gets password strength description
  static String getPasswordStrengthDescription(String password) {
    if (password.length < 6) return 'Too short';
    if (password.length < 8) return 'Weak';
    if (!isPasswordStrong(password)) return 'Medium';
    return 'Strong';
  }
}
