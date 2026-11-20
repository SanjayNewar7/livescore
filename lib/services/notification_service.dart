// lib/services/notification_service.dart
//
// Local, on-device notification center for LiveGoal.
//
// Mirrors ProfileService's storage approach: a Hive box holding plain Maps
// (via NotificationItem.toMap()/fromMap()), so there's no generated Hive
// adapter/typeId to keep in sync and no build_runner step required for this
// feature to work.
//
// Two notification kinds are generated here (see notification_model.dart):
//   • news         — a fetched article mentions a favorite club or favorite
//                     player.
//   • matchResult  — a favorite team's match just went final (within the
//                     last [matchResultWindow], 12h by default).
//
// This service does NOT fetch news or games itself — callers (AppProvider)
// pass in whatever they already fetched, and this service does the
// favorite-matching + de-duplicated persistence. That keeps this service
// testable and keeps API-calling logic in one place (SportService).

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:livescore/models/team_page_data.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/services/api_service.dart';

import 'package:livescore/models/notification_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/game_model.dart';

class NotificationService {
  static const String _boxName = 'notifications_box';
  static const String _teamsBoxName = 'team_notification_subscriptions';
  final FlutterLocalNotificationsPlugin _device = FlutterLocalNotificationsPlugin();
  bool _deviceReady = false;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {
    await _ensureBox();
    await _ensureTeamsBox();
    tzdata.initializeTimeZones();
    await _device.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _deviceReady = true;
  }

  Future<Box> _ensureTeamsBox() async {
    if (Hive.isBoxOpen(_teamsBoxName)) return Hive.box(_teamsBoxName);
    return Hive.openBox(_teamsBoxName);
  }

  bool isTeamFollowed(String teamId) =>
      Hive.isBoxOpen(_teamsBoxName) && Hive.box(_teamsBoxName).containsKey(teamId);

  List<String> get followedTeamIds => Hive.isBoxOpen(_teamsBoxName)
      ? Hive.box(_teamsBoxName).keys.map((key) => key.toString()).toList()
      : const [];

