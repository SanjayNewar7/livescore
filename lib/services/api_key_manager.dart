// lib/services/api_key_manager.dart
import 'package:livescore/utils/constants.dart';

class ApiKeyManager {
  static final ApiKeyManager _instance = ApiKeyManager._internal();
  factory ApiKeyManager() => _instance;
  ApiKeyManager._internal();

  // ─── SINGLE API KEY ──────────────────────────────────────────────────────
  // Using only one API key to avoid suspension issues
  final String _apiKey = AppConstants.apiFootballKey;

  // Rate limit tracking
  int _dailyRequests = 0;
  int _minuteRequests = 0;
  DateTime? _dailyResetTime;
  DateTime? _minuteResetTime;
  DateTime? _lastRequestTime;

  static const int _dailyLimit = 100;
  static const int _minuteLimit = 10;
  static const Duration _cooldown = Duration(milliseconds: 500);

  /// Get the API key if rate limits allow
  String getNextKey() {
    final now = DateTime.now();

    // Check daily limit
    if (_dailyRequests >= _dailyLimit) {
      if (_dailyResetTime != null && now.isAfter(_dailyResetTime!)) {
        // Reset daily count
        _dailyRequests = 0;
        _dailyResetTime = now.add(const Duration(days: 1));
        _minuteRequests = 0;
        _minuteResetTime = now.add(const Duration(minutes: 1));
        print('[ApiKeyManager] Daily limit reset');
      } else {
        print('[ApiKeyManager] ⚠️ Daily limit reached ($_dailyLimit/$_dailyLimit)');
        // Wait and retry
        Future.delayed(const Duration(seconds: 2));
        return _apiKey;
      }
    }

    // Check minute limit
    if (_minuteRequests >= _minuteLimit) {
      if (_minuteResetTime != null && now.isAfter(_minuteResetTime!)) {
        // Reset minute count
        _minuteRequests = 0;
        _minuteResetTime = now.add(const Duration(minutes: 1));
        print('[ApiKeyManager] Minute limit reset');
      } else {
        final waitSeconds = _minuteResetTime != null
            ? _minuteResetTime!.difference(now).inSeconds + 1
            : 10;
        print('[ApiKeyManager] ⚠️ Minute limit reached. Wait $waitSeconds seconds');
        // Wait and retry
        Future.delayed(Duration(seconds: waitSeconds));
        return _apiKey;
      }
    }

    // Check cooldown
    if (_lastRequestTime != null) {
      final diff = now.difference(_lastRequestTime!);
      if (diff < _cooldown) {
        return _apiKey;
      }
    }

    print('[ApiKeyManager] Using API key (minute: $_minuteRequests/$_minuteLimit, daily: $_dailyRequests/$_dailyLimit)');
    return _apiKey;
  }

  /// Mark a request as made
  void markRequest(String key) {
    final now = DateTime.now();
    _dailyRequests++;
    _minuteRequests++;
    _lastRequestTime = now;

    if (_dailyResetTime == null) {
      _dailyResetTime = now.add(const Duration(days: 1));
    }
    if (_minuteResetTime == null) {
      _minuteResetTime = now.add(const Duration(minutes: 1));
    }

    print('[ApiKeyManager] 📊 Request marked: daily=$_dailyRequests/$_dailyLimit, minute=$_minuteRequests/$_minuteLimit');
  }

  /// Check if the key can be used
  bool canUseKey() {
    final now = DateTime.now();

    if (_dailyRequests >= _dailyLimit) {
      if (_dailyResetTime != null && now.isAfter(_dailyResetTime!)) {
        _dailyRequests = 0;
        _dailyResetTime = now.add(const Duration(days: 1));
        _minuteRequests = 0;
        _minuteResetTime = now.add(const Duration(minutes: 1));
        return true;
      }
      return false;
    }

    if (_minuteRequests >= _minuteLimit) {
      if (_minuteResetTime != null && now.isAfter(_minuteResetTime!)) {
        _minuteRequests = 0;
        _minuteResetTime = now.add(const Duration(minutes: 1));
        return true;
      }
      return false;
    }

    if (_lastRequestTime != null) {
      final diff = now.difference(_lastRequestTime!);
      if (diff < _cooldown) {
        return false;
      }
    }

    return true;
  }

  /// Get the time until rate limit resets
  Duration getTimeUntilReset() {
    if (_minuteResetTime != null) {
      final diff = _minuteResetTime!.difference(DateTime.now());
      if (diff.isNegative) return Duration.zero;
      return diff;
    }
    return const Duration(seconds: 10);
  }

  /// Get usage stats for debugging
  Map<String, dynamic> getUsageStats() {
    return {
      'dailyRequests': _dailyRequests,
      'dailyLimit': _dailyLimit,
      'minuteRequests': _minuteRequests,
      'minuteLimit': _minuteLimit,
      'canUse': canUseKey(),
      'resetIn': getTimeUntilReset().inSeconds,
    };
  }

  /// Reset usage (for testing)
  void resetUsage() {
    _dailyRequests = 0;
    _minuteRequests = 0;
    _dailyResetTime = null;
    _minuteResetTime = null;
    _lastRequestTime = null;
    print('[ApiKeyManager] Usage reset');
  }
}