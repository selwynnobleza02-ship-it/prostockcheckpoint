import 'package:flutter/material.dart';

class PasswordRequirement {
  final String description;
  final bool isMet;
  final IconData icon;

  PasswordRequirement({
    required this.description,
    required this.isMet,
    required this.icon,
  });
}

class EnhancedPasswordValidator {
  static const int minLength = 8;
  static const int maxLength = 128;

  /// Validates password and returns detailed requirements
  static List<PasswordRequirement> validatePassword(String password) {
    List<PasswordRequirement> requirements = [];

    // Length requirement
    requirements.add(
      PasswordRequirement(
        description: 'At least $minLength characters',
        isMet: password.length >= minLength,
        icon: Icons.check_circle_outline,
      ),
    );

    // Uppercase requirement
    requirements.add(
      PasswordRequirement(
        description: 'One uppercase letter (A-Z)',
        isMet: password.contains(RegExp(r'[A-Z]')),
        icon: Icons.check_circle_outline,
      ),
    );

    // Lowercase requirement
    requirements.add(
      PasswordRequirement(
        description: 'One lowercase letter (a-z)',
        isMet: password.contains(RegExp(r'[a-z]')),
        icon: Icons.check_circle_outline,
      ),
    );

    // Number requirement
    requirements.add(
      PasswordRequirement(
        description: 'One number (0-9)',
        isMet: password.contains(RegExp(r'[0-9]')),
        icon: Icons.check_circle_outline,
      ),
    );

    // Special character requirement
    requirements.add(
      PasswordRequirement(
        description: 'One special character (!@#\$%^&*)',
        isMet: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
        icon: Icons.check_circle_outline,
      ),
    );

    // No common patterns
    requirements.add(
      PasswordRequirement(
        description: 'No common patterns (123, abc, qwe)',
        isMet: !_hasCommonPatterns(password),
        icon: Icons.check_circle_outline,
      ),
    );

    // No repeated characters
    requirements.add(
      PasswordRequirement(
        description: 'No repeated characters (aaa, 111)',
        isMet: !_hasRepeatedCharacters(password),
        icon: Icons.check_circle_outline,
      ),
    );

    return requirements;
  }

  /// Checks if password meets all requirements
  static bool isPasswordValid(String password) {
    final requirements = validatePassword(password);
    return requirements.every((req) => req.isMet);
  }

  /// Gets password strength score (0-100)
  static int getPasswordStrengthScore(String password) {
    if (password.isEmpty) return 0;

    final requirements = validatePassword(password);
    final metRequirements = requirements.where((req) => req.isMet).length;

    // Base score from requirements
    int score = (metRequirements / requirements.length * 80).round();

    // Bonus for length
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;

    return score.clamp(0, 100);
  }

  /// Gets password strength level
  static PasswordStrengthLevel getPasswordStrengthLevel(String password) {
    final score = getPasswordStrengthScore(password);

    if (score < 30) return PasswordStrengthLevel.weak;
    if (score < 60) return PasswordStrengthLevel.fair;
    if (score < 80) return PasswordStrengthLevel.good;
    return PasswordStrengthLevel.strong;
  }

  /// Gets password strength color
  static Color getPasswordStrengthColor(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.weak:
        return Colors.red;
      case PasswordStrengthLevel.fair:
        return Colors.orange;
      case PasswordStrengthLevel.good:
        return Colors.blue;
      case PasswordStrengthLevel.strong:
        return Colors.green;
    }
  }

  /// Gets password strength description
  static String getPasswordStrengthDescription(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.weak:
        return 'Weak password';
      case PasswordStrengthLevel.fair:
        return 'Fair password';
      case PasswordStrengthLevel.good:
        return 'Good password';
      case PasswordStrengthLevel.strong:
        return 'Strong password';
    }
  }

  /// Checks for common patterns
  static bool _hasCommonPatterns(String password) {
    final commonPatterns = [
      '123',
      'abc',
      'qwe',
      'asd',
      'zxc',
      'password',
      'admin',
      'user',
      'test',
      'qwerty',
      'asdf',
      'zxcv',
    ];

    final lowerPassword = password.toLowerCase();
    return commonPatterns.any((pattern) => lowerPassword.contains(pattern));
  }

  /// Checks for repeated characters
  static bool _hasRepeatedCharacters(String password) {
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  /// Gets validation error message
  static String? getValidationError(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (password.length > maxLength) {
      return 'Password must be less than $maxLength characters';
    }

    final requirements = validatePassword(password);
    final unmetRequirements = requirements.where((req) => !req.isMet);

    if (unmetRequirements.isNotEmpty) {
      return 'Password must meet all requirements';
    }

    return null;
  }
}

enum PasswordStrengthLevel { weak, fair, good, strong }
