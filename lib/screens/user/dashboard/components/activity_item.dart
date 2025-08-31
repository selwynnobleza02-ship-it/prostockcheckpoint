import 'package:flutter/material.dart';

class ActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.parse(activity['timestamp']);
    final timeAgo = _getTimeAgo(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getActionColor(activity['action']),
            radius: 16,
            child: Icon(
              _getActionIcon(activity['action']),
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['action'].toString().replaceAll('_', ' '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (activity['product_name'] != null)
                  Text(
                    activity['product_name'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'STOCK_RECEIVED':
        return Colors.green;
      case 'STOCK_REMOVED':
        return Colors.red;
      case 'PRODUCT_SCANNED':
        return Colors.blue;
      case 'SALE_MADE':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'STOCK_RECEIVED':
        return Icons.add_box;
      case 'STOCK_REMOVED':
        return Icons.remove_circle;
      case 'PRODUCT_SCANNED':
        return Icons.qr_code_scanner;
      case 'SALE_MADE':
        return Icons.point_of_sale;
      default:
        return Icons.help_outline;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Now';
    }
  }
}
