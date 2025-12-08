import 'dart:async';

import 'package:flutter/material.dart';

class LoadingOverlay {
  static final Map<String, BuildContext> _contexts = {};
  static final Map<String, Timer> _timers = {};

  static void show(
    BuildContext context, {
    String? message,
    String id = 'default',
  }) {
    // Uždaryti esamą loading su tuo pačiu ID
    _hideCurrent(id);

    _contexts[id] = context;

    // Pridėti timeout (10 sekundžių)
    _timers[id] = Timer(const Duration(seconds: 10), () {
      _hideCurrent(id);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8A000000),
      builder: (context) =>
          PopScope(canPop: false, child: _LoadingDialog(message: message)),
    );
  }

  static void _hideCurrent(String id) {
    // Atšaukti timeout timer
    _timers[id]?.cancel();
    _timers.remove(id);

    try {
      final context = _contexts[id];
      if (context != null && context.mounted) {
        // Tikrinti ar galima pop tik kai mounted
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      // Ignore error if context is no longer valid
    } finally {
      // VISADA išvalyti iš map'o
      _contexts.remove(id);
    }
  }

  static void hide({String id = 'default'}) {
    _hideCurrent(id);
  }

  // Papildomas metodas uždaryti visus
  static void hideAll() {
    for (final id in _contexts.keys.toList()) {
      _hideCurrent(id);
    }
  }
}

class _LoadingDialog extends StatelessWidget {
  final String? message;

  const _LoadingDialog({this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.purple,
                strokeWidth: 3,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
