import 'package:hive_flutter/hive_flutter.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/player_model.dart';

class CacheService {
  static const String _gamesBox     = 'cached_games';
  static const String _standingsBox = 'cached_standings';
  static const String _newsBox      = 'cached_news';
  static const String _playersBox   = 'cached_players';

  static const Duration cacheDuration = Duration(minutes: 5);

  /// Maximum number of news articles kept in any single cache slot.
  /// Set to 25 — enough for one full page (20) plus a small buffer.
  static const int _maxCachedNewsArticles = 25;

  late Box _gamesBoxRef;
  late Box _standingsBoxRef;
  late Box _newsBoxRef;
  late Box _playersBoxRef;

  bool _isInitialized = false;

  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    _gamesBoxRef     = await Hive.openBox(_gamesBox);
    _standingsBoxRef = await Hive.openBox(_standingsBox);
    _newsBoxRef      = await Hive.openBox(_newsBox);
    _playersBoxRef   = await Hive.openBox(_playersBox);

    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ── Deep-cast helpers (Hive returns _Map<dynamic,dynamic>) ──────────────────
  static Map<String, dynamic> _castMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return (raw as Map).map((k, v) {
      if (v is Map) return MapEntry(k.toString(), _castMap(v));
      if (v is List) return MapEntry(k.toString(), _castList(v));
      return MapEntry(k.toString(), v);
    });
  }

  static List<dynamic> _castList(dynamic raw) {
    if (raw is! List) return [];
    return (raw as List).map((item) {
      if (item is Map) return _castMap(item);
      if (item is List) return _castList(item);
      return item;
    }).toList();
  }

  // ── Games ────────────────────────────────────────────────────────────────────
  Future<void> cacheGames(List<Game> games,
      {String? date, String? leagueCode}) async {
    await _ensureInitialized();
    final key = '${leagueCode ?? 'all'}_${date ?? 'today'}';
    await _gamesBoxRef.put(key, {
      'data': games.map((g) => g.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Game>?> getCachedGames(
      {String? date, String? leagueCode}) async {
    await _ensureInitialized();
    final key = '${leagueCode ?? 'all'}_${date ?? 'today'}';
    final raw = _gamesBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          cacheDuration.inMilliseconds) return null;
      final gamesData = _castList(cached['data']);
      return gamesData.map((g) => Game.fromJson(_castMap(g))).toList();
    } catch (e) {
      print('Cache read error (games): $e');
      return null;
    }
  }

  // ── Standings ─────────────────────────────────────────────────────────────────
  Future<void> cacheStandings(List<Standing> standings,
      {String? leagueCode}) async {
    await _ensureInitialized();
    final key = 'standings_${leagueCode ?? 'all'}';
    await _standingsBoxRef.put(key, {
      'data': standings.map((s) => s.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Standing>?> getCachedStandings({String? leagueCode}) async {
    await _ensureInitialized();
    final key = 'standings_${leagueCode ?? 'all'}';
    final raw = _standingsBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          cacheDuration.inMilliseconds) return null;
      final standingsData = _castList(cached['data']);
      return standingsData.map((s) => Standing.fromJson(_castMap(s))).toList();
    } catch (e) {
      print('Cache read error (standings): $e');
      return null;
    }
  }

  // ── News — capped at [_maxCachedNewsArticles] per category key ───────────────
  //
  // Strategy:
  //   • Always store the LATEST [_maxCachedNewsArticles] articles.
  //   • On write, if more articles are provided the list is trimmed to the
  //     first [_maxCachedNewsArticles] (ESPN returns newest-first).
  //   • Old cached articles beyond that limit are automatically discarded.
  //
  Future<void> cacheNews(List<NewsArticle> news, {String? category}) async {
    await _ensureInitialized();
    final key = category ?? 'all';

    // Cap to newest [_maxCachedNewsArticles] articles
    final trimmed = news.length > _maxCachedNewsArticles
        ? news.sublist(0, _maxCachedNewsArticles)
        : news;

    await _newsBoxRef.put(key, {
      'data': trimmed.map((n) => n.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    print('[CacheService] Cached ${trimmed.length} news articles for key "$key"'
        ' (limit=$_maxCachedNewsArticles)');
  }

  Future<List<NewsArticle>?> getCachedNews({String? category}) async {
    await _ensureInitialized();
    final key = category ?? 'all';
    final raw = _newsBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          cacheDuration.inMilliseconds) return null;
      final newsData = _castList(cached['data']);
      // Only return up to the cap (guards against stale data from before this version)
      final articles  = newsData.map((n) => NewsArticle.fromJson(_castMap(n))).toList();
      return articles.length > _maxCachedNewsArticles
          ? articles.sublist(0, _maxCachedNewsArticles)
          : articles;
    } catch (e) {
      print('Cache read error (news): $e');
      return null;
    }
  }

  /// Clears every news entry in the cache box (all categories).
  Future<void> clearNewsCache() async {
    await _ensureInitialized();
    await _newsBoxRef.clear();
    print('[CacheService] News cache cleared.');
  }

  // ── Full wipe ─────────────────────────────────────────────────────────────────
  Future<void> clearAllCache() async {
    await _ensureInitialized();
    await _gamesBoxRef.clear();
    await _standingsBoxRef.clear();
    await _newsBoxRef.clear();
    await _playersBoxRef.clear();
  }
}