import 'package:flutter/material.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/screens/admin/components/stat_card.dart';

class StatsHeader extends StatelessWidget {
  final List<AppUser> users;
  final List<Map<String, dynamic>> activities;

  const StatsHeader({
    super.key,
    required this.users,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo[600],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Users',
                  value: users.length.toString(),
                  icon: Icons.people,
                  color: Colors.blue[400]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Total Activities',
                  value: activities.length.toString(),
                  icon: Icons.admin_panel_settings,
                  color: Colors.green[400]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Active Users',
                  value: users.where((u) => u.isActive).length.toString(),
                  icon: Icons.verified_user,
                  color: Colors.orange[400]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Today\'s Activities',
                  value: activities
                      .where((a) {
                        final date = DateTime.parse(a['timestamp']);
                        final today = DateTime.now();
                        return date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;
                      })
                      .length
                      .toString(),
                  icon: Icons.today,
                  color: Colors.purple[400]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
