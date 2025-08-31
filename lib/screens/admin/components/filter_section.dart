import 'package:flutter/material.dart';
import 'package:prostock/models/app_user.dart';

class FilterSection extends StatelessWidget {
  final List<AppUser> users;
  final String? selectedUserId;
  final Function(String?) onUserChanged;
  final Function() onDateRangePressed;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(String) onSearchChanged;

  const FilterSection({
    super.key,
    required this.users,
    required this.selectedUserId,
    required this.onUserChanged,
    required this.onDateRangePressed,
    required this.startDate,
    required this.endDate,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search activities...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  decoration: InputDecoration(
                    labelText: 'Filter by User',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  initialValue: selectedUserId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Users'),
                    ),
                    ...users.map(
                      (user) => DropdownMenuItem<String?>(
                        value: user.id,
                        child: Text(user.username),
                      ),
                    ),
                  ],
                  onChanged: onUserChanged,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onDateRangePressed,
                icon: const Icon(Icons.date_range),
                label: Text(
                  startDate != null && endDate != null
                      ? 'Custom Range'
                      : 'Date Range',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
