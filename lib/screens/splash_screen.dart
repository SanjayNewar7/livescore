import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livescore/providers/app_provider.dart';
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
  late final Animation<double> _fadeAnimation;

  bool _hasError = false;
  String? _errorMessage;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // ─── Rotating Slogans ────────────────────────────────────────────────
  static const List<String> _slogans = [
    ' Live Scores. Instant Updates.',
    ' Your Ultimate Football Companion.',
    ' Every Goal. Every Moment.',
    ' Never Miss a Match Again.',
    ' Real-time Stats at Your Fingertips.',
    ' Global Football, One App.',
    ' Where Football Lives.',
    ' Score Predictions & Analysis.',
    ' Football in Your Pocket.',
    ' Faster Than the Final Whistle.',
    '️ From Kickoff to Final Whistle.',
    ' Your Matchday Essential.',
    ' Live Tables, Live Thrills.',
    ' The Pulse of Football.',
    ' Your Daily Football Fix.',
  ];

  int _currentSloganIndex = 0;
  Timer? _sloganTimer;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0E7C39);
  static const Color _white = Color(0xFFFFFFFF);

  static const Duration _minimumSplashTime = Duration(milliseconds: 1800);
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();

    _stopwatch.start();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _logoController.forward();

    // Start rotating slogans every 2.5 seconds
    _sloganTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        setState(() {
          _currentSloganIndex = (_currentSloganIndex + 1) % _slogans.length;
        });
      }
    });

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
              _errorMessage = 'No internet connection.\nPlease check your network.';
            });
          }
        });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity == ConnectivityResult.none) {
        setState(() {
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

      Navigator.pushReplacementNamed(context, '/home');
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _errorMessage = 'Connection timeout.\nPlease try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _errorMessage = 'Something went wrong.\nPlease try again.';
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _logoController.dispose();
    _sloganTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF16A34A),
              Color(0xFF0E7C39),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _hasError
                ? _buildErrorWidget()
                : _buildSplashContent(),
          ),
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
            // ── App Icon ──────────────────────────────────────────────
            ScaleTransition(
              scale: _logoAnimation,
              child: Image.asset(
                'assets/icons/app_icon_bg.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 32),

            // ── App Name ──────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'LiveGoal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Rotating Slogan ──────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(_currentSloganIndex),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _slogans[_currentSloganIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),

            // ── Loading Indicator ──────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Loading matches...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),

            // ── Footer ──────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Real-time scores from 50+ leagues worldwide',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
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
            // ── Error Icon ──────────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),

            // ── Error Title ─────────────────────────────────────────────
            const Text(
              'Connection Lost',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // ── Error Message ──────────────────────────────────────────
            Text(
              _errorMessage ?? 'Unable to connect to the server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),

            // ── Retry Button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _initializeApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Skip Button ────────────────────────────────────────────
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.7),
              ),
              child: Text(
                'Continue with cached data',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}