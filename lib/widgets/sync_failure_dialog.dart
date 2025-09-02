import 'package:flutter/material.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:provider/provider.dart';

class SyncFailureDialog extends StatelessWidget {
  const SyncFailureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Failures'),
      content: Consumer<SyncFailureProvider>(
        builder: (context, provider, child) {
          if (provider.failures.isEmpty) {
            return const Text('No sync failures.');
          }

          return SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.failures.length,
              itemBuilder: (context, index) {
                final failure = provider.failures[index];
                return ListTile(
                  title: Text('Operation: ${failure.operation.type.toString().split('.').last}'),
                  subtitle: Text('Error: ${failure.error}'),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Provider.of<SyncFailureProvider>(context, listen: false).clearFailures();
            Navigator.of(context).pop();
          },
          child: const Text('Clear and Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
