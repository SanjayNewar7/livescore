import 'package:hive_flutter/hive_flutter.dart';
import 'package:livescore/models/user_preferences.dart';

class PreferencesService {
  static const String _preferencesBoxName = 'user_preferences'; // Renamed to avoid conflict
  late Box _preferencesBox;

  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  Future<void> init() async {
    _preferencesBox = await Hive.openBox(_preferencesBoxName);
  }

  UserPreferences get preferences {
    final data = _preferencesBox.get('preferences');
    if (data == null) {
      return UserPreferences();
    }
    return UserPreferences(
      favoriteTeamIds: List<String>.from(data['favoriteTeamIds'] ?? []),
      favoriteLeagueIds: List<String>.from(data['favoriteLeagueIds'] ?? []),
      hasCompletedOnboarding: data['hasCompletedOnboarding'] ?? false,
      isDarkMode: data['isDarkMode'] ?? false,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      liveScoreAlerts: data['liveScoreAlerts'] ?? true,
      newsAlerts: data['newsAlerts'] ?? true,
      lastSelectedLeague: data['lastSelectedLeague'] ?? 'eng.1',
    );
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    await _preferencesBox.put('preferences', {
      'favoriteTeamIds': preferences.favoriteTeamIds,
      'favoriteLeagueIds': preferences.favoriteLeagueIds,
      'hasCompletedOnboarding': preferences.hasCompletedOnboarding,
      'isDarkMode': preferences.isDarkMode,
      'notificationsEnabled': preferences.notificationsEnabled,
      'liveScoreAlerts': preferences.liveScoreAlerts,
      'newsAlerts': preferences.newsAlerts,
      'lastSelectedLeague': preferences.lastSelectedLeague,
    });
  }

  bool get hasCompletedOnboarding => preferences.hasCompletedOnboarding;

  Future<void> completeOnboarding() async {
    final current = preferences;
    await savePreferences(current.copyWith(hasCompletedOnboarding: true));
  }

  Future<void> toggleDarkMode(bool isDark) async {
    final current = preferences;
    await savePreferences(current.copyWith(isDarkMode: isDark));
  }

  Future<void> setLastSelectedLeague(String leagueCode) async {
    final current = preferences;
    await savePreferences(current.copyWith(lastSelectedLeague: leagueCode));
  }

  Future<void> addFavoriteTeam(String teamId) async {
    final current = preferences;
    if (!current.favoriteTeamIds.contains(teamId)) {
      final newList = List<String>.from(current.favoriteTeamIds)..add(teamId);
      await savePreferences(current.copyWith(favoriteTeamIds: newList));
    }
  }

  Future<void> removeFavoriteTeam(String teamId) async {
    final current = preferences;
    final newList = List<String>.from(current.favoriteTeamIds)..remove(teamId);
    await savePreferences(current.copyWith(favoriteTeamIds: newList));
  }

  bool isTeamFavorite(String teamId) {
    return preferences.favoriteTeamIds.contains(teamId);
  }
}