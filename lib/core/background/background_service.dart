import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/logger.dart';

const String foodiesSyncTask = 'com.foodies.app.syncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.info('Workmanager background task executed: $task');
    // Background task entry point: pending job recovery
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    // Only initialize Workmanager on Android / iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Workmanager().initialize(
          callbackDispatcher,
        );
        AppLogger.info('Workmanager initialized successfully');
      } catch (e) {
        AppLogger.error('Failed to initialize Workmanager', error: e);
      }
    }
  }

  static Future<void> schedulePeriodicSync() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Workmanager().registerPeriodicTask(
          'foodies-sync-id',
          foodiesSyncTask,
          frequency: const Duration(hours: 1),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      } catch (e) {
        AppLogger.error('Error scheduling periodic task', error: e);
      }
    }
  }
}
