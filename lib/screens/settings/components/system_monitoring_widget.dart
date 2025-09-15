import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/services/firestore/activity_service.dart';

class SystemMonitoringWidget extends StatelessWidget {
  const SystemMonitoringWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final activityService = Provider.of<ActivityService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Monitoring',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text('Recent User Activity:'),
        SizedBox(
          height: 200,
          child: StreamBuilder<List<UserActivity>>(
            stream: activityService.getAllUserActivitiesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No recent activity.'));
              }

              final activities = snapshot.data!;

              return ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return ListTile(
                    title: Text('\${activity.action} by \${activity.userId}'),
                    subtitle: Text(activity.details ?? ''),
                    trailing: Text(activity.timestamp.toString()),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
