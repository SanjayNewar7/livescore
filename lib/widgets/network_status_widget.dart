import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatusWidget extends StatefulWidget {
  final Widget child;

  const NetworkStatusWidget({super.key, required this.child});

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  ConnectivityResult _connectivityStatus = ConnectivityResult.wifi;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _connectivityStatus = result;
        _showBanner = result == ConnectivityResult.none;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectivityStatus = result;
      _showBanner = result == ConnectivityResult.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No Internet Connection',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Please check your network settings',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _checkConnectivity,
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}