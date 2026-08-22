import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/services/notification_service.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/league_leader_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/search_model.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/utils/predefined_data.dart' as seed;

// ── Football keyword filter ───────────────────────────────────────────────────
bool _isFootballArticle(NewsArticle a) {
  const footballKeywords = [
    'football', 'soccer', 'fifa', 'uefa', 'premier league', 'la liga',
    'serie a', 'bundesliga', 'ligue 1', 'champions league', 'europa league',
    'world cup', 'nations league', 'mls', 'liga mx', 'brasileirao',
    'eredivisie', 'primeira liga', 'goal', 'match', 'striker', 'midfielder',
    'goalkeeper', 'winger', 'defender', 'offside', 'penalty', 'hat-trick',
    'transfer', 'manager', 'coach', 'squad', 'fixture', 'standings',
    'nil', 'kick-off', 'halftime', 'full time', 'extra time', 'shootout',
    'dribble', 'assist', 'clean sheet', 'yellow card', 'red card',
  ];
  final searchText = [
    a.headline,
    a.description,
    ...a.categories,
  ].join(' ').toLowerCase();

  return footballKeywords.any((kw) => searchText.contains(kw));
}

class AppProvider extends ChangeNotifier {
  final SportService _sportService = SportService();
  final PreferencesService _prefs = PreferencesService();
  final NotificationService _notificationService = NotificationService();

  // Local, on-device notification center — favorite-club/player news +
  // favorite-team full-time results. See services/notification_service.dart.
  int _unreadNotificationCount = 0;
  int get unreadNotificationCount => _unreadNotificationCount;

  void _refreshUnreadNotificationCount() {
    _unreadNotificationCount = _notificationService.unreadCount;
  }

  /// Scans the currently-loaded news + today's/yesterday's games for
  /// mentions of favorite clubs/players and favorite-team full-time
  /// results, and persists any new matches as notifications. Safe to call
  /// repeatedly — NotificationService de-dupes by content-derived id, so
  /// this never resets an already-read notification back to unread.
  Future<void> generateNotifications() async {
    try {
      final favTeamNames = favoriteTeamIds
          .map((id) {
        final matches = _allTeams.where((t) => t.id == id);
        if (matches.isEmpty) return null;
        final team = matches.first;
        return team.displayName.isNotEmpty ? team.displayName : team.name;
      })
          .whereType<String>()
          .toList();

      await _notificationService.generateNewsNotifications(
        articles: _news,
        favoriteTeamNames: favTeamNames,
        favoritePlayers: favoritePlayers,
      );

      // Today's games cover most same-day full-time results. A favorite
      // team's match could also have gone final just before local
      // midnight, so yesterday's games are fetched here directly through
      // SportService (which caches internally) rather than reusing
      // fetchYesterdaysMatches(), which would overwrite the Yesterday
      // tab's _allGames/_yesterdaysGames state as a side effect.
      List<Game> yesterdaysGamesForNotifications = _yesterdaysGames;
      if (yesterdaysGamesForNotifications.isEmpty) {
        try {
          yesterdaysGamesForNotifications = await _sportService.getYesterdaysMatches();
        } catch (e) {
          print('[Notifications] Could not fetch yesterday\'s games: $e');
        }
      }

      final Map<String, Game> uniqueGames = {
        for (final g in [..._todaysGames, ...yesterdaysGamesForNotifications]) g.id: g,
      };

      await _notificationService.generateMatchResultNotifications(
        games: uniqueGames.values.toList(),
        favoriteTeamIds: favoriteTeamIds,
      );

      _refreshUnreadNotificationCount();
      if (_isMounted) notifyListeners();
    } catch (e) {
      print('[Notifications] Error generating notifications: $e');
    }
  }

  /// Re-reads the unread count from NotificationService and notifies
  /// listeners. Call this after returning from a screen (e.g.
  /// NotificationScreen) that may have marked notifications as read
  /// directly through NotificationService without going through AppProvider.
  void refreshUnreadNotificationCount() {
    _refreshUnreadNotificationCount();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await _notificationService.markAllAsRead();
    _refreshUnreadNotificationCount();
    notifyListeners();
  }

  // State variables
  List<Game> _allGames = [];
  List<Game> _allLiveMatches = [];
  List<Game> _todaysGames = [];
  List<Game> _tomorrowsGames = [];
  List<Game> _yesterdaysGames = [];
  List<Game> _customGames = [];
  List<Game> _partialGames = [];
  List<Standing> _standings = [];
  List<NewsArticle> _news = [];
  List<NewsArticle> _paginatedNews = [];
  List<TeamInfo> _allTeams = [];
  bool _isLoading = false;
  bool _isLoadingPartial = false;
  String? _error;
  int _selectedBottomNavIndex = 0;
  bool _isDarkMode = false;
  bool get mounted => true;

  // Fetch status flags
  bool _isFetchingGames = false;
  bool _isFetchingStandings = false;
  bool _isFetchingNews = false;
  bool _isFetchingTeams = false;
  bool _isMounted = true;

  // ─── SEARCH STATE ────────────────────────────────────────────────────────────
  bool _isSearching = false;
  SearchResponse _searchResults = SearchResponse();
  String _searchQuery = '';
  // True whenever _searchResults came from the offline predefined dataset
  // rather than the live API (API rate-limited/down, or query unmatched).
  // The search screen uses this to show a small "showing suggestions" note.
  bool _isSearchFallback = false;

  // ─── SEARCH CACHE ────────────────────────────────────────────────────────────
  final Map<String, SearchResponse> _searchCache = {};
  static const Duration _searchCacheDuration = Duration(minutes: 5);
  final Map<String, DateTime> _searchCacheTimestamps = {};

  bool get isSearching => _isSearching;
  SearchResponse get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  bool get isSearchFallback => _isSearchFallback;

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  // News state - two-phase loading
  int _currentNewsPage = 1;
  bool _hasMoreNews = false;
  bool _isLoadingMoreNews = false;

  // Fetch-guard flags
  bool _isFetchingToday = false;
  bool _isFetchingTomorrow = false;
  bool _isFetchingYesterday = false;
  bool _isFetchingCustom = false;

  // League management
  String _currentLeagueCode = 'eng.1';
  List<Map<String, String>> _availableLeagues = [];
  bool _isLoadingLeagues = false;

  // Getters
  List<Game> get allGames => _allGames;
  List<Game> get allLiveMatches => _allLiveMatches;
  List<Game> get todaysGames => _todaysGames;
  List<Game> get tomorrowsGames => _tomorrowsGames;
  List<Game> get yesterdaysGames => _yesterdaysGames;
  List<Game> get customGames => _customGames;
  List<Game> get partialGames => _partialGames;
  List<Game> get liveGames => _allGames.where((g) => g.status == 'STATUS_LIVE').toList();
  List<Game> get upcomingGames => _allGames.where((g) => g.status != 'STATUS_LIVE' && g.status != 'STATUS_FINAL').toList();
  List<Game> get finishedGames => _allGames.where((g) => g.status == 'STATUS_FINAL').toList();

  List<Standing> get standings => _standings;
  List<NewsArticle> get news => _news;
  List<NewsArticle> get paginatedNews => _paginatedNews;
  List<TeamInfo> get allTeams => _allTeams;
  bool get isLoading => _isLoading;
  bool get isLoadingPartial => _isLoadingPartial;
  bool get isFetchingNews => _isFetchingNews;
  bool get hasMoreNews => _hasMoreNews;
  bool get isLoadingMoreNews => _isLoadingMoreNews;
  String? get error => _error;
  int get selectedBottomNavIndex => _selectedBottomNavIndex;
  bool get isDarkMode => _isDarkMode;
  String get currentLeagueCode => _currentLeagueCode;
  List<Map<String, String>> get availableLeagues => _availableLeagues;
  bool get isLoadingLeagues => _isLoadingLeagues;

