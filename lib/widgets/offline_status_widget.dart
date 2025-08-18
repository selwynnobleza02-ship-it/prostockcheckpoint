import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_manager.dart';

class OfflineStatusWidget extends StatelessWidget {
  const OfflineStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineManager>(
      builder: (context, offlineManager, child) {
        if (offlineManager.isOnline &&
            offlineManager.pendingOperationsCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: offlineManager.isOnline
                ? Colors.orange.shade100
                : Colors.red.shade100,
            border: Border(
              bottom: BorderSide(
                color: offlineManager.isOnline ? Colors.orange : Colors.red,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                offlineManager.isOnline
                    ? (offlineManager.isSyncing
                          ? Icons.sync
                          : Icons.cloud_queue)
                    : Icons.cloud_off,
                color: offlineManager.isOnline
                    ? Colors.orange.shade700
                    : Colors.red.shade700,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStatusMessage(offlineManager),
                  style: TextStyle(
                    color: offlineManager.isOnline
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (offlineManager.pendingOperationsCount > 0 &&
                  offlineManager.isOnline)
                TextButton(
                  onPressed: offlineManager.isSyncing
                      ? null
                      : () {
                          offlineManager.syncPendingOperations();
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    offlineManager.isSyncing ? 'Syncing...' : 'Sync Now',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusMessage(OfflineManager offlineManager) {
    if (!offlineManager.isOnline) {
      if (offlineManager.pendingOperationsCount > 0) {
        return 'Offline - ${offlineManager.pendingOperationsCount} changes pending sync';
      }
      return 'Offline - Changes will sync when connection is restored';
    }

    if (offlineManager.isSyncing) {
      return 'Syncing ${offlineManager.pendingOperationsCount} pending changes...';
    }

    if (offlineManager.pendingOperationsCount > 0) {
      return '${offlineManager.pendingOperationsCount} changes waiting to sync';
    }

    return 'All changes synced';
  }
}
