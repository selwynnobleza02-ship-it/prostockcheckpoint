import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/app_user.dart';
import 'package:intl/intl.dart';
import 'package:prostock/utils/currency_utils.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String? _selectedUserId;
  List<AppUser> _users = [];
  DateTimeRange? _selectedDateRange;
  String? _selectedActivityType;

  final List<String> _activityTypes = ['User Logs', 'Completed Sales'];

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

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
      });
    }
  }

  double _calculateTotalSales(List<UserActivity> activities) {
    return activities
        .where((activity) => activity.action == 'COMPLETE_SALE')
        .fold(0.0, (sum, activity) => sum + (activity.amount ?? 0.0));
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
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
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String?>(
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('Select Activity Type'),
              value: _selectedActivityType,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedActivityType = newValue;
                });
              },
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Types'),
                ),
                ..._activityTypes.map<DropdownMenuItem<String?>>((String type) {
                  return DropdownMenuItem<String?>(
                    value: type,
                    child: Text(type),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserActivity>>(
              stream: ActivityService(
                FirebaseFirestore.instance,
              ).getActivitiesStream(
                userId: _selectedUserId,
                dateRange: _selectedDateRange,
                activityTypes: _selectedActivityType != null
                    ? [_selectedActivityType!]
                    : null,
              ),
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
                final totalSales = _calculateTotalSales(activities);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Total Sales: ${CurrencyUtils.formatCurrency(totalSales)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
