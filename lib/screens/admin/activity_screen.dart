import 'package:flutter/material.dart';
import 'package:prostock/screens/admin/system_monitoring_screen.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/models/user_role.dart';
import 'package:prostock/widgets/sync_status_indicator.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity & Monitoring'),
          actions: const [SyncStatusIndicator()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activity'),
              Tab(text: 'Status'),
              Tab(text: 'Pending'),
              Tab(text: 'Failures'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            UserActivityList(),
            SyncStatusWidget(),
            PendingOperationsWidget(),
            SyncFailuresWidget(),
          ],
        ),
      ),
    );
  }
}

class UserActivityList extends StatefulWidget {
  const UserActivityList({super.key});

  @override
  State<UserActivityList> createState() => _UserActivityListState();
}

class _UserActivityListState extends State<UserActivityList> {
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
    _activityStream = context
        .read<ActivityService>()
        .getAllUserActivitiesStream();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await context.read<AuthProvider>().getAllUsersList();
    if (mounted) {
      setState(() {
        _usersMap = {for (var user in users) user.id!: user};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserActivity>>(
      stream: _activityStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _usersMap.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No activities found.'));
        }

        final activities = snapshot.data!;

        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final username =
                _usersMap[activity.userId]?.username ?? _unknownUser.username;
            return ListTile(
              title: Text('${activity.action} by $username'),
              subtitle: Text(activity.details ?? ''),
              trailing: Text('${activity.timestamp.toLocal()}'.split(' ')[0]),
            );
          },
        );
      },
    );
  }
}
