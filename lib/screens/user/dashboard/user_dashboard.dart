import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/screens/user/dashboard/components/action_card.dart';
import 'package:prostock/screens/user/dashboard/components/activity_item.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/widgets/barcode_scanner_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDashboard extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const UserDashboard({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[600]!, Colors.teal[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sales and manage inventory',
                  style: TextStyle(
                    color: Colors.white.withAlpha(230),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ActionCard(
                  title: 'Make Sale',
                  subtitle: 'Process customer transactions',
                  icon: Icons.point_of_sale,
                  color: Colors.blue,
                  onTap: () => onNavigateToTab(1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ActionCard(
                  title: 'Scan Barcode',
                  subtitle: 'Scan items for stock management',
                  icon: Icons.qr_code_scanner,
                  color: Colors.green,
                  onTap: () => onNavigateToTab(2),
                ),
              ),
            ],
          ),
          if (authProvider.isAdmin) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ActionCard(
                    title: 'Receive Stock',
                    subtitle: 'Scan items to add to inventory',
                    icon: Icons.add_box,
                    color: Colors.green,
                    onTap: () =>
                        _openBarcodeScanner(context, ScannerMode.receiveStock),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ActionCard(
                    title: 'Remove Stock',
                    subtitle: 'Scan items to remove from inventory',
                    icon: Icons.remove_circle,
                    color: Colors.red,
                    onTap: () =>
                        _openBarcodeScanner(context, ScannerMode.removeStock),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Your Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _getUserRecentActivity(authProvider.currentUser?.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No recent activity',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final activities = snapshot.data!.take(5).toList();
                  return Column(
                    children: activities
                        .map((activity) => ActivityItem(activity: activity))
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUserRecentActivity(
    String? userId,
  ) async {
    if (userId == null) return [];

    try {
      final activityService = ActivityService(FirebaseFirestore.instance);
      final activities = await activityService.getUserActivitiesPaginated(
        role: 'user',
        limit: 10,
      );
      return activities.items.map((activity) => activity.toMap()).toList();
    } catch (e) {
      return [];
    }
  }

  void _openBarcodeScanner(BuildContext context, ScannerMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => BarcodeScannerWidget(mode: mode)),
    );
  }
}
