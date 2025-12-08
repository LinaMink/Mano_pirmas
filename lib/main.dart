import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'services/couple_service.dart';
import 'services/auth_service.dart';
import 'services/error_handler.dart';
import 'screens/pairing_screen.dart';
import 'widgets/offline_indicator.dart';
import 'widgets/error_boundary.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. 🔥 Inicializuoti Firebase
    debugPrint('🚀 Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');

    // 2. 💥 Įjungti Crashlytics
    debugPrint('🚀 Setting up Crashlytics...');
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('✅ Crashlytics configured');

    // 3. 🔐 Inicializuoti Authentication
    debugPrint('🚀 Initializing Authentication...');
    final authService = AuthService();
    final user = await authService.ensureAuthenticated();

    if (user != null) {
      debugPrint('✅ User authenticated: ${user.uid}');
      await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
    } else {
      debugPrint('⚠️ Anonymous auth failed, continuing without auth');
    }

    // 4. 🛡️ Firebase App Check (Optional bet rekomenduojama)
    try {
      debugPrint('🚀 Activating App Check...');
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      debugPrint('✅ App Check activated');
    } catch (e) {
      debugPrint('⚠️ App Check activation failed: $e');
    }

    // 5. 📦 Inicializuoti CoupleService
    debugPrint('🚀 Initializing CoupleService...');
    await CoupleService().initialize();
    debugPrint('✅ CoupleService initialized');

    // ✅ VISKAS OK - paleisti app
    debugPrint('🎉 All systems ready, launching app...');
    runApp(MyApp(analytics: FirebaseAnalytics.instance));
  } catch (e, stack) {
    // 🔥 KRITINĖ KLAIDA - nepavyko inicializuoti
    await ErrorHandler.logError(e, stack, context: 'main_startup', fatal: true);

    debugPrint('❌ CRITICAL ERROR on startup: $e\n$stack');

    // Bandyti paleisti net su klaida (su error screen)
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Aplikacijos klaida',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ErrorHandler.getUserFriendlyMessage(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Bandyti restart app
                      runApp(MyApp(analytics: FirebaseAnalytics.instance));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Bandyti iš naujo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics;

  const MyApp({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love Messages',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,

        // App Bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),

        // Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // ✅ PATAISYTA: CardThemeData vietoj CardTheme
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),

      // Analytics observer
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],

      // Home screen wrapped with error boundary and offline indicator
      home: ErrorBoundary(
        child: const OfflineIndicator(child: PairingScreen()),
        onError: () {
          debugPrint('❌ ErrorBoundary triggered - app crashed');
        },
      ),

      // Disable debug banner
      debugShowCheckedModeBanner: false,
    );
  }
}
