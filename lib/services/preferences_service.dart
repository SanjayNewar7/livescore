import 'package:hive_flutter/hive_flutter.dart';
import 'package:livescore/models/user_preferences.dart';

class PreferencesService {
  static const String _preferencesBoxName = 'user_preferences'; // Renamed to avoid conflict
  late Box _preferencesBox;

  /// Shared cap across teams, players, and leagues — up to 4 of each.
  static const int maxFavoritesPerCategory = 4;

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
      favoritePlayers: ((data['favoritePlayers'] as List?) ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
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
      'favoritePlayers': preferences.favoritePlayers,
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

  // ─── FAVORITE TEAMS (max 4) ─────────────────────────────────────────────

  /// Returns true if the team was added, false if it was already a favorite
  /// or the cap (4) was already reached.
  Future<bool> addFavoriteTeam(String teamId) async {
    final current = preferences;
    if (current.favoriteTeamIds.contains(teamId)) return false;
    if (current.favoriteTeamIds.length >= maxFavoritesPerCategory) return false;
    final newList = List<String>.from(current.favoriteTeamIds)..add(teamId);
    await savePreferences(current.copyWith(favoriteTeamIds: newList));
    return true;
  }

  Future<void> removeFavoriteTeam(String teamId) async {
    final current = preferences;
    final newList = List<String>.from(current.favoriteTeamIds)..remove(teamId);
    await savePreferences(current.copyWith(favoriteTeamIds: newList));
  }

  bool isTeamFavorite(String teamId) {
    return preferences.favoriteTeamIds.contains(teamId);
  }

  // ─── FAVORITE LEAGUES (max 4) ───────────────────────────────────────────

  /// Returns true if the league was added, false if it was already a
  /// favorite or the cap (4) was already reached.
  Future<bool> addFavoriteLeague(String leagueCode) async {
    final current = preferences;
    if (current.favoriteLeagueIds.contains(leagueCode)) return false;
    if (current.favoriteLeagueIds.length >= maxFavoritesPerCategory) return false;
    final newList = List<String>.from(current.favoriteLeagueIds)..add(leagueCode);
    await savePreferences(current.copyWith(favoriteLeagueIds: newList));
    return true;
  }

  Future<void> removeFavoriteLeague(String leagueCode) async {
    final current = preferences;
    final newList = List<String>.from(current.favoriteLeagueIds)..remove(leagueCode);
    await savePreferences(current.copyWith(favoriteLeagueIds: newList));
  }

  bool isLeagueFavorite(String leagueCode) {
    return preferences.favoriteLeagueIds.contains(leagueCode);
  }

  // ─── FAVORITE PLAYERS (max 4) ───────────────────────────────────────────

  /// [player] should contain 'id', 'name', 'image', 'team' keys.
  /// Returns true if the player was added, false if already a favorite or
  /// the cap (4) was already reached.
  Future<bool> addFavoritePlayer(Map<String, String> player) async {
    final current = preferences;
    final id = player['id'];
    if (id == null) return false;
    if (current.favoritePlayers.any((p) => p['id'] == id)) return false;
    if (current.favoritePlayers.length >= maxFavoritesPerCategory) return false;
    final newList = List<Map<String, String>>.from(current.favoritePlayers)..add(player);
    await savePreferences(current.copyWith(favoritePlayers: newList));
    return true;
  }

  Future<void> removeFavoritePlayer(String playerId) async {
    final current = preferences;
    final newList = current.favoritePlayers.where((p) => p['id'] != playerId).toList();
    await savePreferences(current.copyWith(favoritePlayers: newList));
  }

  bool isPlayerFavorite(String playerId) {
    return preferences.favoritePlayers.any((p) => p['id'] == playerId);
  }
}