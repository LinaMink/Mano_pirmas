import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class DailyWidgetManager {
  static const String widgetName = 'DailyMessageWidget';

  // Inicializuoti widget'ą
  static Future<void> initializeWidget() async {
    try {
      // iOS reikalauja app group ID
      await HomeWidget.setAppGroupId('group.lockscreenlove');
    } catch (e) {
      debugPrint('⚠️ Widget initialization error: $e');
    }
  }

  // Atnaujinti widget'ą su žinute
  static Future<void> updateWidget({
    required String message,
    required String writerName,
  }) async {
    try {
      // Išsaugoti duomenis
      await HomeWidget.saveWidgetData<String>('daily_message', message);
      await HomeWidget.saveWidgetData<String>('writer_name', writerName);
      await HomeWidget.saveWidgetData<String>(
        'last_update',
        DateTime.now().toIso8601String(),
      );

      // Atnaujinti widget'ą
      await HomeWidget.updateWidget(
        iOSName: 'DailyMessageWidget',
        androidName: 'HomeWidgetProvider',
      );

      final displayMessage = message.length > 30
          ? '${message.substring(0, 30)}...'
          : message;
      debugPrint('✅ Widget updated: $displayMessage');
    } catch (e) {
      debugPrint('❌ Widget update failed: $e');
      // Fallback: išsaugoti į SharedPreferences tiesiogiai
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('daily_message_backup', message);
        await prefs.setString('writer_name_backup', writerName);
      } catch (e2) {
        debugPrint('❌ Backup failed: $e2');
      }
    }
  }

  // Gauti paskutinę žinutę
  static Future<Map<String, String>> getLastMessage() async {
    try {
      final message = await HomeWidget.getWidgetData<String>(
        'daily_message',
        defaultValue: 'Tu esi nuostabus! ❤️',
      );
      final writer = await HomeWidget.getWidgetData<String>(
        'writer_name',
        defaultValue: '',
      );
      final lastUpdate = await HomeWidget.getWidgetData<String>(
        'last_update',
        defaultValue: '',
      );

      return {
        'message': message ?? 'Tu esi nuostabus! ❤️',
        'writer': writer ?? '',
        'last_update': lastUpdate ?? '',
      };
    } catch (e) {
      debugPrint('⚠️ Get last message failed: $e');
      return {
        'message': 'Tu esi nuostabus! ❤️',
        'writer': '',
        'last_update': '',
      };
    }
  }

  // Supaprastinta versija - grąžina visada false
  static Future<bool> isWidgetAdded() async {
    return false;
  }
}