  List<String> get favoriteTeamIds => _prefs.preferences.favoriteTeamIds;
  List<String> get favoriteLeagueIds => _prefs.preferences.favoriteLeagueIds;
  List<Map<String, String>> get favoritePlayers => _prefs.preferences.favoritePlayers;

  List<Game> get favoriteTeamGames => _allGames
      .where((g) => favoriteTeamIds.contains(g.awayTeam.id) || favoriteTeamIds.contains(g.homeTeam.id))
      .toList();

  // Helper method to check if an article is within last 3 days
  bool _isWithinThreeDays(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);
      return difference.inDays <= 3;
    } catch (e) {
      return true;
    }
  }

  // Check if we've reached the 3-day limit in the loaded articles
  bool hasReachedThreeDayLimit() {
    if (_paginatedNews.isEmpty) return false;

    NewsArticle? oldest;
    for (final article in _paginatedNews) {
      try {
        final date = DateTime.parse(article.publishedAt);
        if (oldest == null) {
          oldest = article;
        } else {
          final oldestDate = DateTime.parse(oldest.publishedAt);
          if (date.isBefore(oldestDate)) {
            oldest = article;
          }
        }
      } catch (e) {
        continue;
      }
    }

    if (oldest == null) return false;

    try {
      final date = DateTime.parse(oldest.publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);
      return difference.inDays > 3;
    } catch (e) {
      return false;
    }
  }

  Future<void> init() async {
    _isDarkMode = _prefs.preferences.isDarkMode;
    _currentLeagueCode = _prefs.preferences.lastSelectedLeague;
    _sportService.setLeague(_currentLeagueCode);

    _availableLeagues = AppConstants.allLeagues.map((league) {
      return {
        'id': league['code']!,
        'name': league['name']!,
        'slug': league['code']!,
        'abbreviation': league['name']!.length >= 3
            ? league['name']!.substring(0, 3).toUpperCase()
            : league['name']!.toUpperCase(),
        'flag': league['flag']!,
      };
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        fetchTodaysMatches(progressive: true),
        fetchStandingsConcurrent(),
        fetchNewsConcurrent(),
        fetchAllTeamsConcurrent(),
      ]);
      await generateNotifications();
    });
  }

  // ─── CONCURRENT FETCH METHODS ──────────────────────────────────────────────

  Future<void> fetchStandingsConcurrent() async {
    if (_isFetchingStandings) return;
    _isFetchingStandings = true;

    try {
      _standings = await _sportService.getStandings(forceRefresh: false);
      notifyListeners();
    } catch (e) {
      print('[Concurrent] Error fetching standings: $e');
    } finally {
      _isFetchingStandings = false;
    }
  }

  // ─── NEWS: Two-phase loading for better performance ─────────────────────────────────

  Future<void> fetchNewsConcurrent({bool forceRefresh = false, int page = 1}) async {
    if (_isFetchingNews) return;

    _isFetchingNews = true;
    _currentNewsPage = 1;
    _hasMoreNews = false;
    _paginatedNews = [];
    _news = [];
    notifyListeners();

    try {
      print('[News] Starting two-phase loading...');

      await _sportService.getNewsWithTwoPhase(
        league: null,
        forceRefresh: forceRefresh,
        onPhase1Complete: (initialNews) {
          print('[News] Phase 1 complete: ${initialNews.length} articles');
          _paginatedNews = initialNews;
          _news = List.from(_paginatedNews);
          _isFetchingNews = false;
          notifyListeners();
        },
        onPhase2Complete: (allNews) {
          print('[News] Phase 2 complete: ${allNews.length} total articles');
          _paginatedNews = allNews;
          _news = List.from(_paginatedNews);
          notifyListeners();
          generateNotifications();
        },
      );
    } catch (e) {
      print('[News] Error: $e');
      _isFetchingNews = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNews() async {
    print('[News] No pagination support - all articles loaded at once');
    _hasMoreNews = false;
    notifyListeners();
  }

  Future<void> refreshNews() async {
    await fetchNewsConcurrent(forceRefresh: true, page: 1);
  }

  Future<void> silentRefreshNews() async {
    if (_isFetchingNews) return;

    try {
      final freshRaw = await _sportService.getNewsWithTwoPhase(forceRefresh: true);
      if (freshRaw.isEmpty) return;

      final existingIds = _paginatedNews.map((a) => a.id).toSet();
      final newArticles = freshRaw.where((a) => !existingIds.contains(a.id)).toList();

      if (newArticles.isNotEmpty) {
        print('[SilentNews] +${newArticles.length} new articles at top');
        _paginatedNews = [...newArticles, ..._paginatedNews];
        _news = List.from(_paginatedNews);
        if (_isMounted) notifyListeners();
        generateNotifications();
      }
    } catch (e) {
      print('[SilentNews] Error: $e');
    }
  }

  Future<void> fetchAllTeamsConcurrent() async {
    if (_isFetchingTeams) return;
    _isFetchingTeams = true;

    try {
      final allLeagues = AppConstants.popularLeagues;
      final Set<String> seenIds = {};
      final List<TeamInfo> combined = [];

      final currentTeams = await _sportService.getAllTeams();
      for (final t in currentTeams) {
        if (seenIds.add(t.id)) combined.add(t);
      }

      final otherLeagues = allLeagues.where((l) => l['code'] != _currentLeagueCode).toList();
      final futures = otherLeagues.map((league) async {
        try {
          _sportService.setLeague(league['code']!);
          return await _sportService.getAllTeams();
        } catch (_) {
          return <TeamInfo>[];
        }
      });

      final results = await Future.wait(futures);
      for (final teams in results) {
        for (final t in teams) {
          if (seenIds.add(t.id)) combined.add(t);
        }
      }

      _sportService.setLeague(_currentLeagueCode);
      _allTeams = combined;
      notifyListeners();
    } catch (e) {
      print('[Concurrent] Error fetching teams: $e');
    } finally {
      _isFetchingTeams = false;
    }
  }

  // ─── TODAY with progressive loading ─────────────────────────────────────────
  Future<void> fetchTodaysMatches({bool forceRefresh = false, bool progressive = true}) async {
    if (_isFetchingToday && !forceRefresh) return;

    _isFetchingToday = true;
    _isLoadingPartial = true;
    _partialGames = [];
    _todaysGames = [];
    _error = null;
    notifyListeners();

    try {
      if (progressive) {
        _todaysGames = await _sportService.getTodaysMatchesProgressive(
          forceRefresh: forceRefresh,
          onPartialUpdate: (partialGames) {
            _partialGames = partialGames;
            _allGames = partialGames;
            notifyListeners();
          },
        );
        _partialGames = _todaysGames;
        _allGames = _todaysGames;
      } else {
        _todaysGames = await _sportService.getTodaysMatches(forceRefresh: forceRefresh);
        _allGames = _todaysGames;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingPartial = false;
      _isFetchingToday = false;
      notifyListeners();
    }
  }

  // ─── YESTERDAY ───────────────────────────────────────────────────────────────
  Future<void> fetchYesterdaysMatches({bool forceRefresh = false, bool progressive = true}) async {
    if (_isFetchingYesterday && !forceRefresh) return;

    _isFetchingYesterday = true;
    _isLoadingPartial = true;
    _partialGames = [];
    _yesterdaysGames = [];
    _error = null;
    notifyListeners();

    try {
      if (progressive) {
        _yesterdaysGames = await _sportService.getYesterdaysMatchesProgressive(
          forceRefresh: forceRefresh,
          onPartialUpdate: (partialGames) {
            _partialGames = partialGames;
            _allGames = partialGames;
            notifyListeners();
          },
        );
        _partialGames = _yesterdaysGames;
        _allGames = _yesterdaysGames;
      } else {
        _yesterdaysGames = await _sportService.getYesterdaysMatches(forceRefresh: forceRefresh);
        _allGames = _yesterdaysGames;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingPartial = false;
      _isFetchingYesterday = false;
      notifyListeners();
    }
  }

  // ─── TOMORROW ────────────────────────────────────────────────────────────────
  Future<void> fetchTomorrowsMatches({bool forceRefresh = false, bool progressive = true}) async {
    if (_isFetchingTomorrow && !forceRefresh) return;

    _isFetchingTomorrow = true;
    _isLoadingPartial = true;
    _partialGames = [];
    _tomorrowsGames = [];
    _error = null;
    notifyListeners();

    try {
      if (progressive) {
        _tomorrowsGames = await _sportService.getTomorrowsMatchesProgressive(
          forceRefresh: forceRefresh,
          onPartialUpdate: (partialGames) {
            _partialGames = partialGames;
            _allGames = partialGames;
            notifyListeners();
          },
        );
        _partialGames = _tomorrowsGames;
        _allGames = _tomorrowsGames;
      } else {
        _tomorrowsGames = await _sportService.getTomorrowsMatches(forceRefresh: forceRefresh);
        _allGames = _tomorrowsGames;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingPartial = false;
      _isFetchingTomorrow = false;
      notifyListeners();
    }
  }

  // ─── CUSTOM DATE ─────────────────────────────────────────────────────────────
  Future<void> fetchGamesByDate(String dateStr, {bool forceRefresh = false}) async {
    if (_isFetchingCustom && !forceRefresh) return;

    _isFetchingCustom = true;
    _isLoadingPartial = true;
    _partialGames = [];
    _customGames = [];
    _error = null;
    notifyListeners();

    try {
      _customGames = await _sportService.getGamesByDateFromAllLeaguesProgressive(
        dateStr,
        forceRefresh: forceRefresh,
        onPartialUpdate: (partialGames) {
          _partialGames = partialGames;
          notifyListeners();
        },
      );
      _partialGames = _customGames;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingPartial = false;
      _isFetchingCustom = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllLiveMatches({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allLiveMatches = await _sportService.getAllLiveMatches(forceRefresh: forceRefresh);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLiveScores({bool forceRefresh = false, String? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (date != null) {
        _customGames = await _sportService.getGamesByDateFromAllLeagues(date, forceRefresh: forceRefresh);
        _allGames = _customGames;
      } else {
        _allGames = await _sportService.getLiveScores(forceRefresh: forceRefresh);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStandings({bool forceRefresh = false}) async {
    try {
      _standings = await _sportService.getStandings(forceRefresh: forceRefresh);
      notifyListeners();
    } catch (e) {
      print('Error fetching standings: $e');
    }
  }

  Future<List<Standing>> fetchStandingsDirect(String leagueCode, {String? season}) async {
    try {
      _sportService.setLeague(leagueCode);
      final standings = await _sportService.getStandings(forceRefresh: true, season: season);
      return standings;
    } catch (e) {
      print('Error fetching standings: $e');
      return [];
    }
  }

  Future<LeagueLeaders> fetchLeagueLeaders(String leagueCode, {String? season}) async {
    try {
      _sportService.setLeague(leagueCode);
      return await _sportService.getLeagueLeaders(season: season);
    } catch (e) {
      print('Error fetching league leaders: $e');
      return LeagueLeaders.empty;
    }
  }

  // Legacy aliases
  Future<void> fetchNews({bool forceRefresh = false}) async =>
      fetchNewsConcurrent(forceRefresh: forceRefresh, page: 1);

  Future<void> fetchAllTeams() async => fetchAllTeamsConcurrent();

  Future<void> refreshAllData() async {
    await Future.wait([
      fetchTodaysMatches(forceRefresh: true, progressive: true),
      fetchStandingsConcurrent(),
      fetchNewsConcurrent(forceRefresh: true, page: 1),
      fetchAllTeamsConcurrent(),
    ]);
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.toggleDarkMode(_isDarkMode);
    notifyListeners();
  }

  void setBottomNavIndex(int index) {
    _selectedBottomNavIndex = index;
    notifyListeners();
  }

  Future<void> toggleFavoriteTeam(String teamId) async {
    if (favoriteTeamIds.contains(teamId)) {
      await _prefs.removeFavoriteTeam(teamId);
    } else {
      await _prefs.addFavoriteTeam(teamId);
    }
    notifyListeners();
    generateNotifications();
  }

  bool isTeamFavorite(String teamId) => _prefs.isTeamFavorite(teamId);

  // ─── FAVORITE PLAYERS (mirrors toggleFavoriteTeam above) ────────────────

  /// Removes a favorite player by id. Unlike teams, players aren't toggled
  /// on from here (there's no bare "player id" to add — onboarding's
  /// picker already has the full {id, name, image, team} map needed by
  /// PreferencesService.addFavoritePlayer), so this only supports the
  /// remove side, which is all Settings' delete-tile needs.
  Future<void> removeFavoritePlayer(String playerId) async {
    await _prefs.removeFavoritePlayer(playerId);
    notifyListeners();
  }

  bool isPlayerFavorite(String playerId) => _prefs.isPlayerFavorite(playerId);

  // ─── FAVORITE LEAGUES (mirrors toggleFavoriteTeam above) ────────────────

  Future<void> toggleFavoriteLeague(String leagueCode) async {
    if (favoriteLeagueIds.contains(leagueCode)) {
      await _prefs.removeFavoriteLeague(leagueCode);
    } else {
      await _prefs.addFavoriteLeague(leagueCode);
    }
    notifyListeners();
  }

  bool isLeagueFavorite(String leagueCode) => _prefs.isLeagueFavorite(leagueCode);

  // ─── SILENT REFRESH FOR TODAY'S GAMES ────────────────────────────────────────
  bool _isLoadingBackground = false;

  Future<void> silentRefreshToday() async {
    if (_isFetchingToday || _isLoadingBackground) return;
    _isLoadingBackground = true;

    try {
      final fresh = await _sportService.getTodaysMatchesSilent();
      if (fresh.isEmpty) return;

      bool changed = fresh.length != _todaysGames.length;
      if (!changed) {
        for (int i = 0; i < fresh.length; i++) {
          final a = fresh[i]; final b = _todaysGames[i];
          if (a.id != b.id || a.status != b.status ||
              a.awayScore != b.awayScore || a.homeScore != b.homeScore ||
              a.clock != b.clock) { changed = true; break; }
        }
      }

      if (changed) {
        _todaysGames = fresh;
        _allGames = fresh;
        notifyListeners();
        generateNotifications();
      }
    } catch (e) {
      print('[SilentRefresh] Error: $e');
    } finally {
      _isLoadingBackground = false;
    }
  }

  Future<void> loadAvailableLeagues() async {
    _isLoadingLeagues = true;
    try {
      _availableLeagues = await _sportService.getAllLeagues();
    } catch (e) {
      _availableLeagues = AppConstants.popularLeagues.map((league) => {
        'id': league['code']!,
        'name': league['name']!,
        'slug': league['code']!,
        'abbreviation': league['name']!.length >= 3
            ? league['name']!.substring(0, 3).toUpperCase()
            : league['name']!.toUpperCase(),
        'flag': league['flag']!,
      }).toList();
    } finally {
      _isLoadingLeagues = false;
      notifyListeners();
    }
  }

  // ─── SEARCH WITH CACHING ────────────────────────────────────────────────────

  Timer? _searchDebounceTimer;

  Future<void> searchWithDebounce(String query, {Duration delay = const Duration(milliseconds: 500)}) async {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(delay, () {
      search(query);
    });
  }

  /// Search with caching to reduce API calls
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchQuery = '';
      _searchResults = SearchResponse();
      _isSearching = false;
      _isSearchFallback = false;
      notifyListeners();
      return;
    }

    final cacheKey = query.trim().toLowerCase();

    // ─── Check Cache ──────────────────────────────────────────────────────────
    if (_searchCache.containsKey(cacheKey)) {
      final cached = _searchCache[cacheKey]!;
      final timestamp = _searchCacheTimestamps[cacheKey];

      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp);
        if (age < _searchCacheDuration) {
          print('[AppProvider] ✅ Using cached search result for: $query');
          _searchQuery = query;
          _searchResults = cached;
          _isSearching = false;
          _isSearchFallback = false;
          notifyListeners();
          return;
        } else {
          // Cache expired
          _searchCache.remove(cacheKey);
          _searchCacheTimestamps.remove(cacheKey);
          print('[AppProvider] Cache expired for: $query');
        }
      }
    }

    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    try {
      print('[AppProvider] 🔍 Performing fresh search for: $query');
      var results = await _sportService.search(query);
      _isSearchFallback = false;

      // ─── Predefined fallback ──────────────────────────────────────────────
      // The live search can legitimately come back empty (rate-limited,
      // API-Football's league/season restrictions, TheSportsDB missing a
      // player, transient network blip, etc).
      if (results.isEmpty) {
        // 1) Try to match the query against our small seed dataset first
        //    (e.g. user searched "Ronaldo" and it happens to be one of the
        //    10 predefined famous players).
        final matched = _predefinedSearchFallback(query);
        if (matched.isNotEmpty) {
          print('[AppProvider] ℹ️ Live search empty, using matched predefined data for: $query');
          results = matched;
          _isSearchFallback = true;
        } else {
          // 2) The query doesn't match anyone in the seed dataset either
          //    (e.g. "Mohanad Lashin") — rather than leaving the user with
          //    a dead "no results" screen when the live API is down/rate
          //    limited, surface generic trending suggestions instead so
          //    there's still something useful on screen.
          final trending = _predefinedTrendingSuggestions();
          if (trending.isNotEmpty) {
            print('[AppProvider] ℹ️ Live search empty & no seed match, showing trending suggestions for: $query');
            results = trending;
            _isSearchFallback = true;
          }
        }
      }

      // ─── Cache Results ──────────────────────────────────────────────────────
      // Note: fallback results are intentionally NOT cached — they're a
      // stand-in for a live API that's currently unavailable/rate-limited,
      // and caching them would keep serving stale suggestions even after
      // the live API recovers.
      if (results.isNotEmpty && !_isSearchFallback) {
        _searchCache[cacheKey] = results;
        _searchCacheTimestamps[cacheKey] = DateTime.now();

        // Clean old cache entries (keep last 20)
        if (_searchCache.length > 20) {
          final keys = _searchCache.keys.toList();
          // Sort by timestamp (oldest first)
          keys.sort((a, b) {
            final t1 = _searchCacheTimestamps[a] ?? DateTime.now();
            final t2 = _searchCacheTimestamps[b] ?? DateTime.now();
            return t1.compareTo(t2);
          });
          // Remove oldest entries
          for (int i = 0; i < keys.length - 20; i++) {
            _searchCache.remove(keys[i]);
            _searchCacheTimestamps.remove(keys[i]);
          }
          print('[AppProvider] 🧹 Cleaned search cache, kept 20 entries');
        }
      }

      _searchResults = results;
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      print('[AppProvider] ❌ Search error: $e');
      // API call itself threw (network down, etc) — still try to serve
      // something instead of an empty state.
      final matched = _predefinedSearchFallback(query);
      _searchResults = matched.isNotEmpty ? matched : _predefinedTrendingSuggestions();
      _isSearchFallback = true;
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Filters the offline predefined players/clubs dataset by [query],
  /// matching on name, team name, or nationality (players) and name
  /// (clubs). Used only as a fallback when the live search API fails or
  /// returns nothing.
  SearchResponse _predefinedSearchFallback(String query) {
    final q = query.trim();
    if (q.isEmpty) return SearchResponse();

    final players = seed.famousPlayers.where((p) {
      return seed.matchesPredefinedQuery(p['name'] as String, q) ||
          seed.matchesPredefinedQuery(p['teamName'] as String, q) ||
          seed.matchesPredefinedQuery(p['nationality'] as String, q);
    }).map((p) {
      return SearchResult(
        id: p['id'] as String,
        name: p['name'] as String,
        displayName: p['name'] as String,
        type: 'player',
        imageUrl: p['imageUrl'] as String,
        teamName: p['teamName'] as String,
        teamId: p['teamId'] as String,
        position: p['position'] as String,
        jerseyNumber: p['jersey'] as String,
        nationality: p['nationality'] as String,
      );
    }).toList();

    final clubs = seed.famousClubs.where((c) {
      return seed.matchesPredefinedQuery(c['name']!, q);
    }).map((c) {
      return SearchResult(
        id: c['id']!,
        name: c['name']!,
        displayName: c['name']!,
        type: 'team',
        imageUrl: 'https://a.espncdn.com/i/teamlogos/soccer/500/${c['id']}.png',
        leagueCode: c['league'],
        leagueName: c['leagueName'],
        abbreviation: c['name']!.length > 3 ? c['name']!.substring(0, 3).toUpperCase() : c['name']!.toUpperCase(),
      );
    }).toList();

    return SearchResponse(players: players, teams: clubs);
  }

  /// Generic, unfiltered "popular right now" suggestions built from the
  /// same offline seed dataset. Used when the live search is unavailable
  /// AND the query doesn't match anything in our small predefined list —
  /// e.g. searching an obscure player name while API-Football is
  /// rate-limited. Better to show the user *something* recognizable than
  /// a flat "no results found".
  SearchResponse _predefinedTrendingSuggestions({int playerLimit = 6, int clubLimit = 4}) {
    final players = seed.famousPlayers.take(playerLimit).map((p) {
      return SearchResult(
        id: p['id'] as String,
        name: p['name'] as String,
        displayName: p['name'] as String,
        type: 'player',
        imageUrl: p['imageUrl'] as String,
        teamName: p['teamName'] as String,
        teamId: p['teamId'] as String,
        position: p['position'] as String,
        jerseyNumber: p['jersey'] as String,
        nationality: p['nationality'] as String,
      );
    }).toList();

    final clubs = seed.famousClubs.take(clubLimit).map((c) {
      return SearchResult(
        id: c['id']!,
        name: c['name']!,
        displayName: c['name']!,
        type: 'team',
        imageUrl: 'https://a.espncdn.com/i/teamlogos/soccer/500/${c['id']}.png',
        leagueCode: c['league'],
        leagueName: c['leagueName'],
        abbreviation: c['name']!.length > 3 ? c['name']!.substring(0, 3).toUpperCase() : c['name']!.toUpperCase(),
      );
    }).toList();

    return SearchResponse(players: players, teams: clubs);
  }

  // lib/providers/app_provider.dart

// Add this method to handle search with better error handling



  Future<void> setCurrentLeague(String leagueCode) async {
    if (_currentLeagueCode == leagueCode) return;
    _currentLeagueCode = leagueCode;
    _sportService.setLeague(leagueCode);
    await _prefs.setLastSelectedLeague(leagueCode);
    notifyListeners();

    await Future.wait([
      fetchAllLiveMatches(forceRefresh: true),
      fetchStandings(forceRefresh: true),
      fetchAllTeamsConcurrent(),
    ]);
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = SearchResponse();
    _isSearching = false;
    _isSearchFallback = false;
    // Don't clear cache on clear
    notifyListeners();
  }

  /// Clear search cache manually (for testing or logout)
  void clearSearchCache() {
    _searchCache.clear();
    _searchCacheTimestamps.clear();
    print('[AppProvider] 🧹 Search cache cleared');
  }
}