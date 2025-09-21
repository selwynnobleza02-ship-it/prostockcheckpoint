import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/services/offline_manager.dart';

class SyncStatusIndicator extends StatelessWidget {
  final Color? color;
  final EdgeInsetsGeometry? padding;
  const SyncStatusIndicator({super.key, this.color, this.padding});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineManager>(
      builder: (context, offlineManager, child) {
        final isOnline = offlineManager.isOnline;
        final isSyncing = offlineManager.isSyncing;
        final total = offlineManager.totalOperationsToSync;
        final progress = offlineManager.syncProgress;
        final hasPending = offlineManager.pendingOperationsCount > 0;

        Widget icon;
        String tooltip;

        if (!isOnline) {
          icon = const Icon(Icons.cloud_off, color: Colors.orangeAccent);
          tooltip = 'Offline - operations will be queued';
        } else if (isSyncing) {
          icon = Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const Icon(Icons.cloud_sync, size: 16),
            ],
          );
          tooltip = 'Syncing $progress / $total';
        } else if (hasPending) {
          icon = const Icon(Icons.cloud_queue, color: Colors.orangeAccent);
          tooltip = 'Pending operations: $total';
        } else {
          icon = const Icon(Icons.cloud_done, color: Colors.lightGreen);
          tooltip = 'All changes synced';
        }

        return Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 8),
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                if (isOnline && hasPending && !isSyncing) {
                  await offlineManager.syncPendingOperations();
                }
              },
              child: icon,
            ),
          ),
        );
      },
    );
  }
}
