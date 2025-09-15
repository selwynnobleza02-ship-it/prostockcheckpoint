import 'package:flutter/material.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sync_failure_provider.dart';

class SystemMonitoringScreen extends StatelessWidget {
  const SystemMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('System Monitoring'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Status'),
              Tab(text: 'Pending'),
              Tab(text: 'Failures'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SyncStatusWidget(),
            PendingOperationsWidget(),
            SyncFailuresWidget(),
          ],
        ),
      ),
    );
  }
}

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineManager = Provider.of<OfflineManager>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sync Status', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Connectivity'),
            trailing: Text(offlineManager.isOnline ? 'Online' : 'Offline'),
          ),
          ListTile(
            title: const Text('Syncing'),
            trailing: Text(offlineManager.isSyncing ? 'In Progress' : 'Idle'),
          ),
          ListTile(
            title: const Text('Last Sync Time'),
            trailing: Text(
              offlineManager.lastSyncTime?.toLocal().toString() ?? 'Never',
            ),
          ),
          ListTile(
            title: const Text('Pending Operations'),
            trailing: Text(offlineManager.pendingOperationsCount.toString()),
          ),
        ],
      ),
    );
  }
}

class PendingOperationsWidget extends StatelessWidget {
  const PendingOperationsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineManager = Provider.of<OfflineManager>(context);
    final pendingOperations = offlineManager.pendingOperations;

    if (pendingOperations.isEmpty) {
      return const Center(child: Text('No pending operations.'));
    }

    return ListView.builder(
      itemCount: pendingOperations.length,
      itemBuilder: (context, index) {
        final operation = pendingOperations[index];
        return ListTile(
          title: Text(operation.type.toString().split('.').last),
          subtitle: Text('ID: ${operation.id}'),
          trailing: Text('Retries: ${operation.retryCount}'),
        );
      },
    );
  }
}

class SyncFailuresWidget extends StatelessWidget {
  const SyncFailuresWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final syncFailureProvider = Provider.of<SyncFailureProvider>(context);
    final failures = syncFailureProvider.failures;

    if (failures.isEmpty) {
      return const Center(child: Text('No sync failures.'));
    }

    return ListView.builder(
      itemCount: failures.length,
      itemBuilder: (context, index) {
        final failure = failures[index];
        return ListTile(
          title: Text(failure.operation.type.toString().split('.').last),
          subtitle: Text(failure.error),
          trailing: Text(
            failure.operation.timestamp.toLocal().toString().split(' ')[0],
          ),
        );
      },
    );
  }
}
