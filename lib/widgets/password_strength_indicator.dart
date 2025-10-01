import 'package:flutter/material.dart';
import '../utils/enhanced_password_validator.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showRequirements;
  final EdgeInsetsGeometry? padding;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showRequirements = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final requirements = EnhancedPasswordValidator.validatePassword(password);
    final strengthLevel = EnhancedPasswordValidator.getPasswordStrengthLevel(
      password,
    );
    final strengthColor = EnhancedPasswordValidator.getPasswordStrengthColor(
      strengthLevel,
    );
    final strengthDescription =
        EnhancedPasswordValidator.getPasswordStrengthDescription(strengthLevel);

    return Container(
      padding: padding ?? const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strength bar and description
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value:
                      EnhancedPasswordValidator.getPasswordStrengthScore(
                        password,
                      ) /
                      100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthDescription,
                style: TextStyle(
                  color: strengthColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          if (showRequirements && password.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Requirements list
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: requirements.map((requirement) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: requirement.isMet
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: requirement.isMet
                          ? Colors.green[300]!
                          : Colors.red[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        requirement.isMet ? Icons.check : Icons.close,
                        size: 14,
                        color: requirement.isMet
                            ? Colors.green[600]
                            : Colors.red[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        requirement.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: requirement.isMet
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class PasswordStrengthCard extends StatelessWidget {
  final String password;
  final bool isVisible;

  const PasswordStrengthCard({
    super.key,
    required this.password,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || password.isEmpty) {
      return const SizedBox.shrink();
    }

    final requirements = EnhancedPasswordValidator.validatePassword(password);
    final strengthLevel = EnhancedPasswordValidator.getPasswordStrengthLevel(
      password,
    );
    final strengthColor = EnhancedPasswordValidator.getPasswordStrengthColor(
      strengthLevel,
    );
    final strengthDescription =
        EnhancedPasswordValidator.getPasswordStrengthDescription(strengthLevel);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with strength indicator
            Row(
              children: [
                Icon(Icons.security, size: 20, color: strengthColor),
                const SizedBox(width: 8),
                Text(
                  'Password Strength',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: strengthColor,
                  ),
                ),
                const Spacer(),
                Text(
                  strengthDescription,
                  style: TextStyle(
                    color: strengthColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value:
                  EnhancedPasswordValidator.getPasswordStrengthScore(password) /
                  100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              minHeight: 6,
            ),

            const SizedBox(height: 16),

            // Requirements grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: requirements.length,
              itemBuilder: (context, index) {
                final requirement = requirements[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: requirement.isMet
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: requirement.isMet
                          ? Colors.green[300]!
                          : Colors.red[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        requirement.isMet ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: requirement.isMet
                            ? Colors.green[600]
                            : Colors.red[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          requirement.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: requirement.isMet
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