  List<String> get followedTeamNames => Hive.isBoxOpen(_teamsBoxName)
      ? Hive.box(_teamsBoxName).values
          .whereType<Map>()
          .map((value) => value['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty).toList()
      : const [];

  Future<bool> requestDevicePermission() async {
    if (!_deviceReady) await init();
    final android = _device.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      if (granted != true) return false;
      await android.requestExactAlarmsPermission();
      return true;
    }
    final ios = _device.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? true;
  }

  Future<void> followTeam({
    required String teamId,
    required String teamName,
    required String leagueCode,
    required List<TeamUpcomingFixture> fixtures,
  }) async {
    final box = await _ensureTeamsBox();
    await box.put(teamId, {
      'name': teamName,
      'league': leagueCode,
      'followedAt': DateTime.now().toIso8601String(),
      'fixtureIds': <int>[],
      'resultIds': <int>[],
    });
    await scheduleTeamFixtures(teamId, fixtures);
  }

  Future<void> unfollowTeam(String teamId) async {
    final box = await _ensureTeamsBox();
    final data = box.get(teamId);
    if (data is Map && _deviceReady) {
      for (final id in [
        ...(data['fixtureIds'] as List? ?? []),
        ...(data['resultIds'] as List? ?? []),
        ...(data['scheduledIds'] as List? ?? []),
      ]) {
        if (id is int) await _device.cancel(id: id);
      }
    }
    await box.delete(teamId);
  }

  Future<void> scheduleTeamFixtures(
      String teamId, List<TeamUpcomingFixture> fixtures) async {
    if (!_deviceReady) await init();
    final box = await _ensureTeamsBox();
    final raw = box.get(teamId);
    if (raw is! Map) return;
    for (final id in (raw['fixtureIds'] as List? ?? [])) {
      if (id is int) await _device.cancel(id: id);
    }
    final data = Map<String, dynamic>.from(raw);
    final ids = <int>[];
    final teamName = data['name']?.toString() ?? 'Your team';
    if (PreferencesService().preferences.notificationsEnabled &&
        PreferencesService().preferences.liveScoreAlerts) {
      for (final fixture in fixtures) {
        final kickoff = DateTime.tryParse(fixture.date)?.toUtc();
        if (kickoff == null || !kickoff.isAfter(DateTime.now().toUtc())) continue;
        final key = '$teamId:${fixture.date}:${fixture.opponentId}';
        final baseId = _stableId(key) * 2;
        final before = kickoff.subtract(const Duration(minutes: 15));
        if (before.isAfter(DateTime.now().toUtc())) {
          await _schedule(baseId, '$teamName play in 15 minutes',
              '${fixture.isHome ? 'Home' : 'Away'} vs ${fixture.opponentName} • ${fixture.competition}', before);
          ids.add(baseId);
        }
        await _schedule(baseId + 1, 'Kickoff: $teamName vs ${fixture.opponentName}',
            '${fixture.competition} is underway', kickoff);
        ids.add(baseId + 1);
      }
    }
    data['fixtureIds'] = ids;
    data['fixtures'] = fixtures.map((f) => {
      'opponentId': f.opponentId,
      'opponentName': f.opponentName,
      'opponentLogo': f.opponentLogo,
      'opponentAbbr': f.opponentAbbr,
      'competition': f.competition,
      'leagueFlag': f.leagueFlag,
      'date': f.date,
      'isHome': f.isHome,
    }).toList();
    await box.put(teamId, data);
  }

  Future<void> syncDeviceSettings() async {
    final box = await _ensureTeamsBox();
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      if (!PreferencesService().preferences.notificationsEnabled ||
          !PreferencesService().preferences.liveScoreAlerts) {
        for (final id in (raw['resultIds'] as List? ?? [])) {
          if (id is int) await _device.cancel(id: id);
        }
        final updated = Map<String, dynamic>.from(raw);
        updated['resultIds'] = <int>[];
        await box.put(key, updated);
      }
      final fixtures = <TeamUpcomingFixture>[];
      for (final value in (raw['fixtures'] as List? ?? [])) {
        if (value is! Map) continue;
        fixtures.add(TeamUpcomingFixture(
          opponentId: value['opponentId']?.toString() ?? '',
          opponentName: value['opponentName']?.toString() ?? '',
          opponentLogo: value['opponentLogo']?.toString() ?? '',
          opponentAbbr: value['opponentAbbr']?.toString() ?? '',
          competition: value['competition']?.toString() ?? '',
          leagueFlag: value['leagueFlag']?.toString() ?? '',
          date: value['date']?.toString() ?? '',
          isHome: value['isHome'] == true,
        ));
      }
      await scheduleTeamFixtures(key.toString(), fixtures);
    }
  }

