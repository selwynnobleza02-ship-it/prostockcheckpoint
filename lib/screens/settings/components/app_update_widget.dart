import 'package:flutter/material.dart';

class AppUpdateWidget extends StatelessWidget {
  const AppUpdateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Updates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Maintenance Announcement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The app will be down for maintenance on Sunday at 2:00 AM for approximately 2 hours.',
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // In a real app, this would trigger an update check.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No new updates available.'),
                      ),
                    );
                  },
                  child: const Text('Check for Updates'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
