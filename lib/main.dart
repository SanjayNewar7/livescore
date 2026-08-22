import 'package:flutter/material.dart';
import 'package:livescore/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/screens/splash_screen.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/services/cache_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/services/profile_service.dart';
import 'package:livescore/services/quiz_service.dart';
import 'package:livescore/services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:livescore/screens/home_screen.dart';
import 'package:livescore/screens/teams_screen.dart';
import 'package:livescore/screens/standings_screen.dart';
import 'package:livescore/screens/news_screen.dart';
import 'package:livescore/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
  } catch (e) {
    print('[Main] Hive.initFlutter error: $e');
  }

  try {
    await CacheService().init();
  } catch (e) {
    print('[Main] CacheService init error: $e');
  }
  try {
    await PreferencesService().init();
  } catch (e) {
    print('[Main] PreferencesService init error: $e');
  }
  try {
    await ProfileService().init();
  } catch (e) {
    print('[Main] ProfileService init error: $e');
  }
  try {
    await QuizService().init();
  } catch (e) {
    print('[Main] QuizService init error: $e');
  }
  try {
    await NotificationService().init();
  } catch (e) {
    print('[Main] NotificationService init error: $e');
  }

  print('[Main] Service initialization complete');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'Livescore',
            debugShowCheckedModeBanner: false,
            theme: provider.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) {
              return _NetworkErrorWrapper(child: child);
            },
            initialRoute: '/',
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => _getInitialScreen(),
          settings: settings,
        );
      case '/home':
        return MaterialPageRoute(
          builder: (_) => const MainNavigationWrapper(),
          settings: settings,
        );
      case '/onboarding':
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );
      case '/standings':
      // Optional league code passed as the route argument (e.g. from
      // tapping a favourited league on the home screen). Falls back to
      // the default FIFA World Cup view when no argument is supplied.
        final leagueCode = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => StandingsScreen(initialLeagueCode: leagueCode),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationWrapper(),
          settings: settings,
        );
    }
  }

  Widget _getInitialScreen() {
    try {
      final hasCompleted = PreferencesService().hasCompletedOnboarding;
      return hasCompleted ? const SplashScreen() : const OnboardingScreen();
    } catch (e) {
      return const OnboardingScreen();
    }
  }
}

// ─── Main Navigation Wrapper ──────────────────────────────────────────────────

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      HomeScreen(),
      TeamsScreen(),
      StandingsScreen(),
      NewsScreen(),
      SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer_rounded),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Teams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_rounded),
            label: 'Standings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_rounded),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        selectedItemColor: const Color(0xFF16A34A),
        unselectedItemColor: const Color(0xFF6B7A96),
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Network Error Wrapper ────────────────────────────────────────────────────

class _NetworkErrorWrapper extends StatelessWidget {
  final Widget? child;

  const _NetworkErrorWrapper({this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (child != null) child!,
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _NetworkStatusBanner(),
          ),
        ],
      ),
    );
  }
}

// ─── Network Status Banner ────────────────────────────────────────────────────

class _NetworkStatusBanner extends StatefulWidget {
  const _NetworkStatusBanner();

  @override
  State<_NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<_NetworkStatusBanner> {
  ConnectivityResult _connectivityStatus = ConnectivityResult.wifi;
  bool _isOffline = false;
  late Stream<ConnectivityResult> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen((result) {
      setState(() {
        _connectivityStatus = result;
        _isOffline = result == ConnectivityResult.none;
      });

      if (_isOffline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Some features may be limited.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectivityStatus = result;
      _isOffline = result == ConnectivityResult.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade700,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No internet connection',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _checkConnectivity,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}