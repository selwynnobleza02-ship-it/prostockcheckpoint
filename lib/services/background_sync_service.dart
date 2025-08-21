import 'package:background_fetch/background_fetch.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:prostock/utils/error_logger.dart';

const _backgroundFetchTaskId = 'com.prostock.background_fetch';

class BackgroundSyncService {
  static Future<void> init() async {
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
    ).then((int status) {
      print('[BackgroundFetch] configure success: $status');
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
    });
  }

  static void _onBackgroundFetch(String taskId) async {
    if (taskId == _backgroundFetchTaskId) {
      try {
        await OfflineManager.instance.syncPendingOperations();
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
      await OfflineManager.instance.syncPendingOperations();
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
