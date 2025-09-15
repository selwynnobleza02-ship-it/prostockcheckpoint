import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/models/user_role.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Stream<List<UserActivity>> _activityStream;
  Map<String, AppUser> _usersMap = {};
  final AppUser _unknownUser = AppUser(
    id: '',
    username: 'Unknown',
    email: '',
    passwordHash: '',
    role: UserRole.user,
    createdAt: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _activityStream = context.read<ActivityService>().getAllUserActivitiesStream();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await context.read<AuthProvider>().getAllUsersList();
    setState(() {
      _usersMap = {for (var user in users) user.id!: user};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Activity')),
      body: StreamBuilder<List<UserActivity>>(
        stream: _activityStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _usersMap.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No activities found.'));
          }

          final activities = snapshot.data!;

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final username = _usersMap[activity.userId]?.username ?? _unknownUser.username;
              return ListTile(
                title: Text('\${activity.action} by $username'),
                subtitle: Text(activity.details ?? ''),
                trailing: Text(
                  '\${activity.timestamp.toLocal()}'.split(' ')[0],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
