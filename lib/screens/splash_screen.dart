import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoAnimation;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _background = Colors.white;

  static const Duration _minimumSplashTime = Duration(milliseconds: 1500);
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();

    _stopwatch.start();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoController.forward();

    _listenToConnectivity();
    _initializeApp();
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
          if (!mounted) return;

          if (result == ConnectivityResult.none) {
            setState(() {
              _hasError = true;
              _isLoading = false;
              _errorMessage = 'No internet connection.\nPlease check your network.';
            });
          }
        });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity == ConnectivityResult.none) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No internet connection.\nPlease check your network.';
        });
        return;
      }

      final provider = Provider.of<AppProvider>(context, listen: false);

      await provider.init().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Initialization timeout');
        },
      );

      final elapsed = _stopwatch.elapsed;

      if (elapsed < _minimumSplashTime) {
        await Future.delayed(_minimumSplashTime - elapsed);
      }

      if (!mounted) return;

      // Use named route navigation instead of pushing new instance
      Navigator.pushReplacementNamed(context, '/home');
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Connection timeout.\nPlease try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Something went wrong.\nPlease try again.';
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _hasError
              ? _buildErrorWidget()
              : _buildSplashContent(),
        ),
      ),
    );
  }

  Widget _buildSplashContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _logoAnimation,
              child: Image.asset(
                'assets/icons/splash_logo.png',
                width: 110,
                height: 110,
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'LIVE',
                    style: TextStyle(
                      color: _primaryBlue,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  TextSpan(
                    text: 'SCORE',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Live Football Scores',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 70,
              color: _primaryBlue,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _initializeApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Use named route navigation
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Continue with cached data'),
            ),
          ],
        ),
      ),
    );
  }
}