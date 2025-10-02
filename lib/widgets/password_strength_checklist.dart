import 'package:flutter/material.dart';

class PasswordStrengthChecklist extends StatelessWidget {
  final String password;
  final bool isVisible;

  const PasswordStrengthChecklist({
    super.key,
    required this.password,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final checks = _getPasswordChecks(password);
    final overallStrength = _getOverallStrength(checks);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                size: 16,
                color: _getStrengthColor(overallStrength),
              ),
              const SizedBox(width: 8),
              Text(
                'Password Strength: ${_getStrengthText(overallStrength)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _getStrengthColor(overallStrength),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: overallStrength / 4,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getStrengthColor(overallStrength),
            ),
          ),
          const SizedBox(height: 12),
          ...checks.entries.map(
            (entry) => _buildCheckItem(entry.key, entry.value, context),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isValid, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isValid ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isValid
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isValid
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, bool> _getPasswordChecks(String password) {
    return {
      'At least 8 characters': password.length >= 8,
      'Contains uppercase letter (A-Z)': password.contains(RegExp(r'[A-Z]')),
      'Contains lowercase letter (a-z)': password.contains(RegExp(r'[a-z]')),
      'Contains number (0-9)': password.contains(RegExp(r'[0-9]')),
      'Contains special character (!@#\$%^&*)': password.contains(
        RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
      ),
    };
  }

  int _getOverallStrength(Map<String, bool> checks) {
    return checks.values.where((check) => check).length;
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStrengthText(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Very Weak';
      case 2:
        return 'Weak';
      case 3:
        return 'Fair';
      case 4:
        return 'Good';
      case 5:
        return 'Strong';
      default:
        return 'Unknown';
    }
  }
}
