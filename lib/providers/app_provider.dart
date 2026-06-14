import 'package:flutter/material.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/utils/constants.dart';

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

    // Find the oldest article (by published date)
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
  // Phase 1: Load first 25 articles quickly (shows immediately)
  // Phase 2: Load remaining articles in background (no UI indicator)

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
        },
      );
    } catch (e) {
      print('[News] Error: $e');
      _isFetchingNews = false;
      notifyListeners();
    }
  }

  // Kept for compatibility - no pagination
  Future<void> loadMoreNews() async {
    print('[News] No pagination support - all articles loaded at once');
    _hasMoreNews = false;
    notifyListeners();
  }

  Future<void> refreshNews() async {
    await fetchNewsConcurrent(forceRefresh: true, page: 1);
  }

  /// Silent background refresh — updates articles at the top
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

  // Add or verify this method exists in AppProvider class:

  Future<List<Standing>> fetchStandingsDirect(String leagueCode) async {
    try {
      _sportService.setLeague(leagueCode);
      final standings = await _sportService.getStandings(forceRefresh: true);
      return standings;
    } catch (e) {
      print('Error fetching standings: $e');
      return [];
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
  }

  bool isTeamFavorite(String teamId) => _prefs.isTeamFavorite(teamId);

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
}