import 'package:flutter/material.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/screens/admin/components/activity_list.dart';
import 'package:prostock/screens/admin/components/filter_section.dart';
import 'package:prostock/screens/admin/components/stats_header.dart';
import 'package:prostock/services/firestore_service.dart';

class AdminActivityMonitor extends StatefulWidget {
  const AdminActivityMonitor({super.key});

  @override
  State<AdminActivityMonitor> createState() => _AdminActivityMonitorState();
}

class _AdminActivityMonitorState extends State<AdminActivityMonitor> {
  List<Map<String, dynamic>> _activities = [];
  List<AppUser> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedUserId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final activities =
          await FirestoreService.instance.getAllUserActivitiesWithUsernames();
      final users = await FirestoreService.instance.getAllUsers();

      if (mounted) {
        setState(() {
          _activities = activities;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredActivities {
    return _activities.where((activity) {
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch =
            activity['username'].toString().toLowerCase().contains(
                  searchLower,
                ) ||
                activity['action'].toString().toLowerCase().contains(searchLower) ||
                (activity['product_name']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (activity['details']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false);

        if (!matchesSearch) return false;
      }

      if (_selectedUserId != null && activity['user_id'] != _selectedUserId) {
        return false;
      }

      if (_startDate != null || _endDate != null) {
        final activityDate = DateTime.parse(activity['timestamp']);
        if (_startDate != null && activityDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null &&
            activityDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        StatsHeader(users: _users, activities: _activities),
        FilterSection(
          users: _users,
          selectedUserId: _selectedUserId,
          onUserChanged: (value) {
            setState(() => _selectedUserId = value);
          },
          onDateRangePressed: _showDateRangePicker,
          startDate: _startDate,
          endDate: _endDate,
          onSearchChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ActivityList(activities: _filteredActivities),
      ],
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}

