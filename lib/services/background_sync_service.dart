import 'dart:developer';

import 'package:background_fetch/background_fetch.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:prostock/services/credit_check_service.dart';
import 'package:prostock/services/demand_analysis_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/notification_service.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:prostock/utils/error_logger.dart';

const _backgroundFetchTaskId = 'com.prostock.background_fetch';

class BackgroundSyncService {
  static late OfflineManager _offlineManager;
  static late CreditCheckService _creditCheckService;
  static late DemandAnalysisService _demandService;

  static Future<void> init(
    OfflineManager offlineManager,
    CreditCheckService creditCheckService,
  ) async {
    _offlineManager = offlineManager;
    _creditCheckService = creditCheckService;
    _demandService = DemandAnalysisService(
      LocalDatabaseService.instance,
      NotificationService(),
    );
    BackgroundFetch.configure(
          BackgroundFetchConfig(
            minimumFetchInterval: 15,
            stopOnTerminate: false,
            enableHeadless: true,
            startOnBoot: true,
            requiredNetworkType: NetworkType.ANY,
          ),
          _onBackgroundFetch,
          _onBackgroundFetchTimeout,
        )
        .then((int status) {
          log('[BackgroundFetch] configure success: $status');
        })
        .catchError((e) {
          log('[BackgroundFetch] configure ERROR: $e');
        });
  }

  static void _onBackgroundFetch(String taskId) async {
    if (taskId == _backgroundFetchTaskId) {
      try {
        await _offlineManager.syncPendingOperations();
        await _creditCheckService.checkDuePaymentsAndNotify();
        // Run demand analysis once per day implicitly by BackgroundFetch cadence
        await _demandService.runDailyAndNotify();
      } catch (e, s) {
        ErrorLogger.logError(
          'Error in background fetch',
          error: e,
          stackTrace: s,
          context: 'BackgroundSyncService._onBackgroundFetch',
        );
      }
    }
    BackgroundFetch.finish(taskId);
  }

  static void _onBackgroundFetchTimeout(String taskId) {
    BackgroundFetch.finish(taskId);
  }
}

void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  if (isTimeout) {
    // This task has exceeded its allowed running-time.
    // You must stop what you're doing and immediately call `BackgroundFetch.finish(taskId)`.
    BackgroundFetch.finish(taskId);
    return;
  }

  if (taskId == _backgroundFetchTaskId) {
    try {
      // This is not ideal, but we need to create a new instance of OfflineManager
      // to be able to sync in the background.
      final syncFailureProvider = SyncFailureProvider();
      final offlineManager = OfflineManager(syncFailureProvider);
      final localDatabaseService = LocalDatabaseService.instance;
      final notificationService = NotificationService();
      final creditCheckService = CreditCheckService(
        localDatabaseService,
        notificationService,
      );
      final demandService = DemandAnalysisService(
        localDatabaseService,
        notificationService,
      );
      await offlineManager.initialize();
      await offlineManager.syncPendingOperations();
      await creditCheckService.checkDuePaymentsAndNotify();
      await demandService.runDailyAndNotify();
    } catch (e, s) {
      ErrorLogger.logError(
        'Error in background fetch headless task',
        error: e,
        stackTrace: s,
        context: 'backgroundFetchHeadlessTask',
      );
    }
  }

  BackgroundFetch.finish(taskId);
}