  Future<void> pollTeamActivity() async {
    final prefs = PreferencesService().preferences;
    if (!prefs.notificationsEnabled) return;
    final box = await _ensureTeamsBox();
    if (box.isEmpty) return;
    final subscriptions = <String, Map<String, dynamic>>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) subscriptions[key.toString()] = Map<String, dynamic>.from(raw);
    }
    if (subscriptions.isEmpty) return;
    final api = ApiService();
    if (prefs.newsAlerts) {
      final articles = await api.getNewsBatch(limit: 25);
      await generateNewsNotifications(
        articles: articles,
        favoriteTeamNames: subscriptions.values
            .map((s) => s['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty).toList(),
      );
    }
    if (prefs.liveScoreAlerts) {
      final leagues = subscriptions.values
          .map((s) => s['league']?.toString() ?? '')
          .where((s) => s.isNotEmpty).toSet();
      final now = DateTime.now();
      final games = <Game>[];
      for (final league in leagues) {
        games.addAll(await api.getGamesByDate(league, now));
        games.addAll(await api.getGamesByDate(
            league, now.subtract(const Duration(days: 1))));
      }
      await generateMatchResultNotifications(
        games: games,
        favoriteTeamIds: subscriptions.keys.toList(),
      );
    }
  }

  int _stableId(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return hash;
  }

  Future<void> _schedule(int id, String title, String body, DateTime when) async {
    final android = _device.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    await _device.zonedSchedule(
      id: id, title: title, body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: const NotificationDetails(android: AndroidNotificationDetails(
        'team_matches', 'Team match alerts',
        channelDescription: 'Upcoming matches and kickoff alerts',
        importance: Importance.high, priority: Priority.high,
      ), iOS: DarwinNotificationDetails()),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _showDevice(String id, String title, String body,
      {required bool news}) async {
    if (!_deviceReady) await init();
    await _device.show(id: _stableId(id), title: title, body: body,
        notificationDetails: NotificationDetails(android: AndroidNotificationDetails(
          news ? 'team_news' : 'team_results',
          news ? 'Team news' : 'Team results',
          channelDescription: news ? 'News about followed teams' : 'Final scores for followed teams',
          importance: Importance.high, priority: Priority.high,
        ), iOS: const DarwinNotificationDetails()));
  }

  /// Same reasoning as ProfileService._ensureBox(): go through
  /// Hive.box/Hive.openBox directly on every call instead of caching a
  /// `late Box` field, so a missed/failed init() during app startup can't
  /// silently break every read/write here.
  Future<Box> _ensureBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Box? get _boxIfOpen => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;

  // ─── READ ──────────────────────────────────────────────────────────────

  /// All notifications, newest first.
  List<NotificationItem> getAll() {
    final box = _boxIfOpen;
    if (box == null) return [];

    final items = <NotificationItem>[];
    for (final value in box.values) {
      if (value is Map) {
        try {
          items.add(NotificationItem.fromMap(value));
        } catch (_) {
          // Skip malformed entries rather than crashing the whole list.
        }
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<NotificationItem> get unread => getAll().where((n) => !n.isRead).toList();

  int get unreadCount => getAll().where((n) => !n.isRead).length;

  // ─── WRITE ─────────────────────────────────────────────────────────────

  /// Adds [item] only if a notification with the same id doesn't already
  /// exist, so regenerating notifications on every refresh never resets an
  /// already-read notification back to unread. Returns true if it was
  /// newly added.
  Future<bool> _addIfNew(NotificationItem item) async {
    final box = await _ensureBox();
    if (box.containsKey(item.id)) return false;
    await box.put(item.id, item.toMap());
    return true;
  }

  Future<void> markAsRead(String id) async {
    final box = await _ensureBox();
    final raw = box.get(id);
    if (raw is Map) {
      final updated = NotificationItem.fromMap(raw).copyWith(isRead: true);
      await box.put(id, updated.toMap());
    }
  }

  Future<void> markNewsArticleRead(String articleId) async {
    if (articleId.isEmpty) return;
    final box = await _ensureBox();
    await box.put('read_news_$articleId', true);
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final item = NotificationItem.fromMap(raw);
      if (item.isNews && item.article?.id == articleId && !item.isRead) {
        await box.put(key, item.copyWith(isRead: true).toMap());
      }
    }
  }

  Future<void> markAllAsRead() async {
    final box = await _ensureBox();
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is Map) {
        final parsed = NotificationItem.fromMap(raw);
        if (!parsed.isRead) {
          await box.put(key, parsed.copyWith(isRead: true).toMap());
        }
      }
    }
  }

  Future<void> delete(String id) async {
    final box = await _ensureBox();
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _ensureBox();
    await box.clear();
  }

  // ─── GENERATION: favorite club/player news ────────────────────────────

  /// Scans [articles] for mentions of any name in [favoriteTeamNames] or
  /// [favoritePlayers] (each a {'id','name','image','team'} map — only
  /// 'name' is used here) in the headline, description, or categories.
  /// Only the most recent [maxArticlesToScan] articles are scanned, since
  /// the news list can be large and older matches are of little value as
  /// notifications.
  Future<int> generateNewsNotifications({
    required List<NewsArticle> articles,
    List<String> favoriteTeamNames = const [],
    List<Map<String, String>> favoritePlayers = const [],
    int maxArticlesToScan = 60,
  }) async {
    if (favoriteTeamNames.isEmpty && favoritePlayers.isEmpty) return 0;
    if (articles.isEmpty) return 0;

    final teamNames = favoriteTeamNames
        .where((n) => n.trim().isNotEmpty)
        .toList();
    final playerNames = favoritePlayers
        .map((p) => p['name'] ?? '')
        .where((n) => n.trim().isNotEmpty)
        .toList();

    int added = 0;
    for (final article in articles.take(maxArticlesToScan)) {
      final searchText = [
        article.headline,
        article.description,
        ...article.categories,
      ].join(' ').toLowerCase();

      String? matchedName;
      String? matchedType;

      for (final name in teamNames) {
        if (searchText.contains(name.toLowerCase())) {
          matchedName = name;
          matchedType = 'team';
          break;
        }
      }

      if (matchedName == null) {
        for (final name in playerNames) {
          if (searchText.contains(name.toLowerCase())) {
            matchedName = name;
            matchedType = 'player';
            break;
          }
        }
      }

      if (matchedName == null || article.id.isEmpty) continue;

      DateTime createdAt;
      try {
        createdAt = DateTime.parse(article.publishedAt);
      } catch (_) {
        createdAt = DateTime.now();
      }

      // The article's own headline is already unique per story, which is
      // exactly what keeps this from reading like a repeated template —
      // it becomes the bold title, same as a normal news notification.
      // The muted subtitle just explains *why* it surfaced, picked from a
      // small rotating pool (seeded off the article id, so it's stable —
      // the same article always shows the same subtitle) rather than one
      // fixed sentence every single time.
      final seed = _seedFrom('${article.id}_$matchedType');
      final subtitle = matchedType == 'player'
          ? _pick(seed, [
        '$matchedName in the headlines',
        'Update on $matchedName',
        'Because you follow $matchedName',
        'Spotted in your feed',
      ])
          : _pick(seed, [
        '$matchedName news',
        'Latest on $matchedName',
        'Because you follow $matchedName',
        'Trending in your favorites',
      ]);

      final item = NotificationItem(
        id: 'news_${article.id}',
        type: NotificationType.news,
        title: article.headline.isNotEmpty ? article.headline : '$matchedName in the news',
        subtitle: subtitle,
        imageUrl: article.imageUrl.isNotEmpty ? article.imageUrl : null,
        createdAt: createdAt,
        isRead: (await _ensureBox()).get('read_news_${article.id}') == true,
        matchedEntityName: matchedName,
        matchedEntityType: matchedType,
        article: article,
      );

      if (await _addIfNew(item)) {
        added++;
        final followed = await _ensureTeamsBox();
        final isSubscribed = followed.values.any((value) {
          if (value is! Map ||
              value['name']?.toString().toLowerCase() != matchedName?.toLowerCase()) {
            return false;
          }
          final followedAt = DateTime.tryParse(value['followedAt']?.toString() ?? '');
          return followedAt == null || !createdAt.isBefore(followedAt);
        });
        final articleAge = DateTime.now().difference(createdAt);
        if (!item.isRead && isSubscribed && PreferencesService().preferences.notificationsEnabled &&
            PreferencesService().preferences.newsAlerts &&
            !articleAge.isNegative && articleAge < const Duration(hours: 2)) {
          await _showDevice(item.id, item.title, item.subtitle, news: true);
        }
      }
    }
    return added;
  }

  // ─── GENERATION: favorite team match results ──────────────────────────

  /// Creates "full-time" notifications for finished matches involving a
  /// favorite team, as long as the match is estimated to have finished
  /// within [window] (default 12h) — so reopening the app days later
  /// doesn't flood the list with stale results.
  Future<int> generateMatchResultNotifications({
    required List<Game> games,
    List<String> favoriteTeamIds = const [],
    Duration window = const Duration(hours: 12),
    // Typical soccer match, including stoppage/halftime, wraps up a little
    // over 2 hours after kickoff — used to estimate the final-whistle time
    // since Game doesn't carry an explicit "ended at" timestamp.
    Duration estimatedMatchLength = const Duration(hours: 2),
  }) async {
    if (favoriteTeamIds.isEmpty || games.isEmpty) return 0;

    final now = DateTime.now();
    int added = 0;

    for (final game in games) {
      if (!game.isFinal) continue;
      if (game.id.isEmpty) continue;

      final favoriteIsHome = favoriteTeamIds.contains(game.homeTeam.id);
      final favoriteIsAway = favoriteTeamIds.contains(game.awayTeam.id);
      if (!favoriteIsHome && !favoriteIsAway) continue;

      DateTime? kickoff;
      try {
        kickoff = DateTime.parse(game.date).toLocal();
      } catch (_) {
        kickoff = null;
      }
      final estimatedEnd = kickoff?.add(estimatedMatchLength) ?? now;

      // Skip matches whose estimated final whistle is outside the window
      // (either too long ago, or — as a safety guard against bad data —
      // apparently still in the future).
      if (kickoff != null && kickoff.isAfter(now)) continue;
      if (now.difference(estimatedEnd) > window) continue;
      final finishedAt = now;

      final favoriteTeamName = favoriteIsHome ? game.homeTeam.name : game.awayTeam.name;
      final opponentName = favoriteIsHome ? game.awayTeam.name : game.homeTeam.name;
      final favoriteLogo = favoriteIsHome ? game.homeTeam.logo : game.awayTeam.logo;

      final favoriteScore = int.tryParse(favoriteIsHome ? game.homeScore : game.awayScore) ?? 0;
      final opponentScore = int.tryParse(favoriteIsHome ? game.awayScore : game.homeScore) ?? 0;

      final title = _buildMatchTitle(
        game: game,
        favoriteTeamName: favoriteTeamName,
        opponentName: opponentName,
        favoriteScore: favoriteScore,
        opponentScore: opponentScore,
        favoriteIsHome: favoriteIsHome,
      );
      final subtitle = _buildMatchSubtitle(game);

      final item = NotificationItem(
        id: 'match_${game.id}',
        type: NotificationType.matchResult,
        title: title,
        subtitle: subtitle,
        imageUrl: favoriteLogo.isNotEmpty ? favoriteLogo : null,
        createdAt: finishedAt,
        matchedEntityName: favoriteTeamName,
        matchedEntityType: 'team',
        game: game,
      );

      if (await _addIfNew(item)) {
        added++;
        if ((favoriteIsHome && isTeamFollowed(game.homeTeam.id) ||
                favoriteIsAway && isTeamFollowed(game.awayTeam.id)) &&
            PreferencesService().preferences.notificationsEnabled &&
            PreferencesService().preferences.liveScoreAlerts &&
            kickoff != null && now.difference(kickoff) < const Duration(hours: 4)) {
          // ESPN reports final status without a reliable actual whistle time.
          // Schedule from the first final observation rather than assuming a
          // fixed match length.
          final alertId = _stableId('${item.id}_final');
          await _schedule(alertId, title, subtitle,
              DateTime.now().toUtc().add(const Duration(minutes: 15)));
          final teams = await _ensureTeamsBox();
          final teamId = favoriteIsHome ? game.homeTeam.id : game.awayTeam.id;
          final raw = teams.get(teamId);
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            data['resultIds'] = <int>[
              ...(data['resultIds'] as List? ?? []).whereType<int>(),
              alertId,
            ];
            await teams.put(teamId, data);
          }
        }
      }
    }
    return added;
  }

  // ─── Varied headline helpers ───────────────────────────────────────────
  //
  // A single fixed template ("Full-Time: A x - y B" every time) reads as
  // obviously machine-generated once you've seen it a few times. Instead,
  // each result is described from a small pool of context-appropriate
  // phrasings (big win vs narrow win vs clean sheet vs high-scoring vs
  // draw vs loss, plus a scorer shout-out when someone bagged 2+), and the
  // pick within that pool is seeded off the game id — so it's stable
  // (reopening the app shows the same wording) without ever looking like
  // one sentence with the names swapped in.

  int _seedFrom(String input) => input.hashCode & 0x7fffffff;

  String _pick(int seed, List<String> options) => options[seed % options.length];

  /// Counts non-own-goals scored by the side indicated by [isHomeTeam],
  /// keyed by scorer name — used to spot a brace/hat-trick worth calling
  /// out by name.
  Map<String, int> _goalCounts(Game game, bool isHomeTeam) {
    final counts = <String, int>{};
    for (final g in game.goalScorers) {
      if (g.isHomeTeam == isHomeTeam && !g.isOwnGoal) {
        counts[g.playerName] = (counts[g.playerName] ?? 0) + 1;
      }
    }
    return counts;
  }

  String _buildMatchTitle({
    required Game game,
    required String favoriteTeamName,
    required String opponentName,
    required int favoriteScore,
    required int opponentScore,
    required bool favoriteIsHome,
  }) {
    final score = '$favoriteScore-$opponentScore';
    final margin = favoriteScore - opponentScore;
    final totalGoals = favoriteScore + opponentScore;
    final seed = _seedFrom(game.id);

    List<String> pool;

    if (favoriteScore > opponentScore) {
      if (margin >= 3) {
        pool = [
          '$favoriteTeamName run riot against $opponentName, $score',
          'Statement win! $favoriteTeamName thrash $opponentName $score',
          '$favoriteTeamName put on a show, beating $opponentName $score',
          'No mercy — $favoriteTeamName demolish $opponentName',
        ];
      } else if (opponentScore == 0) {
        pool = [
          '$favoriteTeamName keep a clean sheet, beat $opponentName $score',
          'Clean sheet and three points for $favoriteTeamName',
          '$favoriteTeamName shut out $opponentName to win $score',
        ];
      } else if (margin == 1) {
        pool = [
          '$favoriteTeamName edge past $opponentName $score',
          'Nervy finish, but $favoriteTeamName hold on against $opponentName',
          '$favoriteTeamName sneak past $opponentName $score',
        ];
      } else if (totalGoals >= 5) {
        pool = [
          'Goals galore! $favoriteTeamName beat $opponentName $score',
          'End-to-end thriller — $favoriteTeamName come out on top $score',
        ];
      } else {
        pool = [
          '$favoriteTeamName beat $opponentName $score',
          'Three points for $favoriteTeamName after a $score win over $opponentName',
          '$favoriteTeamName get the job done against $opponentName',
        ];
      }

      // Data-driven bonus option: if a favorite-team player scored 2+,
      // let that shout-out compete in the same pool rather than always
      // winning — so it shows up sometimes, not every single time.
      final counts = _goalCounts(game, favoriteIsHome);
      String? standoutScorer;
      int standoutCount = 0;
      counts.forEach((name, count) {
        if (count >= 2 && count > standoutCount) {
          standoutScorer = name;
          standoutCount = count;
        }
      });
      if (standoutScorer != null) {
        final tag = standoutCount >= 3 ? 'hat-trick' : 'brace';
        pool.add('$standoutScorer nets a $tag as $favoriteTeamName beat $opponentName $score');
      }
    } else if (favoriteScore < opponentScore) {
      final absMargin = -margin;
      if (absMargin >= 3) {
        pool = [
          'Tough night — $favoriteTeamName thrashed by $opponentName $score',
          '$favoriteTeamName well beaten by $opponentName $score',
          'A day to forget for $favoriteTeamName, $score',
        ];
      } else {
        pool = [
          '$favoriteTeamName fall to $opponentName $score',
          '$favoriteTeamName narrowly beaten by $opponentName $score',
          'Heartbreak for $favoriteTeamName, lose $score to $opponentName',
        ];
      }
    } else {
      if (favoriteScore == 0) {
        pool = [
          'Stalemate — $favoriteTeamName held goalless by $opponentName',
          '$favoriteTeamName and $opponentName play out a goalless draw',
        ];
      } else {
        pool = [
          '$favoriteTeamName share the spoils with $opponentName, $score',
          '$favoriteTeamName and $opponentName play out a $score draw',
          'Points shared as $favoriteTeamName draw $score with $opponentName',
        ];
      }
    }

    return _pick(seed, pool);
  }

  String _buildMatchSubtitle(Game game) {
    final seed = _seedFrom('${game.id}_sub');
    final connector = _pick(seed, ['Full-time', 'Match ended', 'Final whistle']);
    final leagueSuffix = game.leagueName.isNotEmpty ? ' • ${game.leagueName}' : '';
    return '$connector • ${game.homeTeam.name} ${game.homeScore}-${game.awayScore} ${game.awayTeam.name}$leagueSuffix';
  }
}
