import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/league_leader_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/models/team_page_data.dart';
import 'package:livescore/screens/game_detail_screen.dart'
    show MatchLineup, LineupPlayer, H2HResult;

// ─────────────────────────────────────────────────────────────────────────────
// Private helper class (file-scoped, not exported)
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduleResult {
  final List<TeamRecentMatch> recentMatches;
  final List<TeamUpcomingFixture> upcoming;
  final String? headCoach;
  final List<String> recentMatchEventIds;

  const _ScheduleResult({
    required this.recentMatches,
    required this.upcoming,
    this.headCoach,
    this.recentMatchEventIds = const [],
  });

  static _ScheduleResult empty() =>
      const _ScheduleResult(recentMatches: [], upcoming: []);
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  final Map<String, int> _leaguePriorityCache = {};

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json, image/*',
    'Referer': 'https://www.espn.com/',
    'Origin':  'https://www.espn.com',
    'User-Agent':
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  };

  String _normalizeStatus(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.contains('progress') || s == 'in progress' || s == 'halftime' ||
        s.contains('live') || s.contains('half time') || s.contains('extra time') ||
        s.contains('penalty') || s.contains('overtime')) {
      return 'STATUS_LIVE';
    }
    if (s.contains('final') || s == 'ft' || s == 'finished' || s == 'ended' ||
        s.contains('full time') || s == 'after extra time' || s == 'after penalties' ||
        s == 'post' || s == 'complete' || s == 'completed' || s == 'result') {
      return 'STATUS_FINAL';
    }
    return 'STATUS_SCHEDULED';
  }

  String _normalizeEventStatus(Map<String, dynamic> event) {
    final competitions = event['competitions'] as List?;
    Map<String, dynamic>? compStatus;
    if (competitions != null && competitions.isNotEmpty) {
      final first = competitions.first;
      if (first is Map<String, dynamic>) {
        compStatus = first['status'] as Map<String, dynamic>?;
      }
    }
    final eventStatus = event['status'] as Map<String, dynamic>?;

    final blocks = <Map<String, dynamic>>[];
    if (compStatus != null) blocks.add(compStatus);
    if (eventStatus != null) blocks.add(eventStatus);

    for (final statusBlock in blocks) {
      final typeBlock = statusBlock['type'] as Map<String, dynamic>?;
      if (typeBlock != null) {
        final state = typeBlock['state']?.toString().toLowerCase() ?? '';
        if (state == 'post') return 'STATUS_FINAL';
        if (state == 'in') return 'STATUS_LIVE';
        if (state == 'pre') return 'STATUS_SCHEDULED';

        final completed = typeBlock['completed'];
        if (completed == true) return 'STATUS_FINAL';

        final description = typeBlock['description']?.toString() ?? '';
        if (description.isNotEmpty) {
          final norm = _normalizeStatus(description);
          if (norm != 'STATUS_SCHEDULED') return norm;
        }
        final typeName = typeBlock['name']?.toString() ?? '';
        if (typeName.isNotEmpty) {
          final norm = _normalizeStatus(typeName);
          if (norm != 'STATUS_SCHEDULED') return norm;
        }
      }

      final directState = statusBlock['state']?.toString().toLowerCase() ?? '';
      if (directState == 'post') return 'STATUS_FINAL';
      if (directState == 'in') return 'STATUS_LIVE';
      if (directState == 'pre') return 'STATUS_SCHEDULED';

      final directCompleted = statusBlock['completed'];
      if (directCompleted == true) return 'STATUS_FINAL';

      final directDesc = statusBlock['description']?.toString() ?? '';
      if (directDesc.isNotEmpty) return _normalizeStatus(directDesc);

      final displayClock = statusBlock['displayClock']?.toString() ?? '';
      final periodRaw = statusBlock['period'];
      if (displayClock == '0:00' && periodRaw != null) {
        final periodVal = int.tryParse(periodRaw.toString()) ?? 0;
        if (periodVal >= 2) return 'STATUS_FINAL';
      }
    }

    try {
      final eventDate = DateTime.parse(event['date']?.toString() ?? '');
      final cutoff = eventDate.add(const Duration(hours: 3));
      if (DateTime.now().isAfter(cutoff)) return 'STATUS_FINAL';
    } catch (_) {}

    return 'STATUS_SCHEDULED';
  }

  Future<List<Map<String, String>>> getAllLeagues() async {
    return AppConstants.allLeagues.map((league) {
      return {
        'id': league['code']!,
        'name': league['name']!,
        'slug': league['code']!,
        'abbreviation': league['name']!.substring(0, 3).toUpperCase(),
        'flag': league['flag']!,
      };
    }).toList();
  }

  Future<List<Game>> getScoreboard({
    required String leagueCode,
    String? date,
  }) async {
    final base = '${AppConstants.baseUrl}/$leagueCode/scoreboard';
    final url  = date != null ? '$base?dates=$date' : base;
    try {
      final response = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return _parseGamesFromScoreboard(json.decode(response.body), leagueCode);
      }
    } catch (e) {
      print('Scoreboard error $leagueCode: $e');
    }
    return [];
  }

  String _extractMatchNote(Map<String, dynamic> competition, String leagueName, Map<String, dynamic> event) {
    String matchNote = '';

    try {
      final notes = competition['notes'] as List? ?? [];
      if (notes.isNotEmpty) {
        for (final note in notes) {
          final headline = note['headline']?.toString().trim() ?? '';
          final type = note['type']?.toString().trim() ?? '';

          final lowerHeadline = headline.toLowerCase();
          if (lowerHeadline.contains('final') ||
              lowerHeadline.contains('semi') ||
              lowerHeadline.contains('quarter') ||
              lowerHeadline.contains('round of') ||
              lowerHeadline.contains('group stage') ||
              lowerHeadline.contains('matchday') ||
              lowerHeadline.contains('knockout') ||
              lowerHeadline.contains('playoff')) {
            matchNote = headline;
            break;
          }

          final lowerType = type.toLowerCase();
          if (lowerType.contains('final') ||
              lowerType.contains('semi') ||
              lowerType.contains('quarter')) {
            matchNote = type;
            break;
          }

          if (matchNote.isEmpty && headline.isNotEmpty && headline != '0') {
            matchNote = headline;
          }
        }
      }

      if (matchNote.isEmpty) {
        final roundName = competition['round']?['name']?.toString();
        final roundNumber = competition['round']?['number']?.toString();

        if (roundName != null && roundName.isNotEmpty) {
          matchNote = roundName;
        } else if (roundNumber != null && roundNumber.isNotEmpty) {
          matchNote = 'Matchday $roundNumber';
        }
      }

      if (matchNote.isEmpty) {
        final seriesName = competition['series']?['displayName']?.toString();
        if (seriesName != null && seriesName.isNotEmpty) {
          final lowerSeries = seriesName.toLowerCase();
          if (lowerSeries.contains('final') ||
              lowerSeries.contains('semi') ||
              lowerSeries.contains('quarter') ||
              lowerSeries.contains('knockout')) {
            matchNote = seriesName;
          }
        }
      }

      if (matchNote.isEmpty) {
        final seasonName = competition['season']?['displayName']?.toString();
        if (seasonName != null && seasonName.isNotEmpty) {
          final lowerSeason = seasonName.toLowerCase();
          if (lowerSeason.contains('final') ||
              lowerSeason.contains('knockout') ||
              lowerSeason.contains('playoff')) {
            matchNote = seasonName;
          }
        }
      }

      try {
        final eventDate = DateTime.parse(event['date']?.toString() ?? '');
        final isChampionsLeague = leagueName.toLowerCase().contains('champions league');
        final isEuropa = leagueName.toLowerCase().contains('europa league');

        if (isChampionsLeague && eventDate.month == 5 && eventDate.day >= 28 && eventDate.day <= 31) {
          matchNote = 'Final';
        }
        else if (isEuropa && eventDate.month == 5 && eventDate.day >= 20 && eventDate.day <= 27) {
          matchNote = 'Final';
        }
        else if (eventDate.month == 5 && eventDate.day >= 15 && eventDate.day <= 30) {
          final leagueLower = leagueName.toLowerCase();
          if (leagueLower.contains('cup') || leagueLower.contains('fa cup') ||
              leagueLower.contains('copa del rey') || leagueLower.contains('dfb-pokal')) {
            matchNote = 'Final';
          }
        }
      } catch (_) {}

    } catch (e) {
      print('Error extracting match note: $e');
    }

    return matchNote;
  }

  List<Game> _parseGamesFromScoreboard(Map<String, dynamic> data, String leagueCode) {
    final List<Game> games = [];
    final events = data['events'] as List? ?? [];

    final league = AppConstants.allLeagues.firstWhere(
          (l) => l['code'] == leagueCode,
      orElse: () => {'name': leagueCode, 'flag': '⚽'},
    );
    final leagueName = league['name'] ?? leagueCode;
    final leagueFlag = league['flag'] ?? '⚽';

    for (final event in events) {
      try {
        final competition = (event['competitions'] as List?)?.first;
        if (competition == null) continue;

        final competitors = competition['competitors'] as List? ?? [];
        if (competitors.length < 2) continue;

        Map<String, dynamic> awayData = {};
        Map<String, dynamic> homeData = {};
        for (final c in competitors) {
          if (c['homeAway'] == 'away') awayData = c;
          if (c['homeAway'] == 'home') homeData = c;
        }
        if (awayData.isEmpty || homeData.isEmpty) continue;

        final awayTeam = _buildTeamInfo(awayData);
        final homeTeam = _buildTeamInfo(homeData);

        final venueData = competition['venue'];
        final venue = Venue(
          id: venueData?['id']?.toString() ?? '',
          fullName: venueData?['fullName'] ?? '',
          city: venueData?['address']?['city'] ?? '',
          state: venueData?['address']?['state'] ?? '',
          capacity: venueData?['capacity'] ?? 0,
        );

        final rawStatus = event['status']?['type']?['description']?.toString() ?? 'Scheduled';
        final status = _normalizeStatus(rawStatus);

        final matchNote = _extractMatchNote(competition, leagueName, event);

        final rawClock = event['status']?['displayClock']?.toString() ?? '';
        final clock = _parseClock(rawClock);
        final period = competition['status']?['period']?.toString() ?? '';

        final awayLineScores = _parseLineScores(awayData['linescores']);
        final homeLineScores = _parseLineScores(homeData['linescores']);

        final List<GoalScorer> goalScorers = _parseGoalScorers(competition, awayTeam, homeTeam);

        final awayFull = awayData['team']?['displayName']?.toString() ?? awayTeam.name;
        final homeFull = homeData['team']?['displayName']?.toString() ?? homeTeam.name;
        final awayShort = awayData['team']?['abbreviation']?.toString() ?? awayTeam.abbreviation;
        final homeShort = homeData['team']?['abbreviation']?.toString() ?? homeTeam.abbreviation;

        games.add(Game(
          id: event['id']?.toString() ?? '',
          status: status,
          shortDetail: matchNote,
          awayTeam: awayTeam,
          homeTeam: homeTeam,
          awayScore: awayData['score']?.toString() ?? '0',
          homeScore: homeData['score']?.toString() ?? '0',
          awayLineScores: awayLineScores,
          homeLineScores: homeLineScores,
          venue: venue,
          date: event['date']?.toString() ?? '',
          clock: clock,
          period: period,
          leagueName: leagueName,
          leagueFlag: leagueFlag,
          goalScorers: goalScorers,
          awayTeamFullName: awayFull,
          homeTeamFullName: homeFull,
          awayTeamShortName: awayShort,
          homeTeamShortName: homeShort,
        ));
      } catch (e) {
        print('Parse error for event in $leagueCode: $e');
      }
    }
    return games;
  }

  TeamInfo _buildTeamInfo(Map<String, dynamic> competitorData) {
    final team = competitorData['team'] as Map<String, dynamic>? ?? {};
    final record = competitorData['records'] != null &&
        (competitorData['records'] as List).isNotEmpty
        ? (competitorData['records'] as List).first['summary']?.toString() ?? '0-0-0'
        : competitorData['record']?.toString() ?? '0-0-0';

    return TeamInfo(
      id: team['id']?.toString() ?? '',
      name: team['name']?.toString() ?? '',
      displayName: team['displayName']?.toString() ?? '',
      abbreviation: team['abbreviation']?.toString() ?? '',
      logo: team['logo']?.toString() ?? '',
      color: '#${team['color']?.toString() ?? '1A62C8'}',
      alternateColor: '#${team['alternateColor']?.toString() ?? 'FFFFFF'}',
      record: record,
    );
  }

  /// Resolves a team logo URL from standings entry data.
  /// ESPN's /standings endpoint usually omits the `logo` field on team objects,
  /// so we fall back to the standard ESPN CDN pattern using the team ID.
  String _resolveTeamLogo(Map<String, dynamic> teamData) {
    // 1. Direct logo string (some endpoints do provide it)
    final direct = teamData['logo']?.toString() ?? '';
    if (direct.isNotEmpty && direct.startsWith('http')) return direct;

    // 2. logos[] array (core API format)
    final logos = teamData['logos'] as List?;
    if (logos != null && logos.isNotEmpty) {
      final href = logos.first['href']?.toString() ?? '';
      if (href.isNotEmpty && href.startsWith('http')) return href;
    }

    // 3. Construct from team ID — always works for club teams
    final id = teamData['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      return 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
    }

    return '';
  }

  List<int> _parseLineScores(dynamic raw) {
    if (raw == null) return [];
    final list = raw as List;
    final List<int> scores = [];
    for (final item in list) {
      final value = item['value'] ?? 0;
      scores.add(value.toInt());
    }
    return scores;
  }

  String _parseClock(String raw) {
    if (raw.isEmpty) return '';
    final colonIdx = raw.lastIndexOf(':');
    if (colonIdx > 0) return raw.substring(0, colonIdx);
    return raw;
  }

  List<GoalScorer> _parseGoalScorers(
      Map<String, dynamic> competition,
      TeamInfo awayTeam,
      TeamInfo homeTeam,
      ) {
    final details = competition['details'] as List? ?? [];
    final List<GoalScorer> scorers = [];

    for (final detail in details) {
      final typeStr = (detail['type']?['text'] ?? '').toString().toLowerCase();
      if (!typeStr.contains('goal') && !typeStr.contains('score')) continue;

      final athleteTeamId = detail['team']?['id']?.toString() ?? '';
      final isHome = athleteTeamId == homeTeam.id;

      final athletes = detail['athletesInvolved'] as List? ?? [];
      final playerName = athletes.isNotEmpty
          ? (athletes.first['displayName'] ?? athletes.first['fullName'] ?? 'Unknown').toString()
          : 'Unknown';
      final playerId = athletes.isNotEmpty
          ? (athletes.first['id']?.toString() ?? '')
          : '';

      final clockStr = detail['clock']?['displayValue']?.toString() ?? '';
      int minute = 0;
      if (clockStr.isNotEmpty) {
        final m = RegExp(r'(\d+)').firstMatch(clockStr);
        if (m != null) minute = int.tryParse(m.group(1)!) ?? 0;
      }

      int? addedTime;
      if (clockStr.contains('+')) {
        final parts = clockStr.split('+');
        if (parts.length > 1) {
          addedTime = int.tryParse(parts[1].replaceAll(RegExp(r'[^\d]'), ''));
        }
      }

      String? assist;
      if (athletes.length > 1) {
        assist = (athletes[1]['displayName'] ?? athletes[1]['fullName'] ?? '').toString();
        if (assist.isEmpty) assist = null;
      }

      scorers.add(GoalScorer(
        playerId: playerId,
        playerName: playerName,
        minute: minute,
        isHomeTeam: isHome,
        addedTime: addedTime,
        assistPlayerName: assist,
        isPenalty: typeStr.contains('penalty'),
        isOwnGoal: typeStr.contains('own'),
      ));
    }

    scorers.sort((a, b) => a.minute.compareTo(b.minute));
    return scorers;
  }

  Future<List<Game>> _fetchLeaguesInParallel(
      List<Map<String, String>> leagues,
      String dateStr,
      ) async {
    print('[API] Fetching $dateStr for ${leagues.length} leagues');

    const batchSize = 12;
    final allGames = <Game>[];

    for (int i = 0; i < leagues.length; i += batchSize) {
      final batch = leagues.sublist(i, (i + batchSize).clamp(0, leagues.length));
      final futures = batch.map((league) async {
        final leagueCode = league['code']!;
        final url = '${AppConstants.baseUrl}/$leagueCode/scoreboard?dates=$dateStr';
        try {
          final res = await _client
              .get(Uri.parse(url), headers: _headers)
              .timeout(const Duration(seconds: 14),
              onTimeout: () => http.Response('{}', 408));

          if (res.statusCode == 200) {
            try {
              final games = _parseGamesFromScoreboard(
                  json.decode(res.body), leagueCode);
              if (games.isNotEmpty) {
                print('[API] ✅ $leagueCode ($dateStr): ${games.length} games');
              }
              return games;
            } catch (e) {
              return <Game>[];
            }
          }
          return <Game>[];
        } catch (e) {
          return <Game>[];
        }
      }).toList();

      final results = await Future.wait(futures);
      for (final g in results) allGames.addAll(g);
    }

    print('[API] $dateStr total: ${allGames.length} games');
    return allGames;
  }

  String _fmt(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  List<String> _utcDatesForLocalDay(DateTime localDay) {
    final startLocal = DateTime(localDay.year, localDay.month, localDay.day, 0, 0);
    final endLocal   = DateTime(localDay.year, localDay.month, localDay.day, 23, 59);
    final startUtc   = startLocal.toUtc();
    final endUtc     = endLocal.toUtc();

    final dates = <String>{};
    dates.add(_fmt(startUtc));
    dates.add(_fmt(endUtc));
    return dates.toList();
  }

  Future<List<Game>> _fetchAllLeaguesForLocalDay(
      DateTime localDay,
      List<Map<String, String>> leagues,
      ) async {
    final utcDates = _utcDatesForLocalDay(localDay);
    print('[API] UTC dates for local ${_fmt(localDay)}: $utcDates');

    final futures = utcDates.map((d) => _fetchLeaguesInParallel(leagues, d));
    final results = await Future.wait(futures);

    final seen   = <String>{};
    final merged = <Game>[];
    for (final batch in results) {
      for (final g in batch) {
        if (seen.add(g.id)) merged.add(g);
      }
    }

    print('[API] Total games: ${merged.length} for local ${_fmt(localDay)}');
    return merged;
  }

  void _buildPriorityCache() {
    if (_leaguePriorityCache.isNotEmpty) return;
    for (int i = 0; i < AppConstants.allLeagues.length; i++) {
      _leaguePriorityCache[AppConstants.allLeagues[i]['name']!] = i;
    }
  }

  void _sortGames(List<Game> games) {
    _buildPriorityCache();

    games.sort((a, b) {
      final aLive = a.status == 'STATUS_LIVE' ? 0 : (a.status == 'STATUS_SCHEDULED' ? 1 : 2);
      final bLive = b.status == 'STATUS_LIVE' ? 0 : (b.status == 'STATUS_SCHEDULED' ? 1 : 2);
      if (aLive != bLive) return aLive.compareTo(bLive);

      final aPriority = _leaguePriorityCache[a.leagueName] ?? 9999;
      final bPriority = _leaguePriorityCache[b.leagueName] ?? 9999;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      final aDate = DateTime.tryParse(a.date) ?? DateTime.now();
      final bDate = DateTime.tryParse(b.date) ?? DateTime.now();
      return aDate.compareTo(bDate);
    });
  }

  Future<List<Game>> getAllTodaysMatchesProgressive({
    Function(List<Game> partialGames)? onPartialUpdate,
  }) async {
    final now = DateTime.now();
    print('\n=== TODAY (Progressive) ===');

    final allGames = <Game>[];

    print('[API] Wave 1 — PRIORITY leagues (${AppConstants.priorityLeagues.length})');
    final priorityGames = await _fetchAllLeaguesForLocalDay(now, AppConstants.priorityLeagues);
    allGames.addAll(priorityGames);
    _sortGames(allGames);

    if (onPartialUpdate != null && priorityGames.isNotEmpty) {
      onPartialUpdate(List.from(allGames));
    }

    _loadBackgroundLeaguesProgressive(AppConstants.majorClubCompetitions, now, allGames, onPartialUpdate);
    _loadBackgroundLeaguesProgressive(AppConstants.backgroundLeagues, now, allGames, onPartialUpdate);
    _loadBackgroundLeaguesProgressive(AppConstants.internationalLeagues, now, allGames, onPartialUpdate);

    print('Progressive Wave-1 total: ${allGames.length} games');
    return allGames;
  }

  void _loadBackgroundLeaguesProgressive(
      List<Map<String, String>> leagues,
      DateTime localDay,
      List<Game> currentGames,
      Function(List<Game> partialGames)? onPartialUpdate,
      ) async {
    print('[API] Loading BACKGROUND leagues (${leagues.length} leagues)');

    final backgroundGames = await _fetchAllLeaguesForLocalDay(localDay, leagues);

    final existingIds = currentGames.map((g) => g.id).toSet();
    final newGames = backgroundGames.where((g) => !existingIds.contains(g.id)).toList();

    if (newGames.isNotEmpty) {
      currentGames.addAll(newGames);
      _sortGames(currentGames);
      print('[API] Added ${newGames.length} games from background leagues');

      if (onPartialUpdate != null) {
        onPartialUpdate(List.from(currentGames));
      }
    } else {
      print('[API] No new games from background leagues');
    }
  }

  Future<List<Game>> getAllGamesByDateStringProgressive(
      String dateStr, {
        Function(List<Game> partialGames)? onPartialUpdate,
      }) async {
    print('\n=== CUSTOM DATE $dateStr ===');
    final year = int.tryParse(dateStr.substring(0, 4)) ?? 0;
    final month = int.tryParse(dateStr.substring(4, 6)) ?? 0;
    final day = int.tryParse(dateStr.substring(6, 8)) ?? 0;

    if (year == 0 || month == 0 || day == 0) {
      return [];
    }

    final targetDate = DateTime(year, month, day);
    final allGames = <Game>[];

    print('[API] Loading priority leagues for custom date');
    final priorityGames = await _fetchAllLeaguesForLocalDay(targetDate, AppConstants.priorityLeagues);
    allGames.addAll(priorityGames);
    _sortGames(allGames);

    if (onPartialUpdate != null && priorityGames.isNotEmpty) {
      onPartialUpdate(List.from(allGames));
    }

    print('[API] Loading major competitions for custom date');
    final competitionGames = await _fetchAllLeaguesForLocalDay(targetDate, AppConstants.majorClubCompetitions);
    allGames.addAll(competitionGames);
    _sortGames(allGames);

    if (onPartialUpdate != null && competitionGames.isNotEmpty) {
      onPartialUpdate(List.from(allGames));
    }

    final remainingLeagues = [
      ...AppConstants.backgroundLeagues,
      ...AppConstants.internationalLeagues,
    ];

    _loadBackgroundLeaguesProgressive(remainingLeagues, targetDate, allGames, onPartialUpdate);

    print('Custom date progressive total: ${allGames.length} games');
    return allGames;
  }

  Future<List<Game>> getAllTodaysMatches() async {
    final now = DateTime.now();
    print('\n=== TODAY ${_fmt(now)} ===');

    print('[API] Wave 1 — PRIORITY (${AppConstants.priorityLeagues.length})');
    final priorityGames = await _fetchAllLeaguesForLocalDay(now, AppConstants.priorityLeagues);

    List<Game> allGames = [...priorityGames];
    _sortGames(allGames);

    _loadBackgroundLeagues(AppConstants.majorClubCompetitions, now, allGames);
    _loadBackgroundLeagues(AppConstants.backgroundLeagues, now, allGames);
    _loadBackgroundLeagues(AppConstants.internationalLeagues, now, allGames);

    print('Wave-1 total: ${allGames.length} games');
    return allGames;
  }

  void _loadBackgroundLeagues(
      List<Map<String, String>> leagues,
      DateTime localDay,
      List<Game> currentGames) async {
    print('[API] Loading BACKGROUND leagues in background (${leagues.length} leagues)');

    final backgroundGames = await _fetchAllLeaguesForLocalDay(localDay, leagues);

    final existingIds = currentGames.map((g) => g.id).toSet();
    final newGames = backgroundGames.where((g) => !existingIds.contains(g.id)).toList();

    if (newGames.isNotEmpty) {
      currentGames.addAll(newGames);
      _sortGames(currentGames);
      print('[API] Added ${newGames.length} games from background leagues');
    } else {
      print('[API] No new games from background leagues');
    }
  }

  Future<List<Game>> getAllYesterdaysMatches() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    print('\n=== YESTERDAY ${_fmt(yesterday)} ===');

    final priorityGames    = await _fetchAllLeaguesForLocalDay(yesterday, AppConstants.priorityLeagues);
    final competitionGames = await _fetchAllLeaguesForLocalDay(yesterday, AppConstants.majorClubCompetitions);
    final backgroundGames  = await _fetchAllLeaguesForLocalDay(yesterday, [
      ...AppConstants.backgroundLeagues,
      ...AppConstants.internationalLeagues,
    ]);

    final allGames = [...priorityGames, ...competitionGames, ...backgroundGames];
    _sortGames(allGames);
    print('Yesterday total: ${allGames.length} games');
    return allGames;
  }

  Future<List<Game>> getAllTomorrowsMatches() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    print('\n=== TOMORROW ${_fmt(tomorrow)} ===');

    final priorityGames    = await _fetchAllLeaguesForLocalDay(tomorrow, AppConstants.priorityLeagues);
    final competitionGames = await _fetchAllLeaguesForLocalDay(tomorrow, AppConstants.majorClubCompetitions);
    final backgroundGames  = await _fetchAllLeaguesForLocalDay(tomorrow, [
      ...AppConstants.backgroundLeagues,
      ...AppConstants.internationalLeagues,
    ]);

    final allGames = [...priorityGames, ...competitionGames, ...backgroundGames];
    _sortGames(allGames);
    print('Tomorrow total: ${allGames.length} games');
    return allGames;
  }

  Future<List<Game>> getGamesForDate(DateTime date) async {
    print('\n=== FETCHING GAMES FOR ${_fmt(date)} ===');
    final games = await _fetchAllLeaguesForLocalDay(date, AppConstants.allLeagues);
    _sortGames(games);
    print('Total games for ${_fmt(date)}: ${games.length}');
    return games;
  }

  Future<List<Game>> getAllYesterdaysMatchesProgressive({
    Function(List<Game> partialGames)? onPartialUpdate,
  }) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    print('\n=== YESTERDAY (Progressive) ===');

    final allGames = <Game>[];

    print('[API] Wave 1 — PRIORITY leagues');
    final priorityGames = await _fetchAllLeaguesForLocalDay(yesterday, AppConstants.priorityLeagues);
    allGames.addAll(priorityGames);
    _sortGames(allGames);

    if (onPartialUpdate != null && priorityGames.isNotEmpty) {
      onPartialUpdate(List.from(allGames));
    }

    _loadBackgroundLeaguesProgressive(AppConstants.majorClubCompetitions, yesterday, allGames, onPartialUpdate);
    _loadBackgroundLeaguesProgressive(AppConstants.backgroundLeagues, yesterday, allGames, onPartialUpdate);
    _loadBackgroundLeaguesProgressive(AppConstants.internationalLeagues, yesterday, allGames, onPartialUpdate);

    print('Progressive yesterday Wave-1 total: ${allGames.length} games');
    return allGames;
  }

  Future<List<Game>> getAllTomorrowsMatchesProgressive({
    Function(List<Game> partialGames)? onPartialUpdate,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    print('\n=== TOMORROW (Progressive) ===');

    final allGames = <Game>[];

    print('[API] Wave 1 — PRIORITY leagues');
    final priorityGames = await _fetchAllLeaguesForLocalDay(tomorrow, AppConstants.priorityLeagues);
    allGames.addAll(priorityGames);
    _sortGames(allGames);

    if (onPartialUpdate != null && priorityGames.isNotEmpty) {
      onPartialUpdate(List.from(allGames));
    }

    _loadBackgroundLeaguesProgressive(AppConstants.majorClubCompetitions, tomorrow, allGames, onPartialUpdate);
    _loadBackgroundLeaguesProgressive(AppConstants.backgroundLeagues, tomorrow, allGames, onPartialUpdate);
    _loadBackgroundLeaguesProgressive(AppConstants.internationalLeagues, tomorrow, allGames, onPartialUpdate);

    print('Progressive tomorrow Wave-1 total: ${allGames.length} games');
    return allGames;
  }

  Future<List<Game>> getGamesForDateRange(DateTime startDate, DateTime endDate) async {
    print('[API] Fetching matches from ${_fmt(startDate)} to ${_fmt(endDate)}');

    final allGames = <Game>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final games = await _fetchAllLeaguesForLocalDay(current, AppConstants.allLeagues);
      allGames.addAll(games);
      current = current.add(const Duration(days: 1));
    }

    _sortGames(allGames);
    print('[API] Found ${allGames.length} games in date range');
    return allGames;
  }

  Future<List<Game>> getChampionsLeagueMatches() async {
    final year = DateTime.now().year;
    final may1 = DateTime(year, 5, 1);
    final june7 = DateTime(year, 6, 7);

    final allMatches = await getGamesForDateRange(may1, june7);

    return allMatches.where((game) =>
        game.leagueName.toLowerCase().contains('champions league')
    ).toList();
  }

  Future<List<Game>> getAllGamesByDateString(String dateStr) async {
    print('\n=== CUSTOM DATE $dateStr ===');
    final year  = int.tryParse(dateStr.substring(0, 4)) ?? 0;
    final month = int.tryParse(dateStr.substring(4, 6)) ?? 0;
    final day   = int.tryParse(dateStr.substring(6, 8)) ?? 0;

    List<Game> games;
    if (year > 0 && month > 0 && day > 0) {
      print('[API] Fetching ALL leagues for custom date');
      games = await _fetchAllLeaguesForLocalDay(
          DateTime(year, month, day), AppConstants.allLeagues);
    } else {
      games = await _fetchLeaguesInParallel(AppConstants.allLeagues, dateStr);
    }
    _sortGames(games);
    print('Custom total: ${games.length} games');
    return games;
  }

  Future<List<Game>> getInitialTodaysMatches() async {
    final now = DateTime.now();
    final formattedDate = _fmt(now);
    print('\n=== INITIAL TODAY $formattedDate (fast) ===');
    print('[API] Fetching ${AppConstants.priorityLeagues.length} priority leagues');
    final games = await _fetchAllLeaguesForLocalDay(now, AppConstants.priorityLeagues);
    _sortGames(games);
    print('Initial: ${games.length} games');
    return games;
  }

  Future<List<Game>> getRemainingLeaguesMatches() async {
    final now = DateTime.now();
    final formattedDate = _fmt(now);
    print('\n=== REMAINING LEAGUES $formattedDate ===');
    final remainingLeagues = [...AppConstants.majorClubCompetitions, ...AppConstants.backgroundLeagues, ...AppConstants.internationalLeagues];
    print('[API] Fetching ${remainingLeagues.length} remaining leagues');
    final games = await _fetchAllLeaguesForLocalDay(now, remainingLeagues);
    print('Remaining: ${games.length} games');
    return games;
  }

  Future<List<Game>> getAllLiveMatches() async {
    final now = DateTime.now();
    final formattedDate = _fmt(now);
    print('\n=== LIVE MATCHES $formattedDate ===');
    final games = await _fetchAllLeaguesForLocalDay(now, AppConstants.allLeagues);
    final live = games.where((g) => g.status == 'STATUS_LIVE').toList();
    live.sort((a, b) => a.date.compareTo(b.date));
    print('Live games: ${live.length}');
    return live;
  }

  Future<List<Game>> getGamesByDate(String leagueCode, DateTime date) async {
    final dateStr = _fmt(date.toUtc());
    final url = '${AppConstants.baseUrl}/$leagueCode/scoreboard?dates=$dateStr';
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return _parseGamesFromScoreboard(json.decode(res.body), leagueCode);
    } catch (e) { print('getGamesByDate $leagueCode: $e'); }
    return [];
  }

  Future<List<Game>> getGamesByDateString(String leagueCode, String dateStr) async {
    final url = '${AppConstants.baseUrl}/$leagueCode/scoreboard?dates=$dateStr';
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return _parseGamesFromScoreboard(json.decode(res.body), leagueCode);
    } catch (e) { print('getGamesByDateString $leagueCode: $e'); }
    return [];
  }

  // Add this method to ApiService class in api_service.dart

  // Replace the existing getStandings method with this:

  Future<List<Standing>> getStandings(String leagueCode, {String? season}) async {
    final seasonQuery = (season != null && season.isNotEmpty) ? '?season=$season' : '';
    final url = '${AppConstants.standingsUrl}/$leagueCode/standings$seasonQuery';
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return _parseSoccerStandingsFixed(json.decode(res.body), leagueCode);
      }
    } catch (e) {
      print('getStandings $leagueCode: $e');
    }
    throw Exception('Failed to load standings for $leagueCode');
  }

  List<Standing> _parseSoccerStandingsFixed(Map<String, dynamic> data, String leagueCode) {
    final List<Standing> standings = [];

    print('[Standings] Parsing standings for league: $leagueCode');

    // Helper function to extract entries recursively
    List<dynamic> extractEntries(dynamic node) {
      final List<dynamic> entries = [];

      if (node == null) return entries;

      // If this node has direct standings entries
      if (node['standings'] != null) {
        final standingsData = node['standings'];
        if (standingsData['entries'] != null) {
          entries.addAll(standingsData['entries'] as List);
        } else if (standingsData is List) {
          entries.addAll(standingsData);
        }
      }

      // If this node has children, recurse
      if (node['children'] != null && (node['children'] as List).isNotEmpty) {
        for (final child in node['children'] as List) {
          entries.addAll(extractEntries(child));
        }
      }

      return entries;
    }

    // Extract all entries
    final List<dynamic> allEntries = extractEntries(data);
    print('[Standings] Found ${allEntries.length} entries');

    int rank = 1;
    String currentGroup = '';

    for (final entry in allEntries) {
      try {
        final teamData = entry['team'] as Map<String, dynamic>? ?? {};
        final statsList = entry['stats'] as List? ?? [];

        // Parse all stats with ESPN's actual field names
        final Map<String, String> statsMap = {};
        int? points, goalsFor, goalsAgainst, gamesPlayed, wins, draws, losses;
        String? form;

        for (final stat in statsList) {
          final name  = stat['name']?.toString() ?? '';
          final abbr  = stat['abbreviation']?.toString() ?? '';
          final displayValue = stat['displayValue']?.toString() ?? '0';
          statsMap[name] = displayValue;
          if (abbr.isNotEmpty) statsMap[abbr] = displayValue; // also index by abbreviation

          // Map ESPN stat names to our fields.
          // ESPN soccer standings use 'pointsFor'/'pointsAgainst' for goals (not 'goalsFor'!)
          // and sometimes 'pointDifferential' for GD. Cover all known variants.
          final key = name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
          final abbrKey = abbr.toLowerCase();
          switch (key) {
            case 'points':
            case 'pts':
              points = int.tryParse(displayValue);
              break;
          // ── Goals For ─────────────────────────────────────────────────────
            case 'pointsfor':      // ← ESPN's actual field name for soccer GF
            case 'goalsfor':
            case 'goalsscored':
            case 'gf':
              goalsFor = int.tryParse(displayValue);
              break;
          // ── Goals Against ─────────────────────────────────────────────────
            case 'pointsagainst':  // ← ESPN's actual field name for soccer GA
            case 'goalsagainst':
            case 'goalsconceded':
            case 'ga':
              goalsAgainst = int.tryParse(displayValue);
              break;
          // ── Goal Difference ───────────────────────────────────────────────
            case 'pointdifferential':
            case 'pointsdiff':
            case 'goaldifference':
            case 'goaldiff':
            case 'gd':
            case 'diff':
            // Use directly when available instead of computing
              final gdVal = int.tryParse(displayValue);
              if (gdVal != null && goalsFor == null && goalsAgainst == null) {
                // Store for later — can't assign directly here; handled below
              }
              break;
          // ── Games Played ──────────────────────────────────────────────────
            case 'gamesplayed':
            case 'matchesplayed':
            case 'played':
            case 'gp':
            case 'mp':
              gamesPlayed = int.tryParse(displayValue);
              break;
            case 'wins':
            case 'w':
              wins = int.tryParse(displayValue);
              break;
            case 'ties':
            case 'draws':
            case 'd':
              draws = int.tryParse(displayValue);
              break;
            case 'losses':
            case 'l':
              losses = int.tryParse(displayValue);
              break;
            case 'form':
            case 'last5':
            case 'formguide':
            case 'recentform':
              form = displayValue;
              break;
          }
          // Abbreviation fallback for when name doesn't match
          if (goalsFor == null && (abbrKey == 'gf' || abbrKey == 'pf')) {
            goalsFor = int.tryParse(displayValue);
          }
          if (goalsAgainst == null && (abbrKey == 'ga' || abbrKey == 'pa')) {
            goalsAgainst = int.tryParse(displayValue);
          }
          if (gamesPlayed == null && (abbrKey == 'gp' || abbrKey == 'mp' || abbrKey == 'p')) {
            gamesPlayed = int.tryParse(displayValue);
          }
          if (wins == null && abbrKey == 'w') wins = int.tryParse(displayValue);
          if (draws == null && (abbrKey == 'd' || abbrKey == 'dr')) draws = int.tryParse(displayValue);
          if (losses == null && abbrKey == 'l') losses = int.tryParse(displayValue);
          if (points == null && (abbrKey == 'pts' || abbrKey == 'pt')) points = int.tryParse(displayValue);
        }

        // Calculate goal difference
        final gd = (goalsFor ?? 0) - (goalsAgainst ?? 0);

        // Get group/conference name
        final groupName = entry['group']?['name']?.toString() ??
            entry['conference']?.toString() ??
            entry['division']?.toString() ?? '';

        if (groupName.isNotEmpty && groupName != currentGroup) {
          currentGroup = groupName;
          print('[Standings] Group: $currentGroup');
        }

        standings.add(Standing(
          rank: rank++,
          team: TeamInfo(
            id: teamData['id']?.toString() ?? '',
            name: teamData['name']?.toString() ?? '',
            displayName: teamData['displayName']?.toString() ?? '',
            abbreviation: teamData['abbreviation']?.toString() ?? '',
            logo: _resolveTeamLogo(teamData),
            color: '#${teamData['color']?.toString() ?? '1A62C8'}',
            alternateColor: '#${teamData['alternateColor']?.toString() ?? 'FFFFFF'}',
            record: '${wins ?? 0}-${losses ?? 0}-${draws ?? 0}',
          ),
          wins: (wins ?? 0).toString(),
          losses: (losses ?? 0).toString(),
          ties: (draws ?? 0).toString(),
          winPercentage: statsMap['winPercent'] ?? '.000',
          pointsFor: (goalsFor ?? 0).toString(),
          pointsAgainst: (goalsAgainst ?? 0).toString(),
          streak: statsMap['streak'] ?? '0',
          clinchedPlayoffs: entry['clinched'] ?? false,
          conference: groupName,
          division: entry['division']?.toString() ?? '',
          stats: statsMap,
          points: points,
          goalsFor: goalsFor,
          goalsAgainst: goalsAgainst,
          goalDifference: gd,
          form: form,
          matchesPlayed: gamesPlayed,
        ));
      } catch (e) {
        print('[Standings] Error parsing entry: $e');
      }
    }

    // Sort by points (descending), then goal difference, then goals for
    standings.sort((a, b) {
      final aPoints = a.points ?? 0;
      final bPoints = b.points ?? 0;
      if (aPoints != bPoints) return bPoints.compareTo(aPoints);

      final aGD = a.goalDifference ?? 0;
      final bGD = b.goalDifference ?? 0;
      if (aGD != bGD) return bGD.compareTo(aGD);

      final aGF = a.goalsFor ?? 0;
      final bGF = b.goalsFor ?? 0;
      return bGF.compareTo(aGF);
    });

    // Update ranks after sorting
    for (int i = 0; i < standings.length; i++) {
      final s = standings[i];
      standings[i] = Standing(
        rank: i + 1,
        team: s.team,
        wins: s.wins,
        losses: s.losses,
        ties: s.ties,
        winPercentage: s.winPercentage,
        pointsFor: s.pointsFor,
        pointsAgainst: s.pointsAgainst,
        streak: s.streak,
        clinchedPlayoffs: s.clinchedPlayoffs,
        conference: s.conference,
        division: s.division,
        stats: s.stats,
        points: s.points,
        goalsFor: s.goalsFor,
        goalsAgainst: s.goalsAgainst,
        goalDifference: s.goalDifference,
        form: s.form,
        matchesPlayed: s.matchesPlayed,
      );
    }

    print('[Standings] Parsed ${standings.length} standings');
    return standings;
  }

  // ── League Stat Leaders ───────────────────────────────────────────────────────
  //
  // Strategy (tried in order):
  //
  // 1. site.web.api.espn.com /apis/v2/sports/soccer/leagues/{code}/seasons/{year}/types/{type}/leaders
  //    — This is the endpoint ESPN's own scorers page uses. Returns inline athlete
  //    and team objects (no $ref resolution needed). Tried with type=2 (regular
  //    season), then type=3 (tournament), then without the types segment.
  //
  // 2. Aggregate from the last 90 days of daily scoreboard calls.
  //    ESPN scoreboard only accepts single dates (date RANGE params → 400).
  //    We fetch daily scoreboards for the past 90 days (batched, parallel)
  //    and tally goals/assists/cards from each game's details[] array —
  //    the same source that powers _parseGoalScorers() for live game cards.
  //    This always works for active seasons and the ongoing World Cup.
  //
  static const String _coreApiBase = 'https://sports.core.api.espn.com/v2/sports/soccer/leagues';

  Future<LeagueLeaders> getLeagueLeaders(String leagueCode, {String? season, int limit = 5}) async {
    // ── Strategy 1: site.web.api ESPN leaders endpoint ────────────────────────
    // This is what espn.com/soccer/scorers uses. Returns inline data, no $refs.
    final result1 = await _tryWebApiLeaders(leagueCode, season: season, limit: limit);
    if (!result1.isEmpty) {
      print('[Leaders] ✅ Got leaders from web API for $leagueCode');
      return result1;
    }

    // ── Strategy 2: Aggregate from season-correct daily scoreboards ─────────
    // ESPN scoreboard only accepts single dates (ranges → 400).
    // We fetch daily scoreboards for the correct season window and tally stats.
    print('[Leaders] Web API returned empty, falling back to scoreboard aggregation');
    final result2 = await _aggregateLeadersFromRecentGames(leagueCode, season: season, limit: limit);
    if (!result2.isEmpty) {
      print('[Leaders] ✅ Got leaders from scoreboard aggregation for $leagueCode');
      return result2;
    }

    print('[Leaders] No leaders data available for $leagueCode');
    return LeagueLeaders.empty;
  }

  /// Strategy 1: ESPN's web API leaders endpoint (what espn.com scorers page uses).
  /// Tries multiple URL patterns: with types/2, types/3, and without types segment.
  Future<LeagueLeaders> _tryWebApiLeaders(String leagueCode, {String? season, int limit = 5}) async {
    final int seasonYear = int.tryParse(season ?? '') ?? DateTime.now().year;
    // For World Cup / tournaments use seasontype 3; domestic leagues use 2; try both
    final bool isTournament = AppConstants.isNationalTeamLeague(leagueCode);
    final primaryType = isTournament ? 3 : 2;
    final fallbackType = isTournament ? 2 : 3;

    final urlPatterns = [
      'https://site.web.api.espn.com/apis/v2/sports/soccer/leagues/$leagueCode/seasons/$seasonYear/types/$primaryType/leaders?limit=$limit&lang=en&region=us',
      'https://site.web.api.espn.com/apis/v2/sports/soccer/leagues/$leagueCode/seasons/$seasonYear/types/$fallbackType/leaders?limit=$limit&lang=en&region=us',
      'https://site.web.api.espn.com/apis/v2/sports/soccer/leagues/$leagueCode/seasons/$seasonYear/leaders?limit=$limit&lang=en&region=us',
    ];

    for (final url in urlPatterns) {
      try {
        print('[Leaders] Trying: $url');
        final res = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final leaders = _parseWebApiLeaders(data, limit);
          if (!leaders.isEmpty) return leaders;
        } else {
          print('[Leaders] HTTP ${res.statusCode} for $url');
        }
      } catch (e) {
        print('[Leaders] Error trying $url: $e');
      }
    }
    return LeagueLeaders.empty;
  }

  /// Parses the site.web.api leaders response.
  /// Response shape: { categories: [ { name, displayName, leaders: [ { athlete:{}, team:{}, value } ] } ] }
  LeagueLeaders _parseWebApiLeaders(Map<String, dynamic> data, int limit) {
    final categories = data['categories'] as List? ?? [];
    if (categories.isEmpty) return LeagueLeaders.empty;

    List<LeaderEntry> parseCategory(List<String> namePatterns) {
      for (final cat in categories) {
        final catName = (cat['name'] ?? cat['displayName'] ?? cat['abbreviation'] ?? '')
            .toString().toLowerCase();
        if (!namePatterns.any((p) => catName.contains(p))) continue;

        final rawLeaders = cat['leaders'] as List? ?? [];
        final entries = <LeaderEntry>[];

        for (final leader in rawLeaders.take(limit)) {
          try {
            // site.web.api returns inline athlete/team objects (no $ref)
            final athlete = leader['athlete'] as Map<String, dynamic>? ?? {};
            final team    = leader['team']    as Map<String, dynamic>? ?? {};
            final value   = leader['value'] ?? leader['displayValue'] ?? 0;

            // Athlete may be nested under 'athlete' key or be the leader itself
            final athleteId   = athlete['id']?.toString() ?? '';
            final athleteName = athlete['displayName']?.toString()
                ?? athlete['fullName']?.toString() ?? '';
            if (athleteName.isEmpty && athleteId.isEmpty) continue;

            // Headshot: inline href, or CDN pattern
            String headshot = '';
            final hs = athlete['headshot'];
            if (hs is Map)        headshot = hs['href']?.toString() ?? '';
            else if (hs is String) headshot = hs;
            if (headshot.isEmpty && athleteId.isNotEmpty) {
              headshot = 'https://a.espncdn.com/i/headshots/soccer/players/full/$athleteId.png';
            }

            // Team logo
            final teamId   = team['id']?.toString() ?? '';
            String teamLogo = '';
            final logos = team['logos'] as List?;
            if (logos != null && logos.isNotEmpty) {
              teamLogo = logos.first['href']?.toString() ?? '';
            }
            if (teamLogo.isEmpty && team['logo'] != null) {
              teamLogo = team['logo'].toString();
            }
            if (teamLogo.isEmpty && teamId.isNotEmpty) {
              teamLogo = 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png';
            }

            entries.add(LeaderEntry(
              athleteId: athleteId,
              name: athleteName,
              headshot: headshot,
              teamId: teamId,
              teamAbbreviation: team['abbreviation']?.toString() ?? '',
              teamLogo: teamLogo,
              value: value is num ? value : num.tryParse(value.toString()) ?? 0,
            ));
          } catch (e) {
            print('[Leaders] Error parsing leader entry: $e');
          }
        }

        if (entries.isNotEmpty) return entries;
      }
      return [];
    }

    final scorers = parseCategory(['goals', 'scoring', 'goal']);
    final assists = parseCategory(['assist']);
    final yellow  = parseCategory(['yellow']);
    final red     = parseCategory(['red']);

    if (scorers.isEmpty && assists.isEmpty && yellow.isEmpty && red.isEmpty) {
      return LeagueLeaders.empty;
    }

    return LeagueLeaders(
      topScorers: scorers,
      topAssists: assists,
      mostYellowCards: yellow,
      mostRedCards: red,
    );
  }

  /// Strategy 2: Aggregate stats from season-correct daily scoreboards.
  /// ESPN only supports single-date scoreboard calls (date ranges → 400).
  /// We sample every 7th day across the season window (≈52 calls for a full year)
  /// rather than fetching all 365 days, which balances coverage vs latency.
  Future<LeagueLeaders> _aggregateLeadersFromRecentGames(
      String leagueCode, {String? season, int limit = 5}) async {

    // Compute the correct season date window from the season param.
    // ESPN season convention: season='2025' = the 2024-25 season.
    //   Domestic leagues: Aug 1 of (year-1) → Jun 30 of (year)
    //   World Cup / international tournaments: Jan 1 of year → Dec 31 of year
    final now = DateTime.now();
    final int seasonYear = int.tryParse(season ?? '') ?? now.year;
    final bool isTournament = AppConstants.isNationalTeamLeague(leagueCode);

    DateTime rangeStart, rangeEnd;
    if (isTournament) {
      // Tournament: single calendar year
      rangeStart = DateTime(seasonYear, 1, 1);
      rangeEnd   = DateTime(seasonYear, 12, 31);
    } else {
      // Domestic league: Aug of previous year → Jun of season year
      rangeStart = DateTime(seasonYear - 1, 8, 1);
      rangeEnd   = DateTime(seasonYear, 6, 30);
    }

    // Don't fetch into the future
    if (rangeEnd.isAfter(now)) rangeEnd = now;
    // If rangeStart is in the future (e.g. next season selected), abort
    if (rangeStart.isAfter(now)) {
      print('[Leaders] Season $seasonYear is in the future, skipping aggregation');
      return LeagueLeaders.empty;
    }

    // Sample every 7 days across the range (≈52 samples for a full season)
    final dates = <String>[];
    for (var d = rangeStart; d.isBefore(rangeEnd) || d.isAtSameMomentAs(rangeEnd);
    d = d.add(const Duration(days: 7))) {
      dates.add(_fmt(d));
    }
    // Always include the last day of range to catch end-of-season games
    final lastFmt = _fmt(rangeEnd);
    if (!dates.contains(lastFmt)) dates.add(lastFmt);

    print('[Leaders] Fetching ${dates.length} weekly scoreboard samples for $leagueCode season $seasonYear '
        '(${_fmt(rangeStart)} → ${_fmt(rangeEnd)})');

    final Map<String, Map<String, dynamic>> playerStats = {};
    const batchSize = 10;

    for (int i = 0; i < dates.length; i += batchSize) {
      final batch = dates.sublist(i, (i + batchSize).clamp(0, dates.length));
      final futures = batch.map((dateStr) async {
        final url = '${AppConstants.baseUrl}/$leagueCode/scoreboard?dates=$dateStr';
        try {
          final res = await _client
              .get(Uri.parse(url), headers: _headers)
              .timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) return;
          final data = json.decode(res.body) as Map<String, dynamic>;
          _tallyStatsFromScoreboard(data, playerStats);
        } catch (_) {}
      }).toList();
      await Future.wait(futures);
    }

    if (playerStats.isEmpty) {
      print('[Leaders] No stats found in scoreboard aggregation for $leagueCode $seasonYear');
      return LeagueLeaders.empty;
    }

    print('[Leaders] Aggregated stats for ${playerStats.length} players from $leagueCode $seasonYear');

    LeaderEntry _toEntry(MapEntry<String, Map<String, dynamic>> e, String statKey) {
      final s = e.value;
      String headshot = s['headshot'] as String? ?? '';
      if (headshot.isEmpty) {
        headshot = 'https://a.espncdn.com/i/headshots/soccer/players/full/${e.key}.png';
      }
      return LeaderEntry(
        athleteId: e.key,
        name: s['name'] as String? ?? '',
        headshot: headshot,
        teamId: s['teamId'] as String? ?? '',
        teamAbbreviation: s['teamAbbr'] as String? ?? '',
        teamLogo: s['teamLogo'] as String? ?? '',
        value: s[statKey] as int,
      );
    }

    List<LeaderEntry> buildList(String statKey) {
      return (playerStats.entries.toList()
        ..sort((a, b) => (b.value[statKey] as int).compareTo(a.value[statKey] as int)))
          .where((e) => (e.value[statKey] as int) > 0)
          .take(limit)
          .map((e) => _toEntry(e, statKey))
          .toList();
    }

    final topScorers = buildList('goals');
    final topAssists = buildList('assists');
    final mostYellow = buildList('yellow');
    final mostRed    = buildList('red');

    print('[Leaders] Aggregation results → scorers:${topScorers.length} '
        'assists:${topAssists.length} yellow:${mostYellow.length} red:${mostRed.length}');

    return LeagueLeaders(
      topScorers: topScorers,
      topAssists: topAssists,
      mostYellowCards: mostYellow,
      mostRedCards: mostRed,
    );
  }

  /// Tallies goals/assists/yellow/red from a scoreboard response's details[] arrays.
  void _tallyStatsFromScoreboard(
      Map<String, dynamic> data, Map<String, Map<String, dynamic>> playerStats) {
    final events = data['events'] as List? ?? [];

    for (final event in events) {
      // Only count completed matches
      final state     = event['status']?['type']?['state']?.toString() ?? '';
      final completed = event['status']?['type']?['completed'] == true;
      if (state != 'post' && !completed) continue;

      final competition =
      (event['competitions'] as List?)?.first as Map<String, dynamic>?;
      if (competition == null) continue;

      // Build teamId → {abbr, logo} for this game
      final Map<String, Map<String, String>> teamInfo = {};
      for (final c in (competition['competitors'] as List? ?? [])) {
        final t   = c['team'] as Map<String, dynamic>? ?? {};
        final tid = t['id']?.toString() ?? '';
        if (tid.isEmpty) continue;
        String logo = t['logo']?.toString() ?? '';
        if (logo.isEmpty) {
          logo = 'https://a.espncdn.com/i/teamlogos/soccer/500/$tid.png';
        }
        teamInfo[tid] = {'abbr': t['abbreviation']?.toString() ?? '', 'logo': logo};
      }

      final details = competition['details'] as List? ?? [];
      for (final detail in details) {
        final typeStr = (detail['type']?['text'] ?? detail['type']?['name'] ?? '')
            .toString().toLowerCase();
        final athletes = detail['athletesInvolved'] as List? ?? [];
        if (athletes.isEmpty) continue;

        final teamId = detail['team']?['id']?.toString() ?? '';
        final tInfo  = teamInfo[teamId] ?? {};

        void credit(Map<String, dynamic> athlete, String key) {
          final pid = athlete['id']?.toString() ?? '';
          if (pid.isEmpty) return;
          final stats = playerStats.putIfAbsent(pid, () => _emptyPlayerStat(athlete, teamId, tInfo));
          stats[key] = (stats[key] as int) + 1;
          // Update team info with richer data when available
          if (teamId.isNotEmpty) stats['teamId'] = teamId;
          if ((tInfo['abbr'] ?? '').isNotEmpty) stats['teamAbbr'] = tInfo['abbr'];
          if ((tInfo['logo'] ?? '').isNotEmpty) stats['teamLogo'] = tInfo['logo'];
        }

        if (typeStr.contains('goal') && !typeStr.contains('penalty miss')) {
          credit(athletes.first as Map<String, dynamic>, 'goals');
          // Assist: second athlete, only for non-own-goals
          if (!typeStr.contains('own goal') && athletes.length > 1) {
            credit(athletes[1] as Map<String, dynamic>, 'assists');
          }
        } else if (typeStr.contains('yellow card') &&
            !typeStr.contains('second yellow') && !typeStr.contains('red')) {
          credit(athletes.first as Map<String, dynamic>, 'yellow');
        } else if (typeStr.contains('red card') || typeStr.contains('second yellow')) {
          credit(athletes.first as Map<String, dynamic>, 'red');
        }
      }
    }
  }

  /// Creates a zeroed-out stat accumulator for a player.
  Map<String, dynamic> _emptyPlayerStat(
      Map<String, dynamic> athlete, String teamId, Map<String, String> tInfo) {
    String headshot = '';
    final rawHs = athlete['headshot'];
    if (rawHs is String && rawHs.isNotEmpty) headshot = rawHs;
    else if (rawHs is Map) headshot = rawHs['href']?.toString() ?? rawHs['full']?.toString() ?? '';

    return {
      'name': athlete['displayName']?.toString() ?? athlete['fullName']?.toString() ?? '',
      'headshot': headshot,
      'teamId': teamId,
      'teamAbbr': tInfo['abbr'] ?? '',
      'teamLogo': tInfo['logo'] ?? '',
      'goals': 0,
      'assists': 0,
      'yellow': 0,
      'red': 0,
    };
  }

  List<Standing> _parseSoccerStandingsImproved(Map<String, dynamic> data, String leagueCode) {

    final List<Standing> standings = [];
    int rank = 1;

    print('[Standings] Parsing standings for league: $leagueCode');

    // Handle different response structures
    List<dynamic> entries = [];

    // Try to find the standings entries
    if (data['children'] != null && (data['children'] as List).isNotEmpty) {
      final children = data['children'] as List;
      for (final child in children) {
        if (child['standings'] != null) {
          final standingsData = child['standings'];
          if (standingsData['entries'] != null) {
            entries.addAll(standingsData['entries'] as List);
          } else if (standingsData is List) {
            entries.addAll(standingsData);
          }
        }
        if (child['children'] != null) {
          for (final subChild in child['children'] as List) {
            if (subChild['standings'] != null) {
              final standingsData = subChild['standings'];
              if (standingsData['entries'] != null) {
                entries.addAll(standingsData['entries'] as List);
              } else if (standingsData is List) {
                entries.addAll(standingsData);
              }
            }
          }
        }
      }
    } else if (data['standings'] != null) {
      final standingsData = data['standings'];
      if (standingsData['entries'] != null) {
        entries = standingsData['entries'] as List;
      } else if (standingsData is List) {
        entries = standingsData;
      }
    }

    print('[Standings] Found ${entries.length} entries');

    for (final entry in entries) {
      try {
        final teamData = entry['team'] as Map<String, dynamic>? ?? {};
        final statsList = entry['stats'] as List? ?? [];

        // Parse all stats
        final Map<String, String> statsMap = {};
        int? points, goalsFor, goalsAgainst, gamesPlayed;
        String? form;

        for (final stat in statsList) {
          final name = stat['name']?.toString() ?? '';
          final abbr = stat['abbreviation']?.toString() ?? '';
          final displayValue = stat['displayValue']?.toString() ?? '0';
          statsMap[name] = displayValue;
          if (abbr.isNotEmpty) statsMap[abbr] = displayValue;

          final key = name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
          final abbrKey = abbr.toLowerCase();
          switch (key) {
            case 'points': case 'pts':
            points = int.tryParse(displayValue); break;
            case 'pointsfor': case 'goalsfor': case 'goalsscored': case 'gf':
            goalsFor = int.tryParse(displayValue); break;
            case 'pointsagainst': case 'goalsagainst': case 'goalsconceded': case 'ga':
            goalsAgainst = int.tryParse(displayValue); break;
            case 'gamesplayed': case 'matchesplayed': case 'played': case 'gp': case 'mp':
            gamesPlayed = int.tryParse(displayValue); break;
            case 'form': case 'last5': case 'formguide': case 'recentform':
            form = displayValue; break;
          }
          if (goalsFor == null && (abbrKey == 'gf' || abbrKey == 'pf')) goalsFor = int.tryParse(displayValue);
          if (goalsAgainst == null && (abbrKey == 'ga' || abbrKey == 'pa')) goalsAgainst = int.tryParse(displayValue);
          if (gamesPlayed == null && (abbrKey == 'gp' || abbrKey == 'mp' || abbrKey == 'p')) gamesPlayed = int.tryParse(displayValue);
          if (points == null && (abbrKey == 'pts' || abbrKey == 'pt')) points = int.tryParse(displayValue);
        }

        // Calculate goal difference
        final gd = (goalsFor ?? 0) - (goalsAgainst ?? 0);

        standings.add(Standing(
          rank: rank++,
          team: TeamInfo(
            id: teamData['id']?.toString() ?? '',
            name: teamData['name']?.toString() ?? '',
            displayName: teamData['displayName']?.toString() ?? '',
            abbreviation: teamData['abbreviation']?.toString() ?? '',
            logo: _resolveTeamLogo(teamData),
            color: '#${teamData['color']?.toString() ?? '1A62C8'}',
            alternateColor: '#${teamData['alternateColor']?.toString() ?? 'FFFFFF'}',
            record: '${statsMap['wins'] ?? '0'}-${statsMap['losses'] ?? '0'}-${statsMap['ties'] ?? '0'}',
          ),
          wins: statsMap['wins'] ?? '0',
          losses: statsMap['losses'] ?? '0',
          ties: statsMap['ties'] ?? '0',
          winPercentage: statsMap['winPercent'] ?? '.000',
          pointsFor: statsMap['pointsFor'] ?? statsMap['goalsFor'] ?? '0',
          pointsAgainst: statsMap['pointsAgainst'] ?? statsMap['goalsAgainst'] ?? '0',
          streak: statsMap['streak'] ?? '0',
          clinchedPlayoffs: entry['clinched'] ?? false,
          conference: '',
          division: '',
          stats: statsMap,
          points: points,
          goalsFor: goalsFor,
          goalsAgainst: goalsAgainst,
          goalDifference: gd,
          form: form,
          matchesPlayed: gamesPlayed,
        ));
      } catch (e) {
        print('[Standings] Error parsing entry: $e');
      }
    }

    // Sort by points (descending), then goal difference
    standings.sort((a, b) {
      final aPoints = a.points ?? int.tryParse(a.stats['points'] ?? '0') ?? 0;
      final bPoints = b.points ?? int.tryParse(b.stats['points'] ?? '0') ?? 0;
      if (aPoints != bPoints) return bPoints.compareTo(aPoints);

      final aGD = a.goalDifference ?? 0;
      final bGD = b.goalDifference ?? 0;
      if (aGD != bGD) return bGD.compareTo(aGD);

      final aGF = a.goalsFor ?? int.tryParse(a.stats['goalsFor'] ?? '0') ?? 0;
      final bGF = b.goalsFor ?? int.tryParse(b.stats['goalsFor'] ?? '0') ?? 0;
      return bGF.compareTo(aGF);
    });

    // Update ranks after sorting
    for (int i = 0; i < standings.length; i++) {
      standings[i] = Standing(
        rank: i + 1,
        team: standings[i].team,
        wins: standings[i].wins,
        losses: standings[i].losses,
        ties: standings[i].ties,
        winPercentage: standings[i].winPercentage,
        pointsFor: standings[i].pointsFor,
        pointsAgainst: standings[i].pointsAgainst,
        streak: standings[i].streak,
        clinchedPlayoffs: standings[i].clinchedPlayoffs,
        conference: standings[i].conference,
        division: standings[i].division,
        stats: standings[i].stats,
        points: standings[i].points,
        goalsFor: standings[i].goalsFor,
        goalsAgainst: standings[i].goalsAgainst,
        goalDifference: standings[i].goalDifference,
        form: standings[i].form,
        matchesPlayed: standings[i].matchesPlayed,
      );
    }

    print('[Standings] Parsed ${standings.length} standings');
    return standings;
  }

  List<Standing> _parseSoccerStandings(Map<String, dynamic> data) {
    final List<Standing> standings = [];
    int rank = 1;

    List<dynamic> children = [];

    if (data['children'] is List) {
      children = data['children'] as List;
    } else if (data['standings'] is List) {
      children = [{'name': 'League', 'standings': data['standings']}];
    }

    void parseStandingEntries(List<dynamic> entries, String groupName) {
      for (final ts in entries) {
        try {
          final team = ts['team'] as Map<String, dynamic>? ?? {};
          final Map<String, String> statsMap = {};
          for (final stat in (ts['stats'] as List? ?? [])) {
            statsMap[stat['name'].toString()] = stat['displayValue']?.toString() ?? '0';
          }
          standings.add(Standing(
            rank: rank++,
            team: TeamInfo(
              id: team['id']?.toString() ?? '',
              name: team['name']?.toString() ?? '',
              displayName: team['displayName']?.toString() ?? '',
              abbreviation: team['abbreviation']?.toString() ?? '',
              logo: _resolveTeamLogo(team),
              color: '#${team['color']?.toString() ?? '1A62C8'}',
              alternateColor: '#${team['alternateColor']?.toString() ?? 'FFFFFF'}',
              record: '${statsMap['wins'] ?? '0'}-${statsMap['losses'] ?? '0'}-${statsMap['ties'] ?? '0'}',
            ),
            wins: statsMap['wins'] ?? '0',
            losses: statsMap['losses'] ?? '0',
            ties: statsMap['ties'] ?? '0',
            winPercentage: statsMap['winPercent'] ?? '.000',
            pointsFor: statsMap['pointsFor'] ?? '0',
            pointsAgainst: statsMap['pointsAgainst'] ?? '0',
            streak: statsMap['streak'] ?? '0',
            clinchedPlayoffs: false,
            conference: groupName,
            division: '',
            stats: statsMap,
          ));
        } catch (e) {
          print('[Standings] Entry parse error: $e');
        }
      }
    }

    for (final child in children) {
      final groupName = child['name']?.toString() ?? 'League';

      if (child['standings'] is List) {
        parseStandingEntries(child['standings'] as List, groupName);
      }
      else if (child['children'] is List) {
        for (final subChild in child['children'] as List) {
          final subGroup = subChild['name']?.toString() ?? groupName;
          if (subChild['standings'] is List) {
            parseStandingEntries(subChild['standings'] as List, subGroup);
          }
        }
      }
    }

    return standings;
  }

  GameDetail _getEmptyGameDetail(String gameId) => GameDetail(
    game: Game(
      id: gameId, status: '', shortDetail: '',
      awayTeam: TeamInfo(id: '', name: '', displayName: '', abbreviation: '', logo: '', color: '', alternateColor: '', record: ''),
      homeTeam: TeamInfo(id: '', name: '', displayName: '', abbreviation: '', logo: '', color: '', alternateColor: '', record: ''),
      awayScore: '', homeScore: '',
      awayLineScores: [], homeLineScores: [],
      venue: Venue(id: '', fullName: '', city: '', state: '', capacity: 0),
      date: '', clock: '', period: '',
    ),
    winProbabilities: [],
    boxScore: {},
    plays: [],
  );

  Future<GameDetail> getGameDetail(String gameId) async {
    for (final league in AppConstants.allLeagues) {
      final url = '${AppConstants.baseUrl}/${league['code']}/summary?event=$gameId';
      try {
        final res = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final hasContent = data['header'] != null || data['plays'] != null ||
              data['boxscore'] != null;
          if (hasContent) return _parseGameDetailEnhanced(data, gameId);
        }
      } catch (_) { continue; }
    }
    return _getEmptyGameDetail(gameId);
  }

  GameDetail _parseGameDetailEnhanced(Map<String, dynamic> data, String gameId) {
    final playsRaw = data['plays']?['plays'] ?? data['plays'] ?? [];
    final playsData = playsRaw is List ? playsRaw : [];

    final List<GoalScorer> goalScorers = [];
    for (final p in playsData) {
      final type = (p['type']?['text'] ?? '').toString().toLowerCase();
      final text = (p['text'] ?? '').toString();
      if (!type.contains('goal') && !text.toLowerCase().contains('goal') &&
          !text.toLowerCase().contains('scored')) continue;

      final goalInfo = _extractGoalInfo(text, p);
      if (goalInfo != null) {
        final isHome = _isHomeTeamGoal(text, data);
        goalScorers.add(GoalScorer(
          playerId: goalInfo['playerId'] ?? '',
          playerName: goalInfo['playerName'] ?? 'Unknown',
          minute: goalInfo['minute'] ?? 0,
          isHomeTeam: isHome,
          addedTime: (p['clock']?['displayValue'] ?? '').toString().contains('+')
              ? int.tryParse((p['clock']['displayValue'] as String).split('+').last.split("'").first)
              : null,
          assistPlayerName: _extractAssistName(text),
          isPenalty: text.toLowerCase().contains('penalty'),
          isOwnGoal: text.toLowerCase().contains('own goal'),
        ));
      }
    }

    final competition = data['gameInfo']?['competition'] ?? {};
    final homeTeamFull = (competition['competitors'] as List? ?? [])
        .firstWhere((c) => c['homeAway'] == 'home', orElse: () => {})?['team']?['displayName'] ?? '';
    final awayTeamFull = (competition['competitors'] as List? ?? [])
        .firstWhere((c) => c['homeAway'] == 'away', orElse: () => {})?['team']?['displayName'] ?? '';

    final wpData = data['winprobability'] as List? ?? [];
    final winProbs = wpData.map((wp) => WinProbability(
      gameId: gameId,
      quarter: wp['quarter'] ?? 0,
      time: wp['time'] ?? '0:00',
      awayWinPercentage: (wp['awayWinPercentage'] ?? 0.0).toDouble(),
      homeWinPercentage: (wp['homeWinPercentage'] ?? 0.0).toDouble(),
      awayScore: wp['awayScore'] ?? 0,
      homeScore: wp['homeScore'] ?? 0,
    )).toList();

    final parsedPlays = <Play>[];
    for (final p in playsData) {
      try { parsedPlays.add(Play.fromJson(p as Map<String, dynamic>)); } catch (_) {}
    }

    return GameDetail(
      game: Game(
        id: gameId, status: '', shortDetail: '',
        awayTeam: TeamInfo(id: '', name: awayTeamFull, displayName: awayTeamFull, abbreviation: '', logo: '', color: '', alternateColor: '', record: ''),
        homeTeam: TeamInfo(id: '', name: homeTeamFull, displayName: homeTeamFull, abbreviation: '', logo: '', color: '', alternateColor: '', record: ''),
        awayScore: '', homeScore: '',
        awayLineScores: [], homeLineScores: [],
        venue: Venue(id: '', fullName: '', city: '', state: '', capacity: 0),
        date: '', clock: '', period: '',
        goalScorers: goalScorers,
        awayTeamFullName: awayTeamFull,
        homeTeamFullName: homeTeamFull,
      ),
      winProbabilities: winProbs,
      boxScore: data['boxscore'] ?? {},
      plays: parsedPlays,
    );
  }

  Map<String, dynamic>? _extractGoalInfo(String text, dynamic playData) {
    final clockDisplay = playData['clock']?['displayValue']?.toString() ?? '';
    int? minute;
    if (clockDisplay.isNotEmpty) {
      final m = RegExp(r'(\d+)').firstMatch(clockDisplay);
      if (m != null) minute = int.tryParse(m.group(1)!);
    }

    String? playerName;
    final playerObj = playData['player'];
    if (playerObj != null) {
      playerName = (playerObj['displayName'] ?? playerObj['fullName'] ?? playerObj['name'])?.toString();
    }
    if (playerName == null) {
      final lower = text.toLowerCase();
      if (lower.contains('goal by')) {
        final idx = lower.indexOf('goal by') + 7;
        final rest = text.substring(idx).trim();
        final sp = rest.indexOf(' ');
        playerName = sp > 0 ? rest.substring(0, sp) : rest;
      } else if (lower.contains(' goal')) {
        final words = text.split(' ');
        for (int i = 0; i < words.length; i++) {
          if (words[i].toLowerCase() == 'goal' && i > 0) { playerName = words[i-1]; break; }
        }
      }
    }
    if (playerName != null) {
      playerName = playerName.replaceAll(RegExp(r'[^\w\s\.]'), '').trim();
      if (playerName.length > 25) playerName = playerName.substring(0, 25);
    }
    return {
      'playerId': playData['player']?['id']?.toString() ?? '',
      'playerName': playerName ?? 'Unknown',
      'minute': minute ?? 0,
    };
  }

  String? _extractAssistName(String text) {
    for (final pattern in [
      RegExp(r'assisted by\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', caseSensitive: false),
      RegExp(r'from\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', caseSensitive: false),
    ]) {
      final m = pattern.firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }

  bool _isHomeTeamGoal(String text, Map<String, dynamic> data) {
    try {
      final competitors = data['gameInfo']?['competition']?['competitors'] as List? ?? [];
      final homeName = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => {})?['team']?['displayName'] ?? '';
      final awayName = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => {})?['team']?['displayName'] ?? '';
      if (homeName.isNotEmpty && text.toLowerCase().contains(homeName.toLowerCase())) return true;
      if (awayName.isNotEmpty && text.toLowerCase().contains(awayName.toLowerCase())) return false;
    } catch (_) {}
    return false;
  }

  Future<List<TeamInfo>> getAllTeams(String leagueCode) async {
    final url = '${AppConstants.baseUrl}/$leagueCode/teams';
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final teamsData = data['sports']?[0]?['leagues']?[0]?['teams'] as List? ?? [];
        return teamsData.map<TeamInfo>((t) {
          final team = t['team'];
          return TeamInfo(
            id: team['id']?.toString() ?? '',
            name: team['name']?.toString() ?? '',
            displayName: team['displayName']?.toString() ?? '',
            abbreviation: team['abbreviation']?.toString() ?? '',
            logo: team['logo']?.toString() ?? '',
            color: '#${team['color']?.toString() ?? '000000'}',
            alternateColor: '#${team['alternateColor']?.toString() ?? 'FFFFFF'}',
            record: (team['record']?['items'] as List? ?? []).isNotEmpty
                ? (team['record']['items'].first['summary'] ?? '0-0-0').toString()
                : '0-0-0',
          );
        }).toList();
      }
    } catch (e) { print('getAllTeams: $e'); }
    return [];
  }

  Future<List<Player>> getTeamRoster(String teamId, String leagueCode) async {
    final url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId/roster';
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return (data['athletes'] as List? ?? []).map<Player>((p) => Player(
          id: p['id']?.toString() ?? '',
          fullName: p['fullName']?.toString() ?? '',
          displayName: p['displayName']?.toString() ?? '',
          headshot: p['headshot']?.toString() ?? '',
          jersey: p['jersey']?.toString() ?? '',
          position: p['position']?['abbreviation']?.toString() ?? '',
          teamId: teamId,
          teamName: p['team']?['displayName']?.toString() ?? '',
          height: p['height'] ?? 0,
          weight: p['weight'] ?? 0,
          age: p['age'] ?? 0,
          college: p['college']?['name']?.toString() ?? '',
          statistics: {},
          injuryStatus: (p['injuries'] as List? ?? []).isNotEmpty
              ? p['injuries'].first['status']?.toString() : null,
        )).toList();
      }
    } catch (e) { print('getTeamRoster: $e'); }
    return [];
  }


  // ── getMatchLineup ──────────────────────────────────────────────────────────
  // Strategy:
  //  1. Try leagues most likely to contain the game first (priority leagues +
  //     international leagues) so we hit the right summary endpoint fast.
  //  2. Parse ESPN's two roster formats:
  //       A) boxscore.players[].statistics[].athletes[]  (club competitions)
  //       B) boxscore.players[].roster[]                 (some intl / WC)
  //       C) rosters[] at root level                     (WC 2026 / summary v2)
  //  3. Deduplicate by player id so no one appears twice.
  //  4. Fall back gracefully — return whatever data we got even if partial.
  Future<MatchLineup?> getMatchLineup(String gameId) async {
    // Try all leagues, prioritising ones most likely to have the match
    final orderedLeagues = [
      ...AppConstants.internationalLeagues,
      ...AppConstants.priorityLeagues,
      ...AppConstants.majorClubCompetitions,
      ...AppConstants.backgroundLeagues,
    ];

    for (final league in orderedLeagues) {
      final url =
          '${AppConstants.baseUrl}/${league['code']}/summary?event=$gameId';
      try {
        final res = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;

        final data = json.decode(res.body) as Map<String, dynamic>;

        // Must have at least a header or boxscore to be the right endpoint
        final hasHeader   = data['header'] != null;
        final hasBoxscore = data['boxscore'] != null;
        if (!hasHeader && !hasBoxscore) continue;

        List<LineupPlayer> homePlayers = [];
        List<LineupPlayer> awayPlayers = [];
        String homeFormation = '';
        String awayFormation = '';

        // ── Path A & B: boxscore.players[] ─────────────────────────────────
        final boxscorePlayers =
            data['boxscore']?['players'] as List? ?? [];

        for (final teamData in boxscorePlayers) {
          final isHome = teamData['homeAway']?.toString() == 'home';
          final formation = teamData['formation']?.toString() ?? '';
          if (isHome && formation.isNotEmpty) homeFormation = formation;
          if (!isHome && formation.isNotEmpty) awayFormation = formation;

          // Path A: statistics[].athletes[]
          final statistics = teamData['statistics'] as List? ?? [];
          for (final group in statistics) {
            final athletes = group['athletes'] as List? ?? [];
            for (final a in athletes) {
              final p = _parseLineupAthlete(a, isHome: isHome);
              if (p != null) {
                if (isHome) homePlayers.add(p);
                else awayPlayers.add(p);
              }
            }
          }

          // Path B: roster[] (used by some ESPN soccer endpoints)
          final roster = teamData['roster'] as List? ?? [];
          for (final a in roster) {
            final p = _parseLineupAthlete(a, isHome: isHome);
            if (p != null) {
              if (isHome) homePlayers.add(p);
              else awayPlayers.add(p);
            }
          }
        }

        // ── Path C: root-level rosters[] (World Cup 2026 / summary v2) ─────
        final rootRosters = data['rosters'] as List? ?? [];
        for (final teamData in rootRosters) {
          final isHome = teamData['homeAway']?.toString() == 'home';
          final formation = teamData['formation']?.toString() ?? '';
          if (isHome && formation.isNotEmpty) homeFormation = formation;
          if (!isHome && formation.isNotEmpty) awayFormation = formation;

          final entries = teamData['roster'] as List?
              ?? teamData['athletes'] as List?
              ?? [];
          for (final a in entries) {
            final p = _parseLineupAthlete(a, isHome: isHome);
            if (p != null) {
              if (isHome) homePlayers.add(p);
              else awayPlayers.add(p);
            }
          }
        }

        // ── Deduplicate by id (keep first occurrence) ──────────────────────
        homePlayers = _dedup(homePlayers);
        awayPlayers = _dedup(awayPlayers);

        // ── Sort: starters first (GK→DEF→MID→FWD), then subs ──────────────
        homePlayers = _sortLineup(homePlayers);
        awayPlayers = _sortLineup(awayPlayers);

        if (homePlayers.isEmpty && awayPlayers.isEmpty) continue;

        return MatchLineup(
          homeFormation: homeFormation,
          awayFormation: awayFormation,
          homePlayers: homePlayers,
          awayPlayers: awayPlayers,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Parse a single athlete entry from any ESPN lineup format.
  /// Returns null if there's not enough data to build a player.
  LineupPlayer? _parseLineupAthlete(dynamic raw, {required bool isHome}) {
    if (raw == null) return null;
    final a = raw as Map<String, dynamic>;

    // ESPN wraps the athlete under 'athlete' key in statistics format,
    // but places it flat in roster format.
    final athlete = (a['athlete'] is Map)
        ? a['athlete'] as Map<String, dynamic>
        : a;

    final id = athlete['id']?.toString() ?? '';
    final fullName = athlete['displayName']?.toString()
        ?? athlete['fullName']?.toString()
        ?? athlete['shortName']?.toString()
        ?? '';
    if (fullName.isEmpty) return null;

    final shortName =
    (athlete['shortName'] ?? athlete['displayName'] ?? '').toString();
    final number = (athlete['jersey'] ?? athlete['number'] ?? '').toString();
    final posAbbr =
        athlete['position']?['abbreviation']?.toString()
            ?? athlete['position']?.toString()
            ?? '';

    // isStarter: ESPN uses 'starter', 'active', or position order
    final starter = a['starter'] == true
        || a['active'] == true
        || a['didPlay'] == true;

    // Headshot — ESPN returns it as a String URL or as a Map with 'href'/'full'
    String headshot = '';
    final rawHs = athlete['headshot'] ?? a['headshot'];
    if (rawHs is String) {
      headshot = rawHs;
    } else if (rawHs is Map) {
      headshot = (rawHs['href'] ?? rawHs['full'] ?? rawHs['default'] ?? '').toString();
    }
    // Try ESPN CDN pattern as last resort when we have an id
    if (headshot.isEmpty && id.isNotEmpty) {
      headshot =
      'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/$id.png&w=96&h=70&cb=1';
    }

    final double? rating = (a['rating'] != null)
        ? double.tryParse(a['rating'].toString())
        : null;

    return LineupPlayer(
      id: id,
      name: fullName,
      shortName: _abbreviateName(shortName),
      number: number,
      position: posAbbr,
      isStarter: starter,
      isHome: isHome,
      headshot: headshot,
      rating: rating,
    );
  }

  /// Remove duplicate players (same id) keeping the first seen.
  List<LineupPlayer> _dedup(List<LineupPlayer> players) {
    final seen = <String>{};
    return players.where((p) {
      if (p.id.isEmpty) return true; // keep anonymous
      return seen.add(p.id);
    }).toList();
  }

  /// Sort: starters first ordered GK→DEF→MID→FWD, then subs.
  List<LineupPlayer> _sortLineup(List<LineupPlayer> players) {
    int posOrder(String pos) {
      switch (pos.toUpperCase()) {
        case 'GK': return 0;
        case 'CB': case 'LB': case 'RB': case 'LWB': case 'RWB':
        case 'D': case 'DEF': return 1;
        case 'CDM': case 'CM': case 'CAM': case 'LM': case 'RM':
        case 'M': case 'MF': case 'MID': return 2;
        case 'LW': case 'RW': case 'SS': case 'ST': case 'CF':
        case 'F': case 'FW': case 'ATT': return 3;
        default: return 4;
      }
    }

    final starters = players.where((p) => p.isStarter).toList()
      ..sort((a, b) => posOrder(a.position).compareTo(posOrder(b.position)));
    final subs = players.where((p) => !p.isStarter).toList()
      ..sort((a, b) => posOrder(a.position).compareTo(posOrder(b.position)));
    return [...starters, ...subs];
  }

  String _abbreviateName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return name;
    return '${parts.first[0]}. ${parts.last}';
  }

  Future<List<NewsArticle>> getNewsBatch({
    String? league,
    int limit = 25,
  }) async {
    String url;
    if (league != null && league != 'all') {
      url = '${AppConstants.newsUrl}?sport=soccer&leagues=$league&limit=$limit';
    } else {
      url = '${AppConstants.newsUrl}?sport=soccer&limit=$limit';
    }

    print('[News] Fetching batch with limit=$limit → $url');

    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        print('[News] HTTP ${res.statusCode}');
        return [];
      }

      Map<String, dynamic> data;
      try {
        data = json.decode(res.body) as Map<String, dynamic>;
      } catch (e) {
        print('[News] JSON decode error: $e');
        return [];
      }

      List<dynamic> articles = [];

      if (data['headlines'] is List && (data['headlines'] as List).isNotEmpty) {
        articles = data['headlines'] as List;
      } else if (data['items'] is List && (data['items'] as List).isNotEmpty) {
        articles = data['items'] as List;
      } else if (data['articles'] is List && (data['articles'] as List).isNotEmpty) {
        articles = data['articles'] as List;
      } else if (data['news'] is List && (data['news'] as List).isNotEmpty) {
        articles = data['news'] as List;
      } else if (data['results'] is List && (data['results'] as List).isNotEmpty) {
        articles = data['results'] as List;
      }

      if (articles.isEmpty) {
        print('[News] No articles found in response');
        return [];
      }

      print('[News] Fetched ${articles.length} articles in batch');
      return articles.map<NewsArticle>((a) => _parseNewsArticle(a)).toList();
    } catch (e) {
      print('[News] Error fetching batch: $e');
      return [];
    }
  }

  NewsArticle _parseNewsArticle(Map<String, dynamic> a) {
    String imageUrl = '';
    String imageCaption = '';
    final imagesList = a['images'] as List? ?? [];
    if (imagesList.isNotEmpty) {
      Map<String, dynamic>? best;
      for (final img in imagesList) {
        final imgMap = img as Map<String, dynamic>;
        final name = (imgMap['name'] ?? '').toString().toLowerCase();
        final caption = (imgMap['caption'] ?? imgMap['title'] ?? '').toString();
        if (name.contains('header') || name.contains('feature') || name.contains('story')) {
          best = imgMap;
          imageCaption = caption;
          break;
        }
      }
      if (best == null) {
        int maxWidth = -1;
        for (final img in imagesList) {
          final imgMap = img as Map<String, dynamic>;
          final w = (imgMap['width'] as num?)?.toInt() ?? 0;
          if (w > maxWidth) { maxWidth = w; best = imgMap; }
        }
        if (best != null) {
          imageCaption = (best['caption'] ?? best['title'] ?? '').toString();
        }
      }
      if (best != null) {
        imageUrl = best['url']?.toString() ?? best['href']?.toString() ?? '';
      }
    } else if (a['image'] is Map) {
      imageUrl = (a['image'] as Map)['url']?.toString() ?? '';
    }

    String author = 'ESPN';
    if (a['byline'] != null && a['byline'].toString().isNotEmpty) {
      author = a['byline'].toString();
    } else if (a['author'] is Map) {
      final auth = a['author'] as Map;
      author = auth['displayName']?.toString()
          ?? auth['fullName']?.toString()
          ?? auth['name']?.toString()
          ?? 'ESPN';
    }

    List<String> categories = [];
    if (a['categories'] is List) {
      for (final c in a['categories'] as List) {
        if (c is Map) {
          final name = c['description']?.toString()
              ?? c['name']?.toString()
              ?? c['displayName']?.toString();
          if (name != null && name.isNotEmpty) categories.add(name);
        } else {
          categories.add(c.toString());
        }
      }
    }
    categories = categories.take(3).toList();

    String? videoUrl;
    if (a['links'] is Map) {
      final links = a['links'] as Map;
      videoUrl = (links['source'] is Map ? links['source']['href']?.toString() : null)
          ?? (links['video'] is Map ? links['video']['href']?.toString() : null);
    }
    if (videoUrl == null && a['video'] is Map) {
      videoUrl = (a['video'] as Map)['url']?.toString();
    }

    String? webUrl;
    if (a['links'] is Map) {
      final links = a['links'] as Map;
      webUrl = (links['web'] is Map ? links['web']['href']?.toString() : null)
          ?? (links['mobile'] is Map ? links['mobile']['href']?.toString() : null)
          ?? (links['app'] is Map ? links['app']['href']?.toString() : null);
    }

    if (webUrl != null && !webUrl.startsWith('http')) {
      webUrl = 'https://$webUrl';
    }

    final publishedAt = (a['published'] ?? a['date'] ?? a['pubDate'] ?? a['createdAt'] ?? '').toString();
    final description = (a['description'] ?? a['summary'] ?? a['abstract'] ?? '').toString();
    final body = (a['body'] ?? a['content'] ?? a['story'] ?? '').toString();
    final type = (a['type'] ?? 'story').toString().toLowerCase();

    return NewsArticle(
      id: a['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      headline: a['headline']?.toString() ?? a['title']?.toString() ?? 'Football News',
      description: description,
      body: body,
      imageUrl: imageUrl,
      imageCaption: imageCaption,
      publishedAt: publishedAt,
      author: author,
      categories: categories,
      videoUrl: videoUrl,
      webUrl: webUrl,
      articleType: type,
      links: a['links'] as Map<String, dynamic>?,
    );
  }

  Future<List<NewsArticle>> getNews({String? league}) async {
    final firstBatch = await getNewsBatch(league: league, limit: 25);
    return firstBatch;
  }

  Future<List<H2HResult>> getH2H(
      String awayTeamId,
      String homeTeamId,
      String currentGameId,
      String leagueCode,
      ) async {
    try {
      final url = '${AppConstants.baseUrl}/$leagueCode/teams/$awayTeamId/schedule';
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body) as Map<String, dynamic>;
      final events = data['events'] as List? ?? [];
      final List<H2HResult> results = [];

      for (final event in events) {
        if (event['id']?.toString() == currentGameId) continue;
        final competition = (event['competitions'] as List?)?.first;
        if (competition == null) continue;

        final competitors = competition['competitors'] as List? ?? [];
        if (competitors.length < 2) continue;

        String? awayId, homeId, awayScore, homeScore;
        String? awayName, homeName;

        for (final c in competitors) {
          final tId = c['team']?['id']?.toString() ?? '';
          final ha  = c['homeAway']?.toString();
          if (ha == 'away') {
            awayId    = tId;
            awayScore = c['score']?.toString() ?? '0';
            awayName  = c['team']?['displayName']?.toString()
                ?? c['team']?['name']?.toString()
                ?? c['team']?['abbreviation']?.toString() ?? '';
          } else {
            homeId    = tId;
            homeScore = c['score']?.toString() ?? '0';
            homeName  = c['team']?['displayName']?.toString()
                ?? c['team']?['name']?.toString()
                ?? c['team']?['abbreviation']?.toString() ?? '';
          }
        }

        final isH2H = (awayId == awayTeamId || awayId == homeTeamId) &&
            (homeId == awayTeamId || homeId == homeTeamId);
        if (!isH2H) continue;

        final rawStatus = event['status']?['type']?['description']?.toString() ?? '';
        if (!rawStatus.toLowerCase().contains('final') &&
            !rawStatus.toLowerCase().contains('ft') &&
            !rawStatus.toLowerCase().contains('finish')) continue;

        final aGoals = int.tryParse(awayScore ?? '0') ?? 0;
        final hGoals = int.tryParse(homeScore ?? '0') ?? 0;

        String result;
        if (aGoals == hGoals) result = 'draw';
        else if (aGoals > hGoals) result = 'away_win';
        else result = 'home_win';

        results.add(H2HResult(
          date: event['date']?.toString() ?? '',
          homeTeam: homeName ?? homeId ?? '',
          awayTeam: awayName ?? awayId ?? '',
          homeScore: homeScore ?? '0',
          awayScore: awayScore ?? '0',
          result: result,
        ));

        if (results.length >= 5) break;
      }

      return results;
    } catch (e) {
      print('getH2H error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TEAM PAGE DATA METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<TeamPageData> getTeamPageData(
      String teamId, {
        String? leagueCode,
      }) async {
    print('[TeamPage] ▶ getTeamPageData called: teamId=$teamId leagueCode=$leagueCode');

    final resolvedLeague = leagueCode ?? await _detectTeamLeague(teamId);
    print('[TeamPage] Resolved league: $resolvedLeague');

    // ── National team path: World Cup or other international ──────────────────
    if (AppConstants.isNationalTeamLeague(resolvedLeague)) {
      return _getTeamPageDataNational(teamId, resolvedLeague);
    }

    // ── Club team path (unchanged) ─────────────────────────────────────────────
    final results = await Future.wait([
      _fetchTeamSchedule(teamId, resolvedLeague),
      _fetchTeamRosterFull(teamId, resolvedLeague),
      _fetchTeamStandingInfo(teamId, resolvedLeague),
    ]);

    _ScheduleResult scheduleData = results[0] as _ScheduleResult;
    final rawSquadPlayers = results[1] as List<TeamSquadPlayer>;
    final standingInfo = results[2] as TeamStandingInfo;

    // Enrich headshots: tries sports.core.api → site.web.api → site.api in order
    final squadPlayers = await _enrichRosterHeadshots(rawSquadPlayers, resolvedLeague);

    if (scheduleData.upcoming.isEmpty) {
      print('[TeamPage] No upcoming fixtures — trying next season schedule');
      final nextYear = DateTime.now().year + 1;
      final nextSeasonSchedule = await _fetchTeamScheduleForYear(
          teamId, resolvedLeague, nextYear);
      if (nextSeasonSchedule.upcoming.isNotEmpty) {
        scheduleData = _ScheduleResult(
          recentMatches: scheduleData.recentMatches,
          upcoming: nextSeasonSchedule.upcoming,
          headCoach: scheduleData.headCoach ?? nextSeasonSchedule.headCoach,
          recentMatchEventIds: scheduleData.recentMatchEventIds,
        );
      }
    }

    print('[TeamPage] Schedule: ${scheduleData.recentMatches.length} recent, ${scheduleData.upcoming.length} upcoming');
    print('[TeamPage] Squad: ${squadPlayers.length} players');
    print('[TeamPage] Standing: rank=${standingInfo.rank}, pts=${standingInfo.points}');

    final enrichedMatches = await _enrichMatchesWithSummaryStats(
      scheduleData.recentMatches,
      scheduleData.recentMatchEventIds,
      teamId,
      resolvedLeague,
    );

    final analytics = _calculateAnalytics(enrichedMatches, squadPlayers);

    return TeamPageData(
      leagueCode: resolvedLeague,
      standingInfo: standingInfo,
      recentMatches: enrichedMatches,
      upcoming: scheduleData.upcoming,
      squad: squadPlayers,
      analytics: analytics,
      headCoach: scheduleData.headCoach,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // NATIONAL TEAM DATA (World Cup 2026 + International fallback)
  // ══════════════════════════════════════════════════════════════════════════════

  /// Builds a full [TeamPageData] for a national team.
  ///
  /// Strategy:
  /// 1. Fetch schedule from `fifa.world` (WC) or the passed international league.
  /// 2. If recent matches < 3, supplement from international qualifier/nations
  ///    leagues so the user always sees up to 5 real results.
  /// 3. Squad always pulled from the primary league, with fallback.
  /// 4. WC Group standings pulled from `fifa.world`.
  Future<TeamPageData> _getTeamPageDataNational(
      String teamId, String leagueCode) async {
    print('[NationalTeam] ▶ _getTeamPageDataNational teamId=$teamId league=$leagueCode');

    final primaryLeague = AppConstants.isWorldCup(leagueCode) ? 'fifa.world' : leagueCode;

    final results = await Future.wait([
      _fetchTeamSchedule(teamId, primaryLeague),
      _fetchTeamRosterFull(teamId, primaryLeague),
      _fetchTeamStandingInfo(teamId, primaryLeague),
    ]);

    _ScheduleResult scheduleData = results[0] as _ScheduleResult;
    final squadPlayers = results[1] as List<TeamSquadPlayer>;
    final standingInfo = results[2] as TeamStandingInfo;

    print('[NationalTeam] Primary schedule: ${scheduleData.recentMatches.length} recent, ${scheduleData.upcoming.length} upcoming');

    // ── Fallback: supplement recent matches from other international competitions ──
    if (scheduleData.recentMatches.length < 3) {
      print('[NationalTeam] Supplementing with international fallback matches');
      final fallback = await _fetchNationalTeamFallbackMatches(
        teamId,
        existing: scheduleData.recentMatches,
        existingIds: scheduleData.recentMatchEventIds,
        targetCount: 5,
      );

      if (fallback.recentMatches.isNotEmpty) {
        final combined = [...scheduleData.recentMatches, ...fallback.recentMatches];
        final combinedIds = [...scheduleData.recentMatchEventIds, ...fallback.recentMatchEventIds];
        final sortedPairs = List.generate(combined.length, (i) => [combined[i], combinedIds[i]])
          ..sort((a, b) =>
              (b[0] as TeamRecentMatch).date.compareTo((a[0] as TeamRecentMatch).date));
        scheduleData = _ScheduleResult(
          recentMatches: sortedPairs.take(5).map((p) => p[0] as TeamRecentMatch).toList(),
          upcoming: scheduleData.upcoming.isNotEmpty ? scheduleData.upcoming : fallback.upcoming,
          headCoach: scheduleData.headCoach ?? fallback.headCoach,
          recentMatchEventIds: sortedPairs.take(5).map((p) => p[1] as String).toList(),
        );
        print('[NationalTeam] After fallback: ${scheduleData.recentMatches.length} recent');
      }
    }

    // ── Try next season fixtures if none found ────────────────────────────────
    if (scheduleData.upcoming.isEmpty) {
      final nextYear = DateTime.now().year + 1;
      final nextSchedule = await _fetchTeamScheduleForYear(teamId, primaryLeague, nextYear);
      if (nextSchedule.upcoming.isNotEmpty) {
        scheduleData = _ScheduleResult(
          recentMatches: scheduleData.recentMatches,
          upcoming: nextSchedule.upcoming,
          headCoach: scheduleData.headCoach ?? nextSchedule.headCoach,
          recentMatchEventIds: scheduleData.recentMatchEventIds,
        );
      }
    }

    // ── Squad fallback ────────────────────────────────────────────────────────
    List<TeamSquadPlayer> finalSquad = squadPlayers;
    if (finalSquad.isEmpty && leagueCode != primaryLeague) {
      finalSquad = await _fetchTeamRosterFull(teamId, leagueCode);
    }

    // Enrich headshots: tries sports.core.api → site.web.api → site.api in order
    finalSquad = await _enrichRosterHeadshots(finalSquad, primaryLeague);

    final enrichedMatches = await _enrichMatchesWithSummaryStats(
      scheduleData.recentMatches,
      scheduleData.recentMatchEventIds,
      teamId,
      primaryLeague,
    );

    final analytics = _calculateAnalytics(enrichedMatches, finalSquad);

    return TeamPageData(
      leagueCode: primaryLeague,
      standingInfo: standingInfo,
      recentMatches: enrichedMatches,
      upcoming: scheduleData.upcoming,
      squad: finalSquad,
      analytics: analytics,
      headCoach: scheduleData.headCoach,
    );
  }

  /// Scans [AppConstants.internationalFallbackLeagues] for up to [targetCount]
  /// recent completed matches for [teamId] not already in [existing].
  Future<_ScheduleResult> _fetchNationalTeamFallbackMatches(
      String teamId, {
        required List<TeamRecentMatch> existing,
        required List<String> existingIds,
        int targetCount = 5,
      }) async {
    final needed = targetCount - existing.length;
    if (needed <= 0) return _ScheduleResult.empty();

    final allRecent = <TeamRecentMatch>[];
    final allIds = <String>[];
    final allUpcoming = <TeamUpcomingFixture>[];
    String? headCoach;

    for (final fallbackCode in AppConstants.internationalFallbackLeagues) {
      if (allRecent.length >= needed) break;
      try {
        final result = await _fetchTeamSchedule(teamId, fallbackCode);
        allRecent.addAll(result.recentMatches);
        allIds.addAll(result.recentMatchEventIds);
        if (allUpcoming.isEmpty) allUpcoming.addAll(result.upcoming);
        headCoach ??= result.headCoach;
      } catch (_) {}
    }

    return _ScheduleResult(
      recentMatches: allRecent,
      upcoming: allUpcoming,
      headCoach: headCoach,
      recentMatchEventIds: allIds,
    );
  }

  Future<_ScheduleResult> _fetchTeamScheduleForYear(
      String teamId, String leagueCode, int year) async {
    final url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId/schedule?season=$year';
    print('[TeamPage] Fetching next-season schedule: $url');
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _ScheduleResult.empty();
      return _parseTeamSchedule(
          json.decode(res.body) as Map<String, dynamic>, leagueCode, teamId);
    } catch (e) {
      print('[TeamPage] Next-season schedule error: $e');
      return _ScheduleResult.empty();
    }
  }

  Future<List<TeamRecentMatch>> _enrichMatchesWithSummaryStats(
      List<TeamRecentMatch> matches,
      List<String> eventIds,
      String teamId,
      String leagueCode,
      ) async {
    if (matches.isEmpty) return matches;

    final futures = List.generate(matches.length, (i) async {
      final eventId = i < eventIds.length ? eventIds[i] : '';
      if (eventId.isEmpty) return matches[i];
      try {
        final leaguesToTry = [
          leagueCode,
          if (leagueCode != 'eng.1') 'eng.1',
          if (leagueCode != 'uefa.champions') 'uefa.champions',
        ];
        for (final lc in leaguesToTry) {
          final url = '${AppConstants.baseUrl}/$lc/summary?event=$eventId';
          try {
            final res = await _client
                .get(Uri.parse(url), headers: _headers)
                .timeout(const Duration(seconds: 6));
            if (res.statusCode == 200) {
              final data = json.decode(res.body) as Map<String, dynamic>;
              return _applyMatchSummaryStats(matches[i], data, teamId);
            }
          } catch (_) {}
        }
        return matches[i];
      } catch (e) {
        print('[TeamPage] Summary fetch error for event $eventId: $e');
        return matches[i];
      }
    });

    return await Future.wait(futures);
  }

  TeamRecentMatch _applyMatchSummaryStats(
      TeamRecentMatch match,
      Map<String, dynamic> summary,
      String teamId,
      ) {
    double? poss = match.possession;
    double? shots = match.shots;
    double? sot = match.shotsOnTarget;
    int yc = match.yellowCards;
    int rc = match.redCards;

    int goalsFor = match.goalsFor;
    int goalsAgainst = match.goalsAgainst;
    String score = match.score;
    String result = match.result;
    bool scoreFixed = false;

    try {
      if (goalsFor == 0 && goalsAgainst == 0) {
        final header = summary['header'] as Map<String, dynamic>?;
        final comps = header?['competitions'] as List?;
        if (comps != null && comps.isNotEmpty) {
          final comp = comps.first as Map<String, dynamic>;
          final compCompetitors = comp['competitors'] as List? ?? [];
          for (final c in compCompetitors) {
            final cTeamId = c['team']?['id']?.toString() ?? '';
            final cScore = int.tryParse(c['score']?.toString() ?? '0') ?? 0;
            if (cTeamId == teamId) {
              goalsFor = cScore;
              scoreFixed = true;
            } else if (scoreFixed || compCompetitors.length == 2) {
              goalsAgainst = cScore;
            }
          }
          if (scoreFixed) {
            if (goalsFor > goalsAgainst) result = 'win';
            else if (goalsFor < goalsAgainst) result = 'loss';
            else result = 'draw';
            score = '$goalsFor-$goalsAgainst';
            print('[TeamPage] Score fixed from summary: $score ($result)');
          }
        }
      }

      if (yc == 0 && rc == 0) {
        final plays = summary['keyPlays'] as List? ??
            summary['keyEvents'] as List? ?? [];
        for (final play in plays) {
          final typeText = (play['type']?['text'] ?? '').toString().toLowerCase();
          final teamRef = play['team']?['id']?.toString() ?? '';
          if (teamRef != teamId) continue;
          if (typeText.contains('yellow')) yc++;
          if (typeText.contains('red card')) rc++;
        }
      }

      final boxScore = summary['boxScore'] as Map<String, dynamic>?;
      final teamStats = boxScore?['teams'] as List?;
      if (teamStats != null) {
        for (final ts in teamStats) {
          final tsTeamId = ts['team']?['id']?.toString() ?? '';
          if (tsTeamId != teamId) continue;
          final statList = ts['statistics'] as List? ?? [];
          for (final stat in statList) {
            final rawName = (stat['name'] ?? '').toString();
            final rawAbbr = (stat['abbreviation'] ?? '').toString();
            final name = rawName.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
            final abbr = rawAbbr.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
            final rawVal = (stat['displayValue'] ?? '').toString();
            final val = double.tryParse(rawVal.replaceAll('%', '').trim());
            if (val == null) continue;
            if ((name.contains('possession') || abbr == 'poss') && poss == null) poss = val;
            if (shots == null && (name == 'shots' || name == 'totalshots' ||
                name == 'shotsattempted' || abbr == 'sh' || abbr == 'shots')) shots = val;
            if (sot == null && (name == 'shotsontarget' || name == 'ontarget' ||
                name == 'shotson' || name == 'targettotal' ||
                abbr == 'sot' || abbr == 'st' || abbr == 'ontarget' || abbr == 'sog')) sot = val;
            if (name.contains('yellow') && yc == 0) yc = val.toInt();
            if ((name == 'redcards' || name == 'red' || abbr == 'rc') && rc == 0) rc = val.toInt();
          }
        }
      }

      final directStats = summary['statistics'] as List?;
      if (directStats != null) {
        for (final ts in directStats) {
          if (ts is! Map) continue;
          final tsId = ts['team']?['id']?.toString() ?? ts['id']?.toString() ?? '';
          if (tsId != teamId && tsId.isNotEmpty) continue;
          for (final stat in (ts['stats'] as List? ?? ts['statistics'] as List? ?? [])) {
            final name = (stat['name'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
            final abbr = (stat['abbreviation'] ?? '').toString().toLowerCase();
            final val = double.tryParse((stat['displayValue'] ?? stat['value'] ?? '').toString().replaceAll('%', '').trim());
            if (val == null) continue;
            if ((name.contains('possession') || abbr == 'poss') && poss == null) poss = val;
            if (shots == null && (name == 'shots' || name == 'totalshots' || abbr == 'sh')) shots = val;
            if (sot == null && (name == 'shotsontarget' || name == 'ontarget' || abbr == 'sot' || abbr == 'sog' || abbr == 'st')) sot = val;
          }
        }
      }

      if (poss == null || shots == null) {
        final header = summary['header'] as Map<String, dynamic>?;
        final competitions = header?['competitions'] as List?;
        if (competitions != null && competitions.isNotEmpty) {
          final comp = competitions.first as Map<String, dynamic>;
          final compStats = comp['statistics'] as List? ?? comp['stats'] as List? ?? [];
          for (final stat in compStats) {
            final name = (stat['name'] ?? '').toString().toLowerCase();
            final val = double.tryParse(
                (stat['displayValue'] ?? stat['value'] ?? '').toString().replaceAll('%', ''));
            if (val == null) continue;
            if (name.contains('possession') && poss == null) poss = val;
            if (name == 'shots' && shots == null) shots = val;
            if ((name.contains('shotsontarget') || name.contains('shots on target') || name == 'sot' || name.contains('on target') || name == 'ontarget') && sot == null) sot = val;
          }
        }
      }

      if (poss == null) {
        final drives = summary['drives'] as Map<String, dynamic>?;
        if (drives != null) {
          final homePoss = drives['homeTeamHasBall'];
          if (homePoss is num) {
            poss = match.isHome ? homePoss.toDouble() : 100 - homePoss.toDouble();
          }
        }
      }
    } catch (e) {
      print('[TeamPage] Summary stat extraction error: $e');
    }

    if (!scoreFixed &&
        poss == match.possession && shots == match.shots &&
        sot == match.shotsOnTarget && yc == match.yellowCards &&
        rc == match.redCards) {
      return match;
    }

    return TeamRecentMatch(
      opponentId: match.opponentId,
      opponentName: match.opponentName,
      opponentLogo: match.opponentLogo,
      opponentAbbr: match.opponentAbbr,
      score: score,
      result: result,
      date: match.date,
      competition: match.competition,
      leagueFlag: match.leagueFlag,
      isHome: match.isHome,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      yellowCards: yc,
      redCards: rc,
      possession: poss,
      shots: shots,
      shotsOnTarget: sot,
    );
  }

  Future<String> _detectTeamLeague(String teamId) async {
    final quickLeagues = AppConstants.priorityLeagues.take(8).toList();
    for (final league in quickLeagues) {
      final code = league['code']!;
      final url = '${AppConstants.baseUrl}/$code/teams/$teamId';
      try {
        final res = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          print('[TeamPage] Detected league: $code for team $teamId');
          return code;
        }
      } catch (_) {}
    }
    print('[TeamPage] Could not detect league, defaulting to eng.1');
    return 'eng.1';
  }

  Future<_ScheduleResult> _fetchTeamSchedule(
      String teamId, String leagueCode) async {
    final url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId/schedule';
    print('[TeamPage] Fetching schedule: $url');
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      print('[TeamPage] Schedule HTTP ${res.statusCode}');
      if (res.statusCode != 200) return _ScheduleResult.empty();
      return _parseTeamSchedule(
          json.decode(res.body) as Map<String, dynamic>, leagueCode, teamId);
    } catch (e) {
      print('[TeamPage] Schedule error: $e');
      return _ScheduleResult.empty();
    }
  }

  _ScheduleResult _parseTeamSchedule(
      Map<String, dynamic> data, String leagueCode, String teamId) {
    final events = data['events'] as List? ?? [];
    print('[TeamPage] Total events in schedule: ${events.length}');
    final now = DateTime.now();

    final List<TeamRecentMatch> allRecent = [];
    final List<String> allRecentEventIds = [];
    final List<TeamUpcomingFixture> upcoming = [];

    String? headCoach;
    final coaches = data['coach'] as List?;
    if (coaches != null && coaches.isNotEmpty) {
      headCoach = coaches.first?['displayName']?.toString();
    }

    final leagueEntry = AppConstants.allLeagues.firstWhere(
          (l) => l['code'] == leagueCode,
      orElse: () => {'name': leagueCode, 'flag': '⚽'},
    );

    for (final event in events) {
      try {
        final competition =
        (event['competitions'] as List?)?.first as Map<String, dynamic>?;
        if (competition == null) continue;
        final competitors = competition['competitors'] as List? ?? [];
        if (competitors.length < 2) continue;

        Map<String, dynamic>? myData, oppData;
        for (final c in competitors) {
          final tid = c['team']?['id']?.toString() ?? '';
          if (tid == teamId) {
            myData = c as Map<String, dynamic>;
          } else {
            oppData = c as Map<String, dynamic>;
          }
        }

        if (myData == null || oppData == null) {
          if (competitors.length >= 2) {
            final eventName = (event['name'] ?? event['shortName'] ?? '').toString();
            for (final c in competitors) {
              final tAbbr = c['team']?['abbreviation']?.toString() ?? '';
              final tName = c['team']?['name']?.toString() ?? '';
              if (eventName.contains(tAbbr) || eventName.contains(tName)) {
                myData ??= c as Map<String, dynamic>;
              } else {
                oppData ??= c as Map<String, dynamic>;
              }
            }
          }
          if (myData == null || oppData == null) continue;
        }

        final normStatus = _normalizeEventStatus(event);
        final isHome = myData['homeAway']?.toString() == 'home';

        if (allRecent.length + upcoming.length < 3) {
          final cs = (event['competitions'] as List?)?.isNotEmpty == true
              ? (event['competitions'] as List).first['status'] : null;
          final es = event['status'];
          final dbgState = cs?['type']?['state'] ?? cs?['state'] ?? es?['type']?['state'] ?? '?';
          final dbgDesc = cs?['type']?['description'] ?? cs?['description'] ?? es?['type']?['description'] ?? '?';
          final dbgComp = cs?['type']?['completed'] ?? cs?['completed'] ?? es?['type']?['completed'] ?? '?';
          print('[TeamPage] Event status — compState=$dbgState desc=$dbgDesc completed=$dbgComp → $normStatus');
        }

        final oppTeam = oppData['team'] as Map<String, dynamic>? ?? {};
        final oppId = oppTeam['id']?.toString() ?? '';
        final oppName = oppTeam['displayName']?.toString() ??
            oppTeam['name']?.toString() ?? 'Unknown';
        final oppAbbr = oppTeam['abbreviation']?.toString() ?? '';

        String oppLogo = oppTeam['logo']?.toString() ?? '';
        if (oppLogo.isEmpty && oppId.isNotEmpty) {
          oppLogo = 'https://a.espncdn.com/i/teamlogos/soccer/500/$oppId.png';
        }

        final eventDate =
            DateTime.tryParse(event['date']?.toString() ?? '') ?? now;

        String compName = leagueEntry['name'] ?? leagueCode;
        String compFlag = leagueEntry['flag'] ?? '⚽';
        final evLeagueName = competition['league']?['name']?.toString() ??
            competition['tournament']?['name']?.toString();
        if (evLeagueName != null && evLeagueName.isNotEmpty) {
          compName = evLeagueName;
          final matchedLeague = AppConstants.allLeagues.firstWhere(
                (l) => (l['name'] ?? '').toLowerCase() == evLeagueName.toLowerCase(),
            orElse: () => const {},
          );
          if (matchedLeague.isNotEmpty) {
            compFlag = matchedLeague['flag'] ?? compFlag;
          }
        }

        if (normStatus == 'STATUS_FINAL') {
          int myScore = 0;
          int oppScore = 0;

          final myScoreRaw = myData['score'];
          final oppScoreRaw = oppData['score'];

          if (myScoreRaw is Map) {
            myScore = int.tryParse(myScoreRaw['displayValue']?.toString() ?? '0') ?? 0;
          } else {
            myScore = int.tryParse(myScoreRaw?.toString() ?? '0') ?? 0;
          }

          if (oppScoreRaw is Map) {
            oppScore = int.tryParse(oppScoreRaw['displayValue']?.toString() ?? '0') ?? 0;
          } else {
            oppScore = int.tryParse(oppScoreRaw?.toString() ?? '0') ?? 0;
          }

          if (myScore == 0 && oppScore == 0) {
            final compScores = competition['score']?.toString() ?? '';
            if (compScores.contains('-')) {
              final parts = compScores.split('-');
              if (parts.length == 2) {
                final s1 = int.tryParse(parts[0].trim()) ?? 0;
                final s2 = int.tryParse(parts[1].trim()) ?? 0;
                myScore = isHome ? s1 : s2;
                oppScore = isHome ? s2 : s1;
              }
            }
          }

          if (myScore == 0 && oppScore == 0) {
            final myLines = myData['linescores'] as List? ?? [];
            final oppLines = oppData['linescores'] as List? ?? [];
            if (myLines.isNotEmpty) {
              myScore = myLines.fold<int>(0, (sum, ls) =>
              sum + (int.tryParse(ls['value']?.toString() ?? '0') ?? 0));
              oppScore = oppLines.fold<int>(0, (sum, ls) =>
              sum + (int.tryParse(ls['value']?.toString() ?? '0') ?? 0));
            }
          }

          String result;
          if (myScore > oppScore) result = 'win';
          else if (myScore < oppScore) result = 'loss';
          else result = 'draw';

          int yc = 0, rc = 0;
          double? poss, shots, sot;
          try {
            final details = competition['details'] as List? ?? [];
            for (final d in details) {
              final t = (d['type']?['text'] ?? '').toString().toLowerCase();
              final tid = d['team']?['id']?.toString() ?? '';
              if (tid != teamId) continue;
              if (t.contains('yellow')) yc++;
              if (t.contains('red card')) rc++;
            }

            final compBoxTeams = competition['boxScore']?['teams'] as List? ?? [];
            for (final ts in compBoxTeams) {
              if (ts['team']?['id']?.toString() != teamId) continue;
              for (final stat in (ts['statistics'] as List? ?? [])) {
                final n = (stat['name'] ?? '').toString().toLowerCase();
                final v = double.tryParse(
                    stat['displayValue']?.toString().replaceAll('%', '') ?? '');
                if (v == null) continue;
                if (n.contains('possession')) poss ??= v;
                if (n == 'shots' || n == 'totalshots' || n == 'shotsattempted') shots ??= v;
                if (n.contains('shotsontarget') || n.contains('shots on target') || n == 'sot' || n.contains('on target') || n == 'ontarget') sot ??= v;
                if (n.contains('yellow') && yc == 0) yc = v.toInt();
                if (n.contains('red') && rc == 0) rc = v.toInt();
              }
            }

            for (final c in [myData, oppData]) {
              if (c == null) continue;
              final isMyTeam = c['team']?['id']?.toString() == teamId;
              final cStats = c['statistics'] as List? ?? [];
              for (final stat in cStats) {
                final n = (stat['name'] ?? stat['abbreviation'] ?? '').toString().toLowerCase();
                final v = double.tryParse(
                    stat['displayValue']?.toString().replaceAll('%', '') ?? '');
                if (v == null || !isMyTeam) continue;
                if (n.contains('poss')) poss ??= v;
                if (n == 'sh' || n == 'shots') shots ??= v;
                if (n == 'sot' || n.contains('on target') || n == 'ontarget' || n.contains('shotsontarget')) sot ??= v;
              }
            }
          } catch (_) {}

          allRecent.add(TeamRecentMatch(
            opponentId: oppId,
            opponentName: oppName,
            opponentLogo: oppLogo,
            opponentAbbr: oppAbbr,
            score: '$myScore-$oppScore',
            result: result,
            date: event['date']?.toString() ?? '',
            competition: compName,
            leagueFlag: compFlag,
            isHome: isHome,
            goalsFor: myScore,
            goalsAgainst: oppScore,
            yellowCards: yc,
            redCards: rc,
            possession: poss,
            shots: shots,
            shotsOnTarget: sot,
          ));
          allRecentEventIds.add(event['id']?.toString() ?? '');
        } else if (normStatus == 'STATUS_SCHEDULED' && eventDate.isAfter(now)) {
          upcoming.add(TeamUpcomingFixture(
            opponentId: oppId,
            opponentName: oppName,
            opponentLogo: oppLogo,
            opponentAbbr: oppAbbr,
            competition: compName,
            leagueFlag: compFlag,
            date: event['date']?.toString() ?? '',
            isHome: isHome,
          ));
        }
      } catch (e) {
        print('[TeamPage] Event parse error: $e');
      }
    }

    final sortedPairs =
    List.generate(allRecent.length, (i) => [allRecent[i], allRecentEventIds[i]])
      ..sort((a, b) =>
          (b[0] as TeamRecentMatch).date.compareTo((a[0] as TeamRecentMatch).date));
    final recent = sortedPairs.take(5).map((p) => p[0] as TeamRecentMatch).toList();
    final recentIds = sortedPairs.take(5).map((p) => p[1] as String).toList();

    upcoming.sort((a, b) => a.date.compareTo(b.date));
    final upcomingFinal = upcoming.take(5).toList();

    print('[TeamPage] Parsed: ${recent.length} recent matches '
        '(from ${allRecent.length} total), ${upcomingFinal.length} upcoming');

    return _ScheduleResult(
      recentMatches: recent,
      upcoming: upcomingFinal,
      headCoach: headCoach,
      recentMatchEventIds: recentIds,
    );
  }

  Future<List<TeamSquadPlayer>> _fetchTeamRosterFull(
      String teamId, String leagueCode) async {
    final url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId/roster';
    print('[TeamPage] Fetching roster: $url');
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      print('[TeamPage] Roster HTTP ${res.statusCode}');
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body) as Map<String, dynamic>;
      final raw = data['athletes'];
      final List<Map<String, dynamic>> athletes = [];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map && item['items'] is List) {
            for (final a in item['items'] as List) {
              if (a is Map) {
                athletes.add(Map<String, dynamic>.from(a));
              }
            }
          } else if (item is Map) {
            athletes.add(Map<String, dynamic>.from(item));
          }
        }
      }

      print('[TeamPage] Total athletes in roster: ${athletes.length}');

      final List<TeamSquadPlayer> players = [];
      for (final a in athletes) {
        // ── Extract player ID ─────────────────────────────────────────────────
        // Handles two roster formats ESPN returns:
        //   Format A (inline): a = { "id": "726742", "displayName": "...", ... }
        //   Format B ($ref):   a = { "$ref": "https://sports.core.api.../athletes/726742" }
        String playerId = a['id']?.toString() ?? '';

        if (playerId.isEmpty) {
          // Try to extract ID from $ref URL
          final ref = a['\$ref']?.toString() ?? '';
          if (ref.isNotEmpty) {
            // e.g. "https://sports.core.api.espn.com/v2/sports/soccer/leagues/eng.1/athletes/726742"
            final match = RegExp(r'/athletes/(\d+)').firstMatch(ref);
            if (match != null) playerId = match.group(1)!;
          }
        }

        if (playerId.isEmpty) continue; // Skip entries with no resolvable ID

        // ── Extract headshot URL ──────────────────────────────────────────────
        // ESPN's site roster API rarely fills `headshot` for soccer, but it
        // consistently provides photo URLs inside `links[]`.
        // Priority order:
        //   1. links[] where rel contains "photo" or "headshot"
        //   2. inline headshot.href / headshot (string)
        //   3. CDN fallback by player ID (widget will try multiple patterns)
        String headshot = '';

        // 1. links[] — most reliable source from the site API
        final links = a['links'] as List? ?? [];
        for (final link in links) {
          if (link is! Map) continue;
          final rels = (link['rel'] as List? ?? [])
              .map((r) => r.toString().toLowerCase())
              .toList();
          // Match any link tagged as photo/headshot/athlete-image
          if (rels.contains('photo') ||
              rels.contains('headshot') ||
              rels.contains('athlete-headshot') ||
              (rels.contains('athlete') && rels.contains('desktop')) ||
              (rels.contains('athlete') && rels.contains('image'))) {
            headshot = link['href']?.toString() ?? '';
            if (headshot.isNotEmpty) break;
          }
        }

        // 2. Inline headshot field (string URL or map)
        if (headshot.isEmpty) {
          final hs = a['headshot'];
          if (hs is String && hs.isNotEmpty) {
            headshot = hs;
          } else if (hs is Map) {
            headshot = hs['href']?.toString() ?? '';
            if (headshot.isEmpty) {
              // $ref — extract player ID from the ref URL to build CDN URL
              final hsRef = hs['\$ref']?.toString() ?? '';
              if (hsRef.isNotEmpty) {
                final m = RegExp(r'/athletes/(\d+)').firstMatch(hsRef);
                if (m != null) playerId = m.group(1)!;
              }
            }
            if (headshot.isEmpty) {
              headshot = hs['full']?.toString() ?? hs['default']?.toString() ?? '';
            }
          }
        }

        // 3. CDN fallback — the widget (_PlayerHeadshot) will try multiple
        //    ESPN CDN patterns automatically, so we just need the player ID.
        //    We only set a fallback URL here if we have nothing at all, so
        //    the widget's priority list starts from combiner426 (best rate).
        //    Leave headshot empty — the widget handles all CDN fallbacks.
        // (headshot stays '' — widget generates URLs from playerId)

        // ── Position ──────────────────────────────────────────────────────────
        final posAbbr =
        (a['position']?['abbreviation'] ?? a['position'] ?? '').toString();
        final posName =
        (a['position']?['name'] ?? a['position']?['displayName'] ?? '')
            .toString()
            .toLowerCase();
        final cat = _positionCategory(posAbbr, posName);

        // ── Nationality ───────────────────────────────────────────────────────
        final nationality = a['citizenship']?.toString() ??
            a['birthPlace']?['country']?.toString() ??
            a['nationality']?.toString() ?? '';

        players.add(TeamSquadPlayer(
          id: playerId,
          name: a['displayName']?.toString() ?? a['fullName']?.toString() ?? '',
          jersey: a['jersey']?.toString() ?? '',
          position: posAbbr,
          positionCategory: cat,
          nationality: nationality,
          age: a['age'] is int
              ? a['age'] as int
              : int.tryParse(a['age']?.toString() ?? ''),
          headshotUrl: headshot,
          rating: double.tryParse(a['rating']?.toString() ?? ''),
        ));
      }

      print('[TeamPage] Parsed ${players.length} players with IDs');
      return players;
    } catch (e) {
      print('[TeamPage] Roster error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Headshot enrichment
  // ──────────────────────────────────────────────────────────────────────────
  //
  // sports.core.api.espn.com returns 403 from mobile clients (no Referer).
  // Instead we use site.api.espn.com which respects our headers, and for
  // players still missing a URL we build the combiner URL (which works when
  // the Image.network widget sends Referer: https://www.espn.com/).
  //
  Future<List<TeamSquadPlayer>> _enrichRosterHeadshots(
      List<TeamSquadPlayer> players, String leagueCode) async {
    if (players.isEmpty) return players;

    // Headers that unlock ESPN CDN and API endpoints
    final headers = {
      ..._headers,
      'Referer': 'https://www.espn.com/',
      'Origin':  'https://www.espn.com',
    };

    // Build a mutable map of id → bestUrl, seeded with whatever we already have
    final enriched = <String, String>{
      for (final p in players) p.id: p.headshotUrl,
    };

    // Only fetch for players who are still missing a real URL
    final missing = players
        .where((p) => p.id.isNotEmpty && p.headshotUrl.isEmpty)
        .toList();

    print('[Headshot] ${players.length} total players, ${missing.length} missing headshots');

    // ── Strategy: try multiple ESPN endpoints in order of reliability ──────
    //
    // 1. sports.core.api.espn.com — the authoritative athlete data source.
    //    Returns {"headshot": {"href": "https://a.espncdn.com/..."}} with the
    //    actual hosted image URL (not a constructed CDN path).
    //
    // 2. site.web.api.espn.com/apis/common/v3 — alternative endpoint that
    //    also returns reliable headshot.href values.
    //
    // 3. site.api.espn.com (original endpoint) — last resort.
    //
    // 4. If all fail, leave headshotUrl empty — the _PlayerHeadshot widget
    //    will try standard CDN patterns with proper Referer headers.
    //
    const batchSize = 10;
    for (int i = 0; i < missing.length; i += batchSize) {
      final batch = missing.sublist(i, (i + batchSize).clamp(0, missing.length));

      await Future.wait(batch.map((player) async {
        final pid = player.id;

        // ── Attempt 1: sports.core.api ─────────────────────────────────────
        try {
          final coreUrl =
              'https://sports.core.api.espn.com/v2/sports/soccer/leagues/'
              '$leagueCode/athletes/$pid?lang=en&region=us';
          final res = await _client
              .get(Uri.parse(coreUrl), headers: headers)
              .timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            final found = _extractHeadshotFromAthleteData(data);
            if (found != null && found.isNotEmpty) {
              enriched[pid] = found;
              return;
            }
          }
        } catch (_) { /* fall through */ }

        // ── Attempt 2: site.web.api common/v3 ─────────────────────────────
        try {
          final webUrl =
              'https://site.web.api.espn.com/apis/common/v3/sports/soccer/'
              '$leagueCode/athletes/$pid';
          final res = await _client
              .get(Uri.parse(webUrl), headers: headers)
              .timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            // common/v3 wraps in an "athlete" key
            final athleteData = data['athlete'] is Map
                ? data['athlete'] as Map<String, dynamic>
                : data;
            final found = _extractHeadshotFromAthleteData(athleteData);
            if (found != null && found.isNotEmpty) {
              enriched[pid] = found;
              return;
            }
          }
        } catch (_) { /* fall through */ }

        // ── Attempt 3: site.api.espn.com (original endpoint) ──────────────
        try {
          final siteUrl =
              '${AppConstants.baseUrl}/$leagueCode/athletes/$pid';
          final res = await _client
              .get(Uri.parse(siteUrl), headers: headers)
              .timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            final found = _extractHeadshotFromAthleteData(data);
            if (found != null && found.isNotEmpty) {
              enriched[pid] = found;
              return;
            }
          }
        } catch (_) { /* fall through */ }

        // No URL found — leave empty so _PlayerHeadshot widget tries CDN patterns
      }));
    }

    final gotHeadshot = enriched.values.where((v) => v.isNotEmpty).length;
    print('[Headshot] Enrichment complete: $gotHeadshot/${players.length} have URLs');

    return players.map((p) {
      final newUrl = enriched[p.id] ?? '';
      if (newUrl.isNotEmpty && newUrl != p.headshotUrl) {
        return TeamSquadPlayer(
          id: p.id,
          name: p.name,
          jersey: p.jersey,
          position: p.position,
          positionCategory: p.positionCategory,
          nationality: p.nationality,
          age: p.age,
          headshotUrl: newUrl,
          rating: p.rating,
        );
      }
      return p;
    }).toList();
  }

  /// Extracts a headshot image URL from an ESPN athlete data map.
  /// Handles the various shapes ESPN uses across its different API endpoints.
  String? _extractHeadshotFromAthleteData(Map<String, dynamic> data) {
    // Shape 1: {"headshot": {"href": "https://..."}}  — sports.core.api
    final hs = data['headshot'];
    if (hs is Map) {
      final href = hs['href']?.toString() ?? '';
      if (href.isNotEmpty && href.startsWith('http')) return href;
      final full = hs['full']?.toString() ?? '';
      if (full.isNotEmpty && full.startsWith('http')) return full;
    }
    // Shape 2: {"headshot": "https://..."}  — direct string
    if (hs is String && hs.isNotEmpty && hs.startsWith('http')) return hs;

    // Shape 3: links[] with rel containing "headshot" or "photo"
    final links = data['links'] as List? ?? [];
    for (final link in links) {
      if (link is! Map) continue;
      final rels = (link['rel'] as List? ?? [])
          .map((r) => r.toString().toLowerCase())
          .toList();
      if (rels.contains('headshot') || rels.contains('photo') ||
          rels.contains('athlete-headshot')) {
        final href = link['href']?.toString() ?? '';
        if (href.isNotEmpty && href.startsWith('http')) return href;
      }
    }

    // Shape 4: athlete.images[] — some common/v3 responses
    final images = data['images'] as List? ?? [];
    for (final img in images) {
      if (img is! Map) continue;
      final imgType = img['type']?.toString().toLowerCase() ??
          img['name']?.toString().toLowerCase() ?? '';
      if (imgType.contains('headshot') || imgType.contains('photo')) {
        final href = img['href']?.toString() ?? img['url']?.toString() ?? '';
        if (href.isNotEmpty && href.startsWith('http')) return href;
      }
    }

    return null;
  }

  String _positionCategory(String abbr, String name) {
    final a = abbr.toUpperCase();
    if (a == 'GK' || name.contains('goalkeeper') || name.contains('keeper')) {
      return 'GOALKEEPERS';
    }
    if (['CB', 'LB', 'RB', 'SW', 'WB', 'LWB', 'RWB'].contains(a) ||
        name.contains('back') || name.contains('defender')) {
      return 'DEFENDERS';
    }
    if (['ST', 'CF', 'LW', 'RW', 'SS', 'FW'].contains(a) ||
        name.contains('forward') ||
        name.contains('striker') ||
        name.contains('winger')) {
      return 'FORWARDS';
    }
    return 'MIDFIELDERS';
  }

  Future<TeamStandingInfo> _fetchTeamStandingInfo(
      String teamId, String leagueCode) async {
    final url = '${AppConstants.standingsUrl}/$leagueCode/standings';
    print('[TeamPage] Fetching standings: $url');
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      print('[TeamPage] Standings HTTP ${res.statusCode}');
      if (res.statusCode != 200) return const TeamStandingInfo();
      return _parseStandingForTeam(
          json.decode(res.body) as Map<String, dynamic>, teamId);
    } catch (e) {
      print('[TeamPage] Standings error: $e');
      return const TeamStandingInfo();
    }
  }

  TeamStandingInfo _parseStandingForTeam(
      Map<String, dynamic> data, String teamId) {
    int pos = 1;
    final children = data['children'] as List? ?? [];
    for (final child in children) {
      final sub = child['children'] as List? ?? [];
      for (final s in sub) {
        final entries = s['standings']?['entries'] as List? ??
            s['standings'] as List? ?? [];
        for (final ts in entries) {
          if (ts['team']?['id']?.toString() == teamId) {
            int? pts;
            for (final stat in (ts['stats'] as List? ?? [])) {
              if ((stat['name'] ?? '').toString().toLowerCase() == 'points') {
                pts = int.tryParse(stat['displayValue']?.toString() ?? '');
                break;
              }
            }
            return TeamStandingInfo(
                rank: pos, points: pts, groupName: s['name']?.toString());
          }
          pos++;
        }
      }
      final entries = child['standings']?['entries'] as List? ??
          child['standings'] as List? ?? [];
      for (final ts in entries) {
        if (ts['team']?['id']?.toString() == teamId) {
          int? pts;
          for (final stat in (ts['stats'] as List? ?? [])) {
            if ((stat['name'] ?? '').toString().toLowerCase() == 'points') {
              pts = int.tryParse(stat['displayValue']?.toString() ?? '');
              break;
            }
          }
          return TeamStandingInfo(
              rank: pos, points: pts, groupName: child['name']?.toString());
        }
        pos++;
      }
    }
    return const TeamStandingInfo();
  }

  TeamAnalytics _calculateAnalytics(
      List<TeamRecentMatch> matches, List<TeamSquadPlayer> squad) {
    if (matches.isEmpty) return TeamAnalytics.empty;

    int wins = 0, draws = 0, losses = 0;
    int gf = 0, ga = 0, yc = 0, rc = 0;
    double possSum = 0, shotsSum = 0, sotSum = 0;
    int possN = 0, shotsN = 0, sotN = 0;

    for (final m in matches) {
      if (m.result == 'win') wins++;
      else if (m.result == 'draw') draws++;
      else losses++;
      gf += m.goalsFor;
      ga += m.goalsAgainst;
      yc += m.yellowCards;
      rc += m.redCards;
      if (m.possession != null && m.possession! > 0) {
        possSum += m.possession!; possN++;
      }
      if (m.shots != null && m.shots! > 0) {
        shotsSum += m.shots!; shotsN++;
      }
      if (m.shotsOnTarget != null && m.shotsOnTarget! > 0) {
        sotSum += m.shotsOnTarget!; sotN++;
      }
    }

    final n = matches.length;
    final avgPoss  = possN > 0 ? possSum / possN : null;
    final avgShots = shotsN > 0 ? shotsSum / shotsN : null;

    // ── SHOTS ON TARGET: store the RAW TOTAL across last-5 games ─────────────
    // The UI tile labelled "SHOTS ON TARGET" shows the cumulative total, not an avg.
    // Fall back to total shots when ESPN didn't return separate SOT data.
    final totalSot   = sotN > 0 ? sotSum : (shotsN > 0 ? shotsSum : null);
    final avgSot     = sotN > 0 ? sotSum / sotN : null;   // kept for radar/tactical section

    // ── CONVERSION RATE: Goals ÷ Shots On Target (fall back to Goals ÷ Shots) ─
    // ESPN's shotsOnTarget stat is preferred; fall back to total shots.
    final conv = totalSot != null && totalSot > 0
        ? gf / totalSot
        : null;

    // ── Fallback shot estimate (for radar only, never shown in metric tiles) ──
    final effectiveShotsPerGame =
        avgShots ?? (gf / n * 6.0).clamp(3.0, 20.0);

    final gaPerGame   = n > 0 ? ga / n : 0.0;
    final goalsPerGame = n > 0 ? gf / n : 0.0;
    final attackScore  = (goalsPerGame / 2.5 * 100).clamp(0.0, 100.0);
    final defScore     = ((1 - gaPerGame / 3.0) * 100).clamp(0.0, 100.0);

    final possScore = avgPoss != null
        ? avgPoss.clamp(0.0, 100.0)
        : (50.0 + (wins - losses) * 3.0).clamp(30.0, 70.0);

    final shotScore = (effectiveShotsPerGame / 20.0 * 100).clamp(0.0, 100.0);

    final midScore = (possScore * 0.55 + shotScore * 0.45).clamp(0.0, 100.0);

    final cardPenalty = n > 0 ? (yc + rc * 3) / (n * 5.0) : 0.0;
    final discScore   = ((1 - cardPenalty) * 100).clamp(0.0, 100.0);

    print('[TeamPage] SOT-DATA: avgShots=$avgShots avgSot=$avgSot conv=$conv sotN=$sotN shotsN=$shotsN');
    print('[TeamPage] Analytics: attack=${attackScore.toStringAsFixed(1)} '
        'def=${defScore.toStringAsFixed(1)} poss=${possScore.toStringAsFixed(1)} '
        'mid=${midScore.toStringAsFixed(1)} disc=${discScore.toStringAsFixed(1)}');
    print('[TeamPage] Goals: $gf for, $ga against | W$wins D$draws L$losses | Cards: $yc Y, $rc R');

    TeamSquadPlayer? best;
    double? bestRating;

    for (final p in squad) {
      if (p.rating != null && (bestRating == null || p.rating! > bestRating!)) {
        bestRating = p.rating;
        best = p;
      }
    }

    if (best == null && squad.isNotEmpty) {
      final priorities = ['FORWARDS', 'MIDFIELDERS', 'DEFENDERS', 'GOALKEEPERS'];
      for (final cat in priorities) {
        final pool = squad.where((p) => p.positionCategory == cat).toList();
        if (pool.isNotEmpty) {
          pool.sort((a, b) =>
              (int.tryParse(a.jersey) ?? 99).compareTo(int.tryParse(b.jersey) ?? 99));
          best = pool.first;
          break;
        }
      }
    }

    String note = '';
    if (best != null) {
      final winRate = n > 0 ? (wins / n * 100).toStringAsFixed(0) : '0';
      final goalAvg = n > 0 ? (gf / n).toStringAsFixed(1) : '0';
      final formStr = [
        if (wins > 0) '$wins W',
        if (draws > 0) '$draws D',
        if (losses > 0) '$losses L',
      ].join(', ');

      switch (best.positionCategory) {
        case 'FORWARDS':
          note = 'Key attacker · $formStr · $goalAvg goals/game avg';
          break;
        case 'MIDFIELDERS':
          note = 'Engine of the team · $formStr · $winRate% win rate';
          break;
        case 'DEFENDERS':
          note = 'Defensive anchor · $ga goals conceded in last ${matches.length}';
          break;
        default:
          note = 'Shot-stopper · $ga goals conceded · Last ${matches.length} matches';
      }
    }

    return TeamAnalytics(
      last5Wins: wins,
      last5Draws: draws,
      last5Losses: losses,
      last5GoalsFor: gf,
      last5GoalsAgainst: ga,
      last5YellowCards: yc,
      last5RedCards: rc,
      avgPossession: avgPoss,
      // avgShotsPerGame → used for AVG SHOTS/GAME tile and radar
      avgShotsPerGame: avgShots ?? effectiveShotsPerGame,
      // avgShotsOnTarget → repurposed as TOTAL SOT across last-5 for the tile display
      // Falls back to total shots if ESPN didn't provide separate SOT data
      avgShotsOnTarget: totalSot,
      // shotConversionRate → Goals ÷ SOT (or Goals ÷ Shots as fallback)
      shotConversionRate: conv,
      attackScore: attackScore,
      midfieldScore: midScore,
      defenseScore: defScore,
      possessionScore: possScore,
      disciplineScore: discScore,
      bestPlayer: best,
      bestPlayerRating: bestRating,
      bestPlayerGoals: gf,
      bestPlayerAssists: 0,
      bestPlayerPerformanceNote: note,
    );
  }
}