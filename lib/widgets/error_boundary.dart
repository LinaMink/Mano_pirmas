import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Catch Flutter framework errors
    FlutterError.onError = (details) {
      _handleError(details.exception, details.stack);
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    debugPrint('ErrorBoundary: $error\n$stackTrace');

    if (mounted) {
      setState(() {
        _hasError = true;
        _error = error;
      });

      widget.onError?.call();

      // Report to Firebase Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _defaultFallback();
    }

    return widget.child;
  }

  Widget _defaultFallback() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Įvyko klaida',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _error?.toString() ?? 'Nežinoma klaida',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _error = null;
                  });
                },
                child: const Text('Bandyti iš naujo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    FlutterError.onError = null;
    super.dispose();
  }
}
