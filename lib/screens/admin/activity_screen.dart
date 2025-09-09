import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/app_user.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String? _selectedUserId;
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await context.read<AuthProvider>().getAllUsers();
    setState(() {
      _users = users;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Activities"),
        centerTitle: true,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Dropdown filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String?>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('Select User'),
                  value: _selectedUserId,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedUserId = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Users'),
                    ),
                    ..._users.map<DropdownMenuItem<String?>>((AppUser user) {
                      return DropdownMenuItem<String?>(
                        value: user.id,
                        child: Text(user.username),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Activities List
          Expanded(
            child: StreamBuilder<List<UserActivity>>(
              stream: ActivityService(
                FirebaseFirestore.instance,
              ).getActivitiesStream(userId: _selectedUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No activities found.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final activities = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final formattedDate = DateFormat(
                      "MMM dd, yyyy • hh:mm a",
                    ).format(activity.timestamp);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            Icons.history,
                            color: Colors.blue,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          activity.action,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activity.details != null &&
                                activity.details!.isNotEmpty)
                              Text(
                                activity.details!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
