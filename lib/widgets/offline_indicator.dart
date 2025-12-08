import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineIndicator extends StatefulWidget {
  final Widget child;

  const OfflineIndicator({super.key, required this.child});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      _handleConnectivityChange(result);
    });
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (!mounted) return;

    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });

    if (_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prisijungta prie interneto'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nėra interneto ryšio. Veikiama offline režimu.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        if (!_isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
