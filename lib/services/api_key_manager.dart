import 'package:livescore/utils/constants.dart';

class ApiKeyManager {
  static final ApiKeyManager _instance = ApiKeyManager._internal();
  factory ApiKeyManager() => _instance;
  ApiKeyManager._internal();

  final List<String> _keys = AppConstants.apiFootballKeys;
  int _currentIndex = 0;
  final Map<String, DateTime> _rateLimitReset = {};
  final Map<String, int> _dailyRequests = {};
  final Map<String, DateTime> _lastRequestTime = {};
  final Map<String, int> _minuteRequests = {};
  final Map<String, DateTime> _minuteReset = {};

  /// Get the next available API key
  String getNextKey() {
    if (_keys.isEmpty) {
      throw Exception('No API keys configured');
    }

    // Try to find a key that hasn't hit its rate limits
    for (int i = 0; i < _keys.length * 2; i++) {
      final key = _keys[_currentIndex];
      _currentIndex = (_currentIndex + 1) % _keys.length;

      if (_canUseKey(key)) {
        print('[ApiKeyManager] Using key: ${key.substring(0, 8)}...');
        return key;
      }
    }

    // If all keys are rate limited, wait 1 second and try again
    print('[ApiKeyManager] All keys rate limited, waiting 1 second...');
    Future.delayed(const Duration(seconds: 1));
    return _keys.first;
  }

  /// Check if a key can be used
  bool _canUseKey(String key) {
    final now = DateTime.now();

    // Check daily limit (100 requests per day)
    final dailyRequests = _dailyRequests[key] ?? 0;
    if (dailyRequests >= 100) {
      // Check if reset time has passed (next day)
      final resetTime = _rateLimitReset[key];
      if (resetTime != null && now.isAfter(resetTime)) {
        // Reset daily count
        _dailyRequests[key] = 0;
        _rateLimitReset[key] = now.add(const Duration(days: 1));
        _minuteRequests[key] = 0;
        _minuteReset[key] = now.add(const Duration(minutes: 1));
        print('[ApiKeyManager] Key ${key.substring(0, 8)}... daily limit reset');
        return true;
      }
      print('[ApiKeyManager] Key ${key.substring(0, 8)}... daily limit reached (100/100)');
      return false;
    }

    // Check minute limit (10 requests per minute)
    final minuteRequests = _minuteRequests[key] ?? 0;
    if (minuteRequests >= 10) {
      final resetTime = _minuteReset[key];
      if (resetTime != null && now.isAfter(resetTime)) {
        // Reset minute count
        _minuteRequests[key] = 0;
        _minuteReset[key] = now.add(const Duration(minutes: 1));
        print('[ApiKeyManager] Key ${key.substring(0, 8)}... minute limit reset');
        return true;
      }
      print('[ApiKeyManager] Key ${key.substring(0, 8)}... minute limit reached (10/10)');
      return false;
    }

    // Check cooldown between requests (minimum 500ms)
    final lastRequest = _lastRequestTime[key];
    if (lastRequest != null) {
      final diff = now.difference(lastRequest);
      if (diff.inMilliseconds < 500) {
        return false;
      }
    }

    return true;
  }

  /// Mark a request as made for a specific key
  void markRequest(String key) {
    final now = DateTime.now();
    _dailyRequests[key] = (_dailyRequests[key] ?? 0) + 1;
    _minuteRequests[key] = (_minuteRequests[key] ?? 0) + 1;
    _lastRequestTime[key] = now;

    // Set daily reset time if not set
    if (!_rateLimitReset.containsKey(key)) {
      _rateLimitReset[key] = now.add(const Duration(days: 1));
    }

    // Set minute reset time if not set
    if (!_minuteReset.containsKey(key)) {
      _minuteReset[key] = now.add(const Duration(minutes: 1));
    }
  }

  /// Get current usage stats for debugging
  Map<String, Map<String, dynamic>> getUsageStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final key in _keys) {
      stats[key] = {
        'daily': _dailyRequests[key] ?? 0,
        'minute': _minuteRequests[key] ?? 0,
        'dailyLimit': 100,
        'minuteLimit': 10,
      };
    }
    return stats;
  }

  /// Reset usage for all keys (for testing)
  void resetUsage() {
    _dailyRequests.clear();
    _rateLimitReset.clear();
    _lastRequestTime.clear();
    _minuteRequests.clear();
    _minuteReset.clear();
  }
}