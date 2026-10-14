import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/background/background_service.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background services (Workmanager on Android)
  try {
    await BackgroundService.initialize();
  } catch (e) {
    AppLogger.error('Failed to initialize background service', error: e);
  }

  runApp(
    const ProviderScope(
      child: FoodiesApp(),
    ),
  );
}
