class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? suggestion;

  ValidationResult({required this.isValid, this.errorMessage, this.suggestion});

  static ValidationResult valid() => ValidationResult(isValid: true);

  static ValidationResult invalid(String errorMessage, {String? suggestion}) =>
      ValidationResult(
        isValid: false,
        errorMessage: errorMessage,
        suggestion: suggestion,
      );
}

class EnhancedValidation {
  // Email validation
  static ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult.invalid('Email is required');
    }

    final trimmedEmail = email.trim();

    // Basic format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return ValidationResult.invalid(
        'Please enter a valid email address',
        suggestion: 'Example: user@example.com',
      );
    }

    // Check for common typos
    if (trimmedEmail.contains('..') ||
        trimmedEmail.startsWith('.') ||
        trimmedEmail.endsWith('.')) {
      return ValidationResult.invalid(
        'Email format is invalid',
        suggestion: 'Remove extra dots or spaces',
      );
    }

    // Check for missing @ symbol
    if (!trimmedEmail.contains('@')) {
      return ValidationResult.invalid(
        'Email must contain @ symbol',
        suggestion: 'Example: user@example.com',
      );
    }

    // Check for missing domain
    final parts = trimmedEmail.split('@');
    if (parts.length != 2 || parts[1].isEmpty) {
      return ValidationResult.invalid(
        'Email must have a valid domain',
        suggestion: 'Example: user@example.com',
      );
    }

    return ValidationResult.valid();
  }

  // Username validation
  static ValidationResult validateUsername(String username) {
    if (username.isEmpty) {
      return ValidationResult.invalid('Username is required');
    }

    final trimmedUsername = username.trim();

    // Length validation
    if (trimmedUsername.length < 3) {
      return ValidationResult.invalid(
        'Username must be at least 3 characters long',
        suggestion: 'Choose a longer username',
      );
    }

    if (trimmedUsername.length > 20) {
      return ValidationResult.invalid(
        'Username must be less than 20 characters',
        suggestion: 'Choose a shorter username',
      );
    }

    // Character validation
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmedUsername)) {
      return ValidationResult.invalid(
        'Username can only contain letters, numbers, and underscores',
        suggestion: 'Use only a-z, A-Z, 0-9, and _',
      );
    }

    // Cannot start or end with underscore
    if (trimmedUsername.startsWith('_') || trimmedUsername.endsWith('_')) {
      return ValidationResult.invalid(
        'Username cannot start or end with underscore',
        suggestion: 'Remove underscores from the beginning or end',
      );
    }

    // Cannot have consecutive underscores
    if (trimmedUsername.contains('__')) {
      return ValidationResult.invalid(
        'Username cannot have consecutive underscores',
        suggestion: 'Remove consecutive underscores',
      );
    }

    return ValidationResult.valid();
  }

  // Password validation
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult.invalid('Password is required');
    }

    if (password.length < 8) {
      return ValidationResult.invalid(
        'Password must be at least 8 characters long',
        suggestion: 'Add more characters to make it stronger',
      );
    }

    if (password.length > 128) {
      return ValidationResult.invalid(
        'Password is too long',
        suggestion: 'Use a password less than 128 characters',
      );
    }

    return ValidationResult.valid();
  }

  // Phone number validation
  static ValidationResult validatePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return ValidationResult.invalid('Phone number is required');
    }

    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10) {
      return ValidationResult.invalid(
        'Phone number must have at least 10 digits',
        suggestion: 'Include area code and phone number',
      );
    }

    if (digitsOnly.length > 15) {
      return ValidationResult.invalid(
        'Phone number is too long',
        suggestion: 'Check your phone number format',
      );
    }

    return ValidationResult.valid();
  }

  // Name validation
  static ValidationResult validateName(
    String name, {
    String fieldName = 'Name',
  }) {
    if (name.isEmpty) {
      return ValidationResult.invalid('$fieldName is required');
    }

    final trimmedName = name.trim();

    if (trimmedName.length < 2) {
      return ValidationResult.invalid(
        '$fieldName must be at least 2 characters long',
        suggestion: 'Enter your full $fieldName',
      );
    }

    if (trimmedName.length > 50) {
      return ValidationResult.invalid(
        '$fieldName is too long',
        suggestion: 'Use a shorter $fieldName',
      );
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(trimmedName)) {
      return ValidationResult.invalid(
        '$fieldName can only contain letters, spaces, hyphens, and apostrophes',
        suggestion: 'Remove special characters or numbers',
      );
    }

    return ValidationResult.valid();
  }

  // URL validation
  static ValidationResult validateUrl(String url) {
    if (url.isEmpty) {
      return ValidationResult.invalid('URL is required');
    }

    final trimmedUrl = url.trim();

    // Basic URL pattern
    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(trimmedUrl)) {
      return ValidationResult.invalid(
        'Please enter a valid URL',
        suggestion: 'Example: https://www.example.com',
      );
    }

    return ValidationResult.valid();
  }

  // Credit card validation
  static ValidationResult validateCreditCard(String cardNumber) {
    if (cardNumber.isEmpty) {
      return ValidationResult.invalid('Card number is required');
    }

    // Remove all non-digit characters
    final digitsOnly = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 13 || digitsOnly.length > 19) {
      return ValidationResult.invalid(
        'Card number must be between 13 and 19 digits',
        suggestion: 'Check your card number',
      );
    }

    // Luhn algorithm validation
    if (!_isValidLuhn(digitsOnly)) {
      return ValidationResult.invalid(
        'Invalid card number',
        suggestion: 'Check your card number for typos',
      );
    }

    return ValidationResult.valid();
  }

  // CVV validation
  static ValidationResult validateCVV(String cvv) {
    if (cvv.isEmpty) {
      return ValidationResult.invalid('CVV is required');
    }

    final digitsOnly = cvv.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length != 3 && digitsOnly.length != 4) {
      return ValidationResult.invalid(
        'CVV must be 3 or 4 digits',
        suggestion: 'Enter the 3 or 4 digit code on your card',
      );
    }

    return ValidationResult.valid();
  }

  // Expiry date validation
  static ValidationResult validateExpiryDate(String expiryDate) {
    if (expiryDate.isEmpty) {
      return ValidationResult.invalid('Expiry date is required');
    }

    // Expected format: MM/YY or MM/YYYY
    final dateRegex = RegExp(r'^(\d{2})\/(\d{2,4})$');
    final match = dateRegex.firstMatch(expiryDate);

    if (match == null) {
      return ValidationResult.invalid(
        'Invalid date format',
        suggestion: 'Use MM/YY or MM/YYYY format',
      );
    }

    final month = int.tryParse(match.group(1)!) ?? 0;
    final year = int.tryParse(match.group(2)!) ?? 0;

    if (month < 1 || month > 12) {
      return ValidationResult.invalid(
        'Invalid month',
        suggestion: 'Month must be between 01 and 12',
      );
    }

    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    final fullYear = year < 100 ? 2000 + year : year;

    if (fullYear < currentYear ||
        (fullYear == currentYear && month < currentMonth)) {
      return ValidationResult.invalid(
        'Card has expired',
        suggestion: 'Use a valid expiry date',
      );
    }

    return ValidationResult.valid();
  }

  // Luhn algorithm for credit card validation
  static bool _isValidLuhn(String cardNumber) {
    int sum = 0;
    bool alternate = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }
}
