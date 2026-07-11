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
import 'package:livescore/services/cache_service.dart';
import 'package:livescore/screens/game_detail_screen.dart'
    show MatchLineup, LineupPlayer, H2HResult;

import '../models/search_model.dart';
import 'api_key_manager.dart';

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
  final CacheService _cache = CacheService();

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

    // Expanded LIVE detection
    if (s.contains('progress') ||
        s == 'in progress' ||
        s.contains('halftime') ||
        s.contains('half time') ||
        s.contains('extra time') ||
        s.contains('overtime') ||
        s.contains('penalty') ||
        s.contains('shootout') ||
        s.contains('1st half') ||
        s.contains('2nd half') ||
        s.contains('1st half') ||
        s.contains('2nd half') ||
        s.contains('half') ||
        s.contains('live') ||
        s.contains('active') ||
        s.contains('started') ||
        s.contains('playing') ||
        s.contains('ongoing')) {
      return 'STATUS_LIVE';
    }

    // Expanded FINAL detection
    if (s.contains('final') ||
        s == 'ft' ||
        s == 'finished' ||
        s == 'ended' ||
        s.contains('full time') ||
        s == 'after extra time' ||
        s == 'after penalties' ||
        s == 'post' ||
        s == 'complete' ||
        s == 'completed' ||
        s == 'result' ||
        s.contains('fulltime') ||
        s.contains('end')) {
      return 'STATUS_FINAL';
    }

    // Everything else is scheduled
    return 'STATUS_SCHEDULED';
  }

  // api_service.dart - Fixed _normalizeEventStatus function

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
      // Check type block first (most reliable)
      final typeBlock = statusBlock['type'] as Map<String, dynamic>?;
      if (typeBlock != null) {
        final state = typeBlock['state']?.toString().toLowerCase() ?? '';
        final name = typeBlock['name']?.toString().toLowerCase() ?? '';
        final description = typeBlock['description']?.toString().toLowerCase() ?? '';
        final completed = typeBlock['completed'];

        // Check for LIVE states - expanded to catch all variations
        if (state == 'in' ||
            state == 'live' ||
            state == 'inprogress' ||
            state == 'in progress' ||
            state == 'active' ||
            state == 'started' ||
            state == 'progress' ||
            name.contains('live') ||
            name.contains('in progress') ||
            name.contains('active') ||
            description.contains('live') ||
            description.contains('in progress') ||
            description.contains('halftime') ||
            description.contains('half time') ||
            description.contains('extra time') ||
            description.contains('overtime') ||
            description.contains('penalty') ||
            description.contains('shootout')) {
          return 'STATUS_LIVE';
        }

        // Check for FINAL states
        if (state == 'post' ||
            state == 'finished' ||
            state == 'completed' ||
            state == 'final' ||
            name.contains('final') ||
            name.contains('full time') ||
            name.contains('finished') ||
            name.contains('completed') ||
            description.contains('final') ||
            description.contains('full time') ||
            description.contains('finished') ||
            completed == true) {
          return 'STATUS_FINAL';
        }

        // Check for SCHEDULED/UPCOMING states
        if (state == 'pre' ||
            state == 'scheduled' ||
            state == 'upcoming' ||
            state == 'pending' ||
            name.contains('scheduled') ||
            name.contains('upcoming') ||
            name.contains('pre') ||
            description.contains('scheduled') ||
            description.contains('upcoming')) {
          return 'STATUS_SCHEDULED';
        }
      }

      // Check direct status fields
      final state = statusBlock['state']?.toString().toLowerCase() ?? '';
      final description = statusBlock['description']?.toString().toLowerCase() ?? '';
      final displayClock = statusBlock['displayClock']?.toString() ?? '';
      final periodRaw = statusBlock['period'];
      final completed = statusBlock['completed'];

      // Check for LIVE states from direct fields
      if (state == 'in' ||
          state == 'live' ||
          state == 'inprogress' ||
          state == 'in progress' ||
          state == 'active' ||
          state == 'started' ||
          state == 'progress' ||
          description.contains('live') ||
          description.contains('in progress') ||
          description.contains('halftime') ||
          description.contains('half time') ||
          description.contains('extra time') ||
          description.contains('overtime') ||
          description.contains('penalty')) {
        return 'STATUS_LIVE';
      }

      // Check for FINAL states from direct fields
      if (state == 'post' ||
          state == 'finished' ||
          state == 'completed' ||
          state == 'final' ||
          description.contains('final') ||
          description.contains('full time') ||
          description.contains('finished') ||
          completed == true) {
        return 'STATUS_FINAL';
      }

      // Check for SCHEDULED states from direct fields
      if (state == 'pre' ||
          state == 'scheduled' ||
          state == 'upcoming' ||
          state == 'pending' ||
          description.contains('scheduled') ||
          description.contains('upcoming')) {
        return 'STATUS_SCHEDULED';
      }

      // If there's a displayClock and period, determine status from them
      if (displayClock.isNotEmpty && periodRaw != null) {
        final periodVal = int.tryParse(periodRaw.toString()) ?? 0;

        // If we have a clock and period >= 1, it's likely live
        if (periodVal >= 1 && periodVal <= 3) {
          // Check if it's halftime (clock often "0:00" at HT)
          if (displayClock == '0:00' && periodVal >= 2) {
            // Could be HT or FT - check if there's more info
            if (description.contains('halftime') || description.contains('half time')) {
              return 'STATUS_LIVE';
            }
            // If period is 2 and clock is 0:00, it's likely halftime
            if (periodVal == 2 && displayClock == '0:00') {
              return 'STATUS_LIVE';
            }
            // If period is 3+ and clock is 0:00, it might be FT
            if (periodVal >= 3 && displayClock == '0:00') {
              return 'STATUS_FINAL';
            }
          }
          // Any other clock with period >= 1 is live
          return 'STATUS_LIVE';
        }
      }
    }

    // Fallback: Check if the event is currently happening based on date
    try {
      final eventDate = DateTime.parse(event['date']?.toString() ?? '');
      final now = DateTime.now();
      final eventEnd = eventDate.add(const Duration(hours: 2, minutes: 30));

      // If current time is between event start and 2.5 hours after, it's likely live
      if (now.isAfter(eventDate) && now.isBefore(eventEnd)) {
        // Check if there's any score data - if so, it's definitely live
        final competitions = event['competitions'] as List?;
        if (competitions != null && competitions.isNotEmpty) {
          final comp = competitions.first as Map<String, dynamic>;
          final competitors = comp['competitors'] as List?;
          if (competitors != null && competitors.isNotEmpty) {
            for (final c in competitors) {
              if (c is Map && c['score'] != null && c['score'] != '0') {
                return 'STATUS_LIVE';
              }
            }
          }
        }
        // If we have a displayClock, it's live
        final status = event['status'] as Map<String, dynamic>?;
        if (status != null && status['displayClock']?.toString().isNotEmpty == true) {
          return 'STATUS_LIVE';
        }
      }

      // If event date is more than 3 hours ago, it's final
      if (now.isAfter(eventDate.add(const Duration(hours: 3)))) {
        return 'STATUS_FINAL';
      }
    } catch (_) {}

    // If the event is in the past but not marked as final, try to determine from score
    try {
      final eventDate = DateTime.parse(event['date']?.toString() ?? '');
      final now = DateTime.now();
      if (now.isAfter(eventDate)) {
        final competitions = event['competitions'] as List?;
        if (competitions != null && competitions.isNotEmpty) {
          final comp = competitions.first as Map<String, dynamic>;
          final competitors = comp['competitors'] as List?;
          if (competitors != null && competitors.isNotEmpty) {
            bool hasScore = false;
            for (final c in competitors) {
              if (c is Map && c['score'] != null) {
                final score = c['score'].toString();
                if (score.isNotEmpty && score != '0') {
                  hasScore = true;
                  break;
                }
              }
            }
            // If it's past and has scores, it's final
            if (hasScore) {
              return 'STATUS_FINAL';
            }
          }
        }
      }
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

        // Use the improved status detection
        final status = _normalizeEventStatus(event);

        // Additional check: if status is SCHEDULED but the event has a clock and score, it's actually LIVE
        if (status == 'STATUS_SCHEDULED') {
          final clock = event['status']?['displayClock']?.toString() ?? '';
          final hasScore = competitors.any((c) {
            final score = c['score']?.toString() ?? '';
            return score.isNotEmpty && score != '0';
          });
          if (clock.isNotEmpty && clock != '0:00' && hasScore) {
            // This is actually a live match
            print('[API] Status correction: SCHEDULED -> LIVE for event ${event['id']} (clock: $clock)');
          }
        }

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
  String _resolveTeamLogo(Map<String, dynamic> teamData) {
    final direct = teamData['logo']?.toString() ?? '';
    if (direct.isNotEmpty && direct.startsWith('http')) return direct;

    final logos = teamData['logos'] as List?;
    if (logos != null && logos.isNotEmpty) {
      final href = logos.first['href']?.toString() ?? '';
      if (href.isNotEmpty && href.startsWith('http')) return href;
    }

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

    List<dynamic> extractEntries(dynamic node) {
      final List<dynamic> entries = [];

      if (node == null) return entries;

      if (node['standings'] != null) {
        final standingsData = node['standings'];
        if (standingsData['entries'] != null) {
          entries.addAll(standingsData['entries'] as List);
        } else if (standingsData is List) {
          entries.addAll(standingsData);
        }
      }

      if (node['children'] != null && (node['children'] as List).isNotEmpty) {
        for (final child in node['children'] as List) {
          entries.addAll(extractEntries(child));
        }
      }

      return entries;
    }

    final List<dynamic> allEntries = extractEntries(data);
    print('[Standings] Found ${allEntries.length} entries');

    int rank = 1;
    String currentGroup = '';

    for (final entry in allEntries) {
      try {
        final teamData = entry['team'] as Map<String, dynamic>? ?? {};
        final statsList = entry['stats'] as List? ?? [];

        final Map<String, String> statsMap = {};
        int? points, goalsFor, goalsAgainst, gamesPlayed, wins, draws, losses;
        String? form;

        for (final stat in statsList) {
          final name  = stat['name']?.toString() ?? '';
          final abbr  = stat['abbreviation']?.toString() ?? '';
          final displayValue = stat['displayValue']?.toString() ?? '0';
          statsMap[name] = displayValue;
          if (abbr.isNotEmpty) statsMap[abbr] = displayValue;

          final key = name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
          final abbrKey = abbr.toLowerCase();
          switch (key) {
            case 'points':
            case 'pts':
              points = int.tryParse(displayValue);
              break;
            case 'pointsfor':
            case 'goalsfor':
            case 'goalsscored':
            case 'gf':
              goalsFor = int.tryParse(displayValue);
              break;
            case 'pointsagainst':
            case 'goalsagainst':
            case 'goalsconceded':
            case 'ga':
              goalsAgainst = int.tryParse(displayValue);
              break;
            case 'pointdifferential':
            case 'pointsdiff':
            case 'goaldifference':
            case 'goaldiff':
            case 'gd':
            case 'diff':
              final gdVal = int.tryParse(displayValue);
              if (gdVal != null && goalsFor == null && goalsAgainst == null) {}
              break;
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

        final gd = (goalsFor ?? 0) - (goalsAgainst ?? 0);

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

  Future<LeagueLeaders> getLeagueLeaders(String leagueCode, {String? season, int limit = 5}) async {
    final leagueId = AppConstants.apiFootballLeagueIds[leagueCode];
    if (leagueId == null) {
      print('[Leaders] No API-Football league mapping for $leagueCode — skipping');
      return LeagueLeaders.empty;
    }

    final apiKey = AppConstants.apiFootballKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_API_FOOTBALL_KEY_HERE') {
      print('[Leaders] No API-Football key configured — skipping leaders fetch');
      return LeagueLeaders.empty;
    }

    final seasonYear = AppConstants.apiFootballSeasonFor(leagueCode, season: season);

    print('[Leaders] Fetching leaders for $leagueCode (apiFootball league=$leagueId, season=$seasonYear)');

    final results = await Future.wait([
      _fetchApiFootballLeaders('topscorers', leagueId, seasonYear, limit),
      _fetchApiFootballLeaders('topassists', leagueId, seasonYear, limit),
      _fetchApiFootballLeaders('topyellowcards', leagueId, seasonYear, limit),
      _fetchApiFootballLeaders('topredcards', leagueId, seasonYear, limit),
    ]);

    final topScorers     = results[0];
    final topAssists     = results[1];
    final mostYellowCards = results[2];
    final mostRedCards    = results[3];

    if (topScorers.isEmpty && topAssists.isEmpty &&
        mostYellowCards.isEmpty && mostRedCards.isEmpty) {
      print('[Leaders] No leaders data returned for $leagueCode $seasonYear');
      return LeagueLeaders.empty;
    }

    print('[Leaders] ✅ scorers:${topScorers.length} assists:${topAssists.length} '
        'yellow:${mostYellowCards.length} red:${mostRedCards.length}');

    return LeagueLeaders(
      topScorers: topScorers,
      topAssists: topAssists,
      mostYellowCards: mostYellowCards,
      mostRedCards: mostRedCards,
    );
  }

  Future<List<LeaderEntry>> _fetchApiFootballLeaders(
      String statKey, int leagueId, int season, int limit) async {
    final url = '${AppConstants.apiFootballBaseUrl}/players/$statKey'
        '?league=$leagueId&season=$season';

    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: {'x-apisports-key': AppConstants.apiFootballKey},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        print('[Leaders] $statKey HTTP ${res.statusCode} for league=$leagueId season=$season: ${res.body}');
        return [];
      }

      final data = json.decode(res.body) as Map<String, dynamic>;

      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        // Common causes when this fires for a valid league/season combo:
        // the free API-Football plan doesn't include that season yet, or
        // the daily 100-request quota has been hit. Both surface here as
        // a non-empty `errors` map rather than an HTTP error.
        print('[Leaders] $statKey API error for league=$leagueId season=$season: $errors');
        return [];
      } else if (errors is List && errors.isNotEmpty) {
        print('[Leaders] $statKey API error for league=$leagueId season=$season: $errors');
        return [];
      }

      final rawList = data['response'] as List? ?? [];
      if (rawList.isEmpty) {
        // No `errors`, but also no data: usually means this competition/
        // season has no recorded stats yet (e.g. group stage hasn't
        // produced qualifying data) or isn't covered on the current plan.
        print('[Leaders] $statKey empty response for league=$leagueId season=$season '
            '(results=${data['results']})');
      }
      return rawList
          .take(limit)
          .map((entry) => _parseApiFootballLeader(entry as Map<String, dynamic>, statKey))
          .whereType<LeaderEntry>()
          .toList();
    } catch (e) {
      print('[Leaders] Error fetching $statKey: $e');
      return [];
    }
  }

  LeaderEntry? _parseApiFootballLeader(Map<String, dynamic> entry, String statKey) {
    try {
      final player = entry['player'] as Map<String, dynamic>? ?? {};
      final statsList = entry['statistics'] as List? ?? [];
      if (statsList.isEmpty) return null;
      final stats = statsList.first as Map<String, dynamic>;

      final team = stats['team'] as Map<String, dynamic>? ?? {};

      final athleteId = player['id']?.toString() ?? '';
      final name = player['name']?.toString() ?? '';
      if (name.isEmpty && athleteId.isEmpty) return null;

      final headshot = player['photo']?.toString() ?? '';
      final teamId = team['id']?.toString() ?? '';
      final teamLogo = team['logo']?.toString() ?? '';
      final teamName = team['name']?.toString() ?? '';
      final teamAbbr = teamName.length >= 3
          ? teamName.substring(0, 3).toUpperCase()
          : teamName.toUpperCase();

      num value = 0;
      switch (statKey) {
        case 'topscorers':
          value = (stats['goals']?['total'] as num?) ?? 0;
          break;
        case 'topassists':
          value = (stats['goals']?['assists'] as num?) ?? 0;
          break;
        case 'topyellowcards':
          value = (stats['cards']?['yellow'] as num?) ?? 0;
          break;
        case 'topredcards':
          value = (stats['cards']?['red'] as num?) ?? 0;
          break;
      }

      return LeaderEntry(
        athleteId: athleteId,
        name: name,
        headshot: headshot,
        teamId: teamId,
        teamAbbreviation: teamAbbr,
        teamLogo: teamLogo,
        value: value,
      );
    } catch (e) {
      print('[Leaders] Error parsing $statKey entry: $e');
      return null;
    }
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

  Future<MatchLineup?> getMatchLineup(String gameId) async {
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

        final hasHeader   = data['header'] != null;
        final hasBoxscore = data['boxscore'] != null;
        if (!hasHeader && !hasBoxscore) continue;

        List<LineupPlayer> homePlayers = [];
        List<LineupPlayer> awayPlayers = [];
        String homeFormation = '';
        String awayFormation = '';

        final boxscorePlayers =
            data['boxscore']?['players'] as List? ?? [];

        for (final teamData in boxscorePlayers) {
          final isHome = teamData['homeAway']?.toString() == 'home';
          final formation = teamData['formation']?.toString() ?? '';
          if (isHome && formation.isNotEmpty) homeFormation = formation;
          if (!isHome && formation.isNotEmpty) awayFormation = formation;

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

          final roster = teamData['roster'] as List? ?? [];
          for (final a in roster) {
            final p = _parseLineupAthlete(a, isHome: isHome);
            if (p != null) {
              if (isHome) homePlayers.add(p);
              else awayPlayers.add(p);
            }
          }
        }

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

        homePlayers = _dedup(homePlayers);
        awayPlayers = _dedup(awayPlayers);

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

  LineupPlayer? _parseLineupAthlete(dynamic raw, {required bool isHome}) {
    if (raw == null) return null;
    final a = raw as Map<String, dynamic>;

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

    final starter = a['starter'] == true
        || a['active'] == true
        || a['didPlay'] == true;

    String headshot = '';
    final rawHs = athlete['headshot'] ?? a['headshot'];
    if (rawHs is String) {
      headshot = rawHs;
    } else if (rawHs is Map) {
      headshot = (rawHs['href'] ?? rawHs['full'] ?? rawHs['default'] ?? '').toString();
    }
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

  List<LineupPlayer> _dedup(List<LineupPlayer> players) {
    final seen = <String>{};
    return players.where((p) {
      if (p.id.isEmpty) return true;
      return seen.add(p.id);
    }).toList();
  }

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



// ─── SEARCH METHODS ─────────────────────────────────────────────────────────────

  /// Search for players, teams, and leagues using ESPN's API
// Add these methods to api_service.dart

// ─── SEARCH METHODS ─────────────────────────────────────────────────────────────

  /// Search for players, teams, and leagues using ESPN's API
  // ─── SEARCH METHODS ─────────────────────────────────────────────────────────────

  /// Search for players, teams, and leagues using ESPN's API
// ─── SEARCH METHODS ─────────────────────────────────────────────────────────────


// ─── SEARCH METHODS USING API-FOOTBALL ──────────────────────────────────────

  /// Search for players, teams, and leagues using API-Football
  Future<SearchResponse> search(String query) async {
    if (query.trim().isEmpty) {
      return SearchResponse();
    }

    print('[Search] Searching for: "$query" using API-Football');
    final lowerQuery = query.trim();

    final List<SearchResult> players = [];
    final List<SearchResult> teams = [];
    final List<SearchResult> leagues = [];

    try {
      // ── Search Leagues (from constants - instant) ─────────────────────────
      final leagueResults = _searchLeaguesFromConstants(lowerQuery);
      leagues.addAll(leagueResults);
      print('[Search] Found ${leagues.length} leagues');

      // ── Search Teams (API-Football) ──────────────────────────────────────
      final teamResults = await _searchTeamsApiFootball(lowerQuery);
      teams.addAll(teamResults);
      print('[Search] Found ${teams.length} teams');

      // ── Search Players (API-Football - search in multiple leagues) ──────
      final playerResults = await _searchPlayersApiFootball(lowerQuery);
      players.addAll(playerResults);
      print('[Search] Found ${players.length} players');

      print('[Search] Total: ${players.length + teams.length + leagues.length} results (players: ${players.length}, teams: ${teams.length}, leagues: ${leagues.length})');

      return SearchResponse(
        players: players,
        teams: teams,
        leagues: leagues,
      );
    } catch (e) {
      print('[Search] Error: $e');
      return SearchResponse(
        players: players,
        teams: teams,
        leagues: leagues,
      );
    }
  }

  /// Search teams using API-Football
  Future<List<SearchResult>> _searchTeamsApiFootball(String query) async {
    final List<SearchResult> results = [];
    final Set<String> seenIds = {};

    final keyManager = ApiKeyManager();

    print('[SearchTeams] Searching for: "$query"');

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final apiKey = keyManager.getNextKey();

        final url = '${AppConstants.apiFootballBaseUrl}/teams?search=$query';

        print('[SearchTeams] Requesting: $url');

        final res = await _client.get(
          Uri.parse(url),
          headers: {'x-apisports-key': apiKey},
        ).timeout(const Duration(seconds: 10));

        keyManager.markRequest(apiKey);

        print('[SearchTeams] Response status: ${res.statusCode}');

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;

          if (data['errors'] != null && data['errors'].isNotEmpty) {
            print('[SearchTeams] API error: ${data['errors']}');
            continue;
          }

          final response = data['response'] as List? ?? [];
          print('[SearchTeams] Found ${response.length} raw results');

          for (final teamData in response) {
            if (teamData is! Map) continue;
            final team = teamData['team'] as Map<String, dynamic>?;

            if (team == null) continue;

            final id = team['id']?.toString() ?? '';
            if (id.isEmpty || seenIds.contains(id)) continue;

            final name = team['name']?.toString() ?? '';
            final displayName = team['name']?.toString() ?? '';
            final abbreviation = team['code']?.toString() ?? '';
            final logo = team['logo']?.toString() ?? '';

            // Check if query matches the name (case insensitive)
            if (!name.toLowerCase().contains(query.toLowerCase())) {
              continue;
            }

            seenIds.add(id);

            // Try to find league for this team from constants
            String leagueName = '';
            String leagueCode = '';
            for (final league in AppConstants.allLeagues) {
              if (name.toLowerCase().contains(league['name']!.toLowerCase().split(' ').first.toLowerCase())) {
                leagueName = league['name']!;
                leagueCode = league['code']!;
                break;
              }
            }

            results.add(SearchResult(
              id: id,
              name: name,
              displayName: displayName,
              type: 'team',
              imageUrl: logo.isNotEmpty ? logo : null,
              leagueName: leagueName,
              leagueCode: leagueCode,
              abbreviation: abbreviation,
            ));

            print('[SearchTeams] Added: $name');
          }
          break; // Success
        } else if (res.statusCode == 429) {
          print('[SearchTeams] Rate limit hit, trying next key...');
          continue;
        } else {
          print('[SearchTeams] API error: ${res.statusCode}');
          break;
        }
      } catch (e) {
        print('[SearchTeams] Exception: $e');
      }
    }

    return results;
  }

  /// Search players using API-Football by searching across multiple leagues
  Future<List<SearchResult>> _searchPlayersApiFootball(String query) async {
    final List<SearchResult> results = [];
    final Set<String> seenIds = {};

    final keyManager = ApiKeyManager();

    print('[SearchPlayers] Searching for: "$query"');

    // Common league IDs to search for players
    // 39 = Premier League, 140 = La Liga, 135 = Serie A, 78 = Bundesliga, 61 = Ligue 1
    // 2 = Champions League, 3 = Europa League
    // 71 = Brasileirão, 253 = MLS, 128 = Argentina, 94 = Portugal, 88 = Netherlands
    final leagueIds = [39, 140, 135, 78, 61, 2, 3, 71, 253, 128, 94, 88, 203, 144, 179];

    // Use current season (2024 or 2025)
    final currentYear = DateTime.now().year;
    final season = currentYear >= 7 ? currentYear : currentYear - 1;

    for (final leagueId in leagueIds) {
      if (results.length >= 30) break; // Limit results to 30

      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final apiKey = keyManager.getNextKey();

          // Search players by name with league filter
          // Note: API-Football requires league or team with search
          final url = '${AppConstants.apiFootballBaseUrl}/players?league=$leagueId&season=$season&search=$query&limit=20';

          print('[SearchPlayers] Searching league $leagueId for "$query"');

          final res = await _client.get(
            Uri.parse(url),
            headers: {'x-apisports-key': apiKey},
          ).timeout(const Duration(seconds: 8));

          keyManager.markRequest(apiKey);

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;

            if (data['errors'] != null && data['errors'].isNotEmpty) {
              print('[SearchPlayers] League $leagueId error: ${data['errors']}');
              break;
            }

            final response = data['response'] as List? ?? [];

            if (response.isNotEmpty) {
              print('[SearchPlayers] League $leagueId found ${response.length} players');
            }

            for (final playerData in response) {
              if (results.length >= 30) break;
              if (playerData is! Map) continue;

              final player = playerData['player'] as Map<String, dynamic>?;
              if (player == null) continue;

              final id = player['id']?.toString() ?? '';
              if (id.isEmpty || seenIds.contains(id)) continue;

              final name = player['name']?.toString() ?? '';
              final firstname = player['firstname']?.toString() ?? '';
              final lastname = player['lastname']?.toString() ?? '';
              final displayName = '$firstname $lastname'.trim();

              // Double-check name match
              final searchableText = '$name $firstname $lastname'.toLowerCase();
              if (!searchableText.contains(query.toLowerCase())) {
                continue;
              }

              seenIds.add(id);

              String position = '';
              String headshot = player['photo']?.toString() ?? '';
              String nationality = player['nationality']?.toString() ?? '';
              int? age = player['age'] as int?;

              final statistics = playerData['statistics'] as List? ?? [];
              String teamName = '';
              if (statistics.isNotEmpty) {
                final firstStat = statistics.first as Map<String, dynamic>;
                final team = firstStat['team'] as Map<String, dynamic>?;
                if (team != null) {
                  teamName = team['name']?.toString() ?? '';
                }
                final games = firstStat['games'] as Map<String, dynamic>?;
                if (games != null) {
                  position = games['position']?.toString() ?? '';
                }
              }

              results.add(SearchResult(
                id: id,
                name: name.isNotEmpty ? name : displayName,
                displayName: displayName.isNotEmpty ? displayName : name,
                type: 'player',
                imageUrl: headshot.isNotEmpty ? headshot : null,
                teamName: teamName,
                teamId: '',
                position: position,
                jerseyNumber: '',
                abbreviation: '',
                nationality: nationality,
                age: age,
                rating: null,
              ));

              print('[SearchPlayers] Added: $displayName ($position) from ${teamName.isNotEmpty ? teamName : 'Unknown Team'}');
            }
            break; // Success, move to next league
          } else if (res.statusCode == 429) {
            print('[SearchPlayers] Rate limit hit, trying next key...');
            continue;
          } else {
            print('[SearchPlayers] League $leagueId API error: ${res.statusCode}');
            break;
          }
        } catch (e) {
          print('[SearchPlayers] Exception for league $leagueId: $e');
        }
      }
    }

    // If we didn't find many results, try searching without the search parameter
    // and filter manually (some leagues don't support search with league)
    if (results.length < 5) {
      print('[SearchPlayers] Few results found, trying fallback search...');

      for (final leagueId in leagueIds.take(5)) {
        if (results.length >= 20) break;

        try {
          final apiKey = keyManager.getNextKey();

          // Get players from league without search parameter
          final url = '${AppConstants.apiFootballBaseUrl}/players?league=$leagueId&season=$season&limit=30';

          final res = await _client.get(
            Uri.parse(url),
            headers: {'x-apisports-key': apiKey},
          ).timeout(const Duration(seconds: 8));

          keyManager.markRequest(apiKey);

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;

            if (data['errors'] != null && data['errors'].isNotEmpty) {
              continue;
            }

            final response = data['response'] as List? ?? [];

            for (final playerData in response) {
              if (results.length >= 20) break;
              if (playerData is! Map) continue;

              final player = playerData['player'] as Map<String, dynamic>?;
              if (player == null) continue;

              final id = player['id']?.toString() ?? '';
              if (id.isEmpty || seenIds.contains(id)) continue;

              final name = player['name']?.toString() ?? '';
              final firstname = player['firstname']?.toString() ?? '';
              final lastname = player['lastname']?.toString() ?? '';
              final displayName = '$firstname $lastname'.trim();

              final searchableText = '$name $firstname $lastname'.toLowerCase();
              if (!searchableText.contains(query.toLowerCase())) {
                continue;
              }

              seenIds.add(id);

              String position = '';
              String headshot = player['photo']?.toString() ?? '';
              String nationality = player['nationality']?.toString() ?? '';
              int? age = player['age'] as int?;

              final statistics = playerData['statistics'] as List? ?? [];
              String teamName = '';
              if (statistics.isNotEmpty) {
                final firstStat = statistics.first as Map<String, dynamic>;
                final team = firstStat['team'] as Map<String, dynamic>?;
                if (team != null) {
                  teamName = team['name']?.toString() ?? '';
                }
                final games = firstStat['games'] as Map<String, dynamic>?;
                if (games != null) {
                  position = games['position']?.toString() ?? '';
                }
              }

              results.add(SearchResult(
                id: id,
                name: name.isNotEmpty ? name : displayName,
                displayName: displayName.isNotEmpty ? displayName : name,
                type: 'player',
                imageUrl: headshot.isNotEmpty ? headshot : null,
                teamName: teamName,
                teamId: '',
                position: position,
                jerseyNumber: '',
                abbreviation: '',
                nationality: nationality,
                age: age,
                rating: null,
              ));

              print('[SearchPlayers] Fallback Added: $displayName');
            }
          }
        } catch (e) {
          print('[SearchPlayers] Fallback exception: $e');
        }
      }
    }

    print('[SearchPlayers] Total found: ${results.length} players');
    return results;
  }

  /// Search leagues from constants (instant, no API call needed)
  List<SearchResult> _searchLeaguesFromConstants(String query) {
    final List<SearchResult> results = [];
    final allLeagues = AppConstants.allLeagues;

    print('[SearchLeagues] Searching for: "$query"');

    for (final league in allLeagues) {
      final name = league['name'] ?? '';
      final code = league['code'] ?? '';
      final flag = league['flag'] ?? '⚽';

      final searchableText = '$name $code'.toLowerCase();
      if (searchableText.contains(query.toLowerCase())) {
        final logoUrl = AppConstants.leagueLogoUrl(code);

        results.add(SearchResult(
          id: code,
          name: name,
          displayName: name,
          type: 'league',
          imageUrl: logoUrl,
          leagueName: name,
          leagueCode: code,
          abbreviation: code.length > 3 ? code.substring(0, 3).toUpperCase() : code.toUpperCase(),
        ));

        print('[SearchLeagues] Added: $name');
      }
    }

    return results;
  }
  /// Helper method to extract headshot URL from athlete data
  String? _extractHeadshotFromAthleteData(dynamic data) {
    if (data == null) return null;

    // Convert to Map<String, dynamic> if needed
    final Map<String, dynamic> athleteData;
    if (data is Map<String, dynamic>) {
      athleteData = data;
    } else if (data is Map) {
      athleteData = Map<String, dynamic>.from(data);
    } else {
      return null;
    }

    final hs = athleteData['headshot'];
    if (hs is Map) {
      final href = hs['href']?.toString() ?? '';
      if (href.isNotEmpty && href.startsWith('http')) return href;
      final full = hs['full']?.toString() ?? '';
      if (full.isNotEmpty && full.startsWith('http')) return full;
    }
    if (hs is String && hs.isNotEmpty && hs.startsWith('http')) return hs;

    final links = athleteData['links'] as List? ?? [];
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

    final images = athleteData['images'] as List? ?? [];
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

  // ══════════════════════════════════════════════════════════════════════════════
  // TEAM PAGE DATA METHODS - MAIN ENTRY POINT
  // ══════════════════════════════════════════════════════════════════════════════

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

    // ── Club team path with cross-season handling ─────────────────────────────
    return _getTeamPageDataClub(teamId, resolvedLeague);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // CLUB TEAM DATA WITH CROSS-SEASON HANDLING
  // ══════════════════════════════════════════════════════════════════════════════

  Future<TeamPageData> _getTeamPageDataClub(
      String teamId,
      String leagueCode,
      ) async {
    print('[ClubTeam] ▶ _getTeamPageDataClub teamId=$teamId league=$leagueCode');

    // Get current season data first
    final currentResults = await Future.wait([
      _fetchTeamSchedule(teamId, leagueCode),
      _fetchTeamRosterFull(teamId, leagueCode),
      _fetchTeamStandingInfo(teamId, leagueCode),
    ]);

    _ScheduleResult currentSchedule = currentResults[0] as _ScheduleResult;
    final currentSquad = currentResults[1] as List<TeamSquadPlayer>;
    final currentStanding = currentResults[2] as TeamStandingInfo;

    print('[ClubTeam] Current season: ${currentSchedule.recentMatches.length} recent, ${currentSchedule.upcoming.length} upcoming');

    // ── Check if current season has started ──────────────────────────────────
    final now = DateTime.now();
    bool allMatchesOld = true;
    for (final match in currentSchedule.recentMatches) {
      try {
        final matchDate = DateTime.parse(match.date);
        if (matchDate.year >= now.year) {
          allMatchesOld = false;
          break;
        }
      } catch (_) {}
    }

    // ── If season hasn't started or all matches are old, fetch last season ──
    _ScheduleResult recentMatchesFromLastSeason = _ScheduleResult.empty();
    _ScheduleResult upcomingFromNextSeason = _ScheduleResult.empty();

    if (currentSchedule.recentMatches.isEmpty || allMatchesOld) {
      final lastYear = now.year - 1;
      print('[ClubTeam] Fetching last season ($lastYear) for recent matches');
      final lastSeasonSchedule = await _fetchTeamScheduleForYear(teamId, leagueCode, lastYear);
      if (lastSeasonSchedule.recentMatches.isNotEmpty) {
        recentMatchesFromLastSeason = lastSeasonSchedule;
        print('[ClubTeam] Found ${recentMatchesFromLastSeason.recentMatches.length} matches from last season');
      }
    }

    // ── If no upcoming fixtures, fetch next season ──────────────────────────
    if (currentSchedule.upcoming.isEmpty) {
      final nextYear = now.year + 1;
      print('[ClubTeam] Fetching next season ($nextYear) for upcoming fixtures');
      final nextSeasonSchedule = await _fetchTeamScheduleForYear(teamId, leagueCode, nextYear);
      if (nextSeasonSchedule.upcoming.isNotEmpty) {
        upcomingFromNextSeason = nextSeasonSchedule;
        print('[ClubTeam] Found ${upcomingFromNextSeason.upcoming.length} upcoming fixtures from next season');
      } else {
        final currentYear = now.year;
        final currentYearSchedule = await _fetchTeamScheduleForYear(teamId, leagueCode, currentYear);
        if (currentYearSchedule.upcoming.isNotEmpty) {
          upcomingFromNextSeason = currentYearSchedule;
          print('[ClubTeam] Found ${upcomingFromNextSeason.upcoming.length} upcoming fixtures from current season');
        }
      }
    }

    // ── Combine results ──────────────────────────────────────────────────────
    final List<TeamRecentMatch> finalRecentMatches = [];
    final List<String> finalRecentIds = [];

    if (recentMatchesFromLastSeason.recentMatches.isNotEmpty) {
      finalRecentMatches.addAll(recentMatchesFromLastSeason.recentMatches);
      finalRecentIds.addAll(recentMatchesFromLastSeason.recentMatchEventIds);
    } else {
      finalRecentMatches.addAll(currentSchedule.recentMatches);
      finalRecentIds.addAll(currentSchedule.recentMatchEventIds);
    }

    final List<TeamUpcomingFixture> finalUpcoming = [];
    if (upcomingFromNextSeason.upcoming.isNotEmpty) {
      finalUpcoming.addAll(upcomingFromNextSeason.upcoming);
    } else {
      finalUpcoming.addAll(currentSchedule.upcoming);
    }

    // Sort recent by date (newest first) and take top 5
    final sortedPairs = List.generate(finalRecentMatches.length, (i) => [finalRecentMatches[i], finalRecentIds[i]])
      ..sort((a, b) => (b[0] as TeamRecentMatch).date.compareTo((a[0] as TeamRecentMatch).date));
    final recent = sortedPairs.take(5).map((p) => p[0] as TeamRecentMatch).toList();
    final recentIds = sortedPairs.take(5).map((p) => p[1] as String).toList();

    // Sort upcoming by date (oldest first) and take top 5
    finalUpcoming.sort((a, b) => a.date.compareTo(b.date));
    final upcoming = finalUpcoming.take(5).toList();

    // ── Enrich headshots ──────────────────────────────────────────────────────
    final squadPlayers = await _enrichRosterHeadshots(
      currentSquad.isNotEmpty ? currentSquad : await _fetchTeamRosterFull(teamId, leagueCode),
      leagueCode,
      teamId: teamId,
    );

    // ── Enrich matches with summary stats ────────────────────────────────────
    final enrichedMatches = await _enrichMatchesWithSummaryStats(
      recent,
      recentIds,
      teamId,
      leagueCode,
    );

    // ── Calculate analytics ──────────────────────────────────────────────────
    final analytics = _calculateAnalytics(enrichedMatches, squadPlayers);

    print('[ClubTeam] Final: ${recent.length} recent, ${upcoming.length} upcoming');
    print('[ClubTeam] Squad: ${squadPlayers.length} players');

    return TeamPageData(
      leagueCode: leagueCode,
      standingInfo: currentStanding,
      recentMatches: enrichedMatches,
      upcoming: upcoming,
      squad: squadPlayers,
      analytics: analytics,
      headCoach: currentSchedule.headCoach ?? recentMatchesFromLastSeason.headCoach,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // NATIONAL TEAM DATA (World Cup 2026 + International fallback)
  // ══════════════════════════════════════════════════════════════════════════════

  Future<TeamPageData> _getTeamPageDataNational(
      String teamId, String leagueCode) async {
    print('[NationalTeam] ▶ _getTeamPageDataNational teamId=$teamId league=$leagueCode');

    final primaryLeague = AppConstants.isWorldCup(leagueCode) ? 'fifa.world' : leagueCode;
    final isWorldCup = AppConstants.isWorldCup(leagueCode);

    // ── For World Cup 2026, use the specialized fixture fetcher ──────────────
    _ScheduleResult scheduleData;
    List<TeamSquadPlayer> squadPlayers;
    TeamStandingInfo standingInfo;

    if (isWorldCup) {
      print('[WorldCup] Using specialized World Cup fixture fetcher');

      scheduleData = await _fetchWorldCupFixtures(teamId);

      final results = await Future.wait([
        _fetchTeamRosterFull(teamId, primaryLeague),
        _fetchTeamStandingInfo(teamId, primaryLeague),
      ]);

      squadPlayers = results[0] as List<TeamSquadPlayer>;
      standingInfo = results[1] as TeamStandingInfo;

      if (scheduleData.headCoach == null) {
        try {
          final coach = await _fetchTeamCoach(teamId, primaryLeague);
          scheduleData = _ScheduleResult(
            recentMatches: scheduleData.recentMatches,
            upcoming: scheduleData.upcoming,
            headCoach: coach,
            recentMatchEventIds: scheduleData.recentMatchEventIds,
          );
        } catch (_) {}
      }
    } else {
      // ── Other national teams (Euro, Copa America, etc.) ──────────────────────
      final results = await Future.wait([
        _fetchTeamSchedule(teamId, primaryLeague),
        _fetchTeamRosterFull(teamId, primaryLeague),
        _fetchTeamStandingInfo(teamId, primaryLeague),
      ]);

      scheduleData = results[0] as _ScheduleResult;
      squadPlayers = results[1] as List<TeamSquadPlayer>;
      standingInfo = results[2] as TeamStandingInfo;

      print('[NationalTeam] Primary schedule: ${scheduleData.recentMatches.length} recent, ${scheduleData.upcoming.length} upcoming');

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

      if (scheduleData.upcoming.isEmpty) {
        print('[NationalTeam] No upcoming fixtures — searching international fallback leagues');
        final fallbackUpcoming = await _fetchUpcomingFromAllLeagues(
          teamId,
          AppConstants.internationalFallbackLeagues,
        );
        if (fallbackUpcoming.isNotEmpty) {
          print('[NationalTeam] Found ${fallbackUpcoming.length} upcoming fixtures in fallback leagues');
          scheduleData = _ScheduleResult(
            recentMatches: scheduleData.recentMatches,
            upcoming: fallbackUpcoming,
            headCoach: scheduleData.headCoach,
            recentMatchEventIds: scheduleData.recentMatchEventIds,
          );
        }
      }

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
    }

    // ── Squad fallback ────────────────────────────────────────────────────────
    List<TeamSquadPlayer> finalSquad = squadPlayers;
    if (finalSquad.isEmpty && leagueCode != primaryLeague) {
      finalSquad = await _fetchTeamRosterFull(teamId, leagueCode);
    }

    finalSquad = await _enrichRosterHeadshots(finalSquad, primaryLeague,
        teamId: teamId);

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

  // ══════════════════════════════════════════════════════════════════════════════
  // WORLD CUP SPECIFIC METHODS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<_ScheduleResult> _fetchWorldCupFixtures(String teamId) async {
    print('[WorldCup] Fetching World Cup 2026 fixtures for team: $teamId');

    final now = DateTime.now();
    final tournamentStart = DateTime(2026, 6, 11);
    final tournamentEnd = DateTime(2026, 7, 19);

    final startDate = now.isBefore(tournamentStart)
        ? tournamentStart
        : tournamentStart;

    final endDate = now.isAfter(tournamentEnd)
        ? tournamentEnd
        : tournamentEnd;

    print('[WorldCup] Fetching matches from ${_fmt(startDate)} to ${_fmt(endDate)}');

    final allMatches = await _fetchAllLeaguesForLocalDayRange(
        startDate,
        endDate,
        ['fifa.world']
    );

    print('[WorldCup] Found ${allMatches.length} World Cup matches in date range');

    final List<TeamRecentMatch> recentMatches = [];
    final List<String> recentEventIds = [];
    final List<TeamUpcomingFixture> upcoming = [];

    for (final game in allMatches) {
      if (game.awayTeam.id != teamId && game.homeTeam.id != teamId) continue;

      final isHome = game.homeTeam.id == teamId;
      final opponent = isHome ? game.awayTeam : game.homeTeam;
      final gameDate = DateTime.tryParse(game.date);

      if (game.status == 'STATUS_FINAL' || game.status == 'STATUS_LIVE') {
        final myScore = int.tryParse(isHome ? game.homeScore : game.awayScore) ?? 0;
        final oppScore = int.tryParse(isHome ? game.awayScore : game.homeScore) ?? 0;

        String result;
        if (myScore > oppScore) result = 'win';
        else if (myScore < oppScore) result = 'loss';
        else result = 'draw';

        recentMatches.add(TeamRecentMatch(
          opponentId: opponent.id,
          opponentName: opponent.displayName,
          opponentLogo: opponent.logo.isNotEmpty ? opponent.logo : 'https://a.espncdn.com/i/teamlogos/soccer/500/${opponent.id}.png',
          opponentAbbr: opponent.abbreviation,
          score: '$myScore-$oppScore',
          result: result,
          date: game.date,
          competition: 'FIFA World Cup 2026',
          leagueFlag: '🏆',
          isHome: isHome,
          goalsFor: myScore,
          goalsAgainst: oppScore,
          yellowCards: 0,
          redCards: 0,
          possession: null,
          shots: null,
          shotsOnTarget: null,
        ));
        recentEventIds.add(game.id);
      } else if (game.status == 'STATUS_SCHEDULED' && gameDate != null && gameDate.isAfter(now)) {
        upcoming.add(TeamUpcomingFixture(
          opponentId: opponent.id,
          opponentName: opponent.displayName,
          opponentLogo: opponent.logo.isNotEmpty ? opponent.logo : 'https://a.espncdn.com/i/teamlogos/soccer/500/${opponent.id}.png',
          opponentAbbr: opponent.abbreviation,
          competition: 'FIFA World Cup 2026',
          leagueFlag: '🏆',
          date: game.date,
          isHome: isHome,
        ));
      }
    }

    recentMatches.sort((a, b) => b.date.compareTo(a.date));
    upcoming.sort((a, b) => a.date.compareTo(b.date));

    print('[WorldCup] Found ${recentMatches.length} recent matches and ${upcoming.length} upcoming matches');

    return _ScheduleResult(
      recentMatches: recentMatches.take(5).toList(),
      upcoming: upcoming.take(5).toList(),
      recentMatchEventIds: recentEventIds.take(5).toList(),
      headCoach: null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER METHODS FOR INTERNATIONAL FALLBACK
  // ══════════════════════════════════════════════════════════════════════════════

  Future<List<TeamUpcomingFixture>> _fetchUpcomingFromAllLeagues(
      String teamId, List<String> leagueCodes) async {
    final allUpcoming = <TeamUpcomingFixture>[];
    final now = DateTime.now();

    for (final code in leagueCodes) {
      try {
        final result = await _fetchTeamSchedule(teamId, code);
        for (final fixture in result.upcoming) {
          try {
            final fixtureDate = DateTime.parse(fixture.date);
            if (fixtureDate.isAfter(now)) {
              allUpcoming.add(fixture);
            }
          } catch (_) {}
        }
        if (allUpcoming.length >= 5) break;
      } catch (e) {
        print('[NationalTeam] Error fetching upcoming from $code: $e');
      }
    }

    allUpcoming.sort((a, b) => a.date.compareTo(b.date));
    return allUpcoming.take(5).toList();
  }

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

  // ══════════════════════════════════════════════════════════════════════════════
  // CORE TEAM SCHEDULE METHODS
  // ══════════════════════════════════════════════════════════════════════════════

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

  Future<_ScheduleResult> _fetchTeamScheduleForYear(
      String teamId, String leagueCode, int year) async {
    String url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId/schedule?season=$year';
    print('[TeamPage] Fetching schedule for year $year: $url');

    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final events = data['events'] as List? ?? [];

        if (events.isNotEmpty) {
          return _parseTeamSchedule(data, leagueCode, teamId);
        }
      }
    } catch (e) {
      print('[TeamPage] Schedule error for year $year: $e');
    }

    if (year == DateTime.now().year) {
      url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId/schedule';
      try {
        final res = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          return _parseTeamSchedule(data, leagueCode, teamId);
        }
      } catch (e) {
        print('[TeamPage] Fallback schedule error: $e');
      }
    }

    return _ScheduleResult.empty();
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
        final eventDate = DateTime.tryParse(event['date']?.toString() ?? '');

        if (eventDate != null) {
          print('[TeamPage] Event ${event['id']}: status=$normStatus, date=${eventDate.toLocal()}, isAfterNow=${eventDate.isAfter(now)}');
        }

        if (normStatus == 'STATUS_FINAL' || normStatus == 'STATUS_LIVE') {
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
            opponentId: oppData['team']?['id']?.toString() ?? '',
            opponentName: oppData['team']?['displayName']?.toString() ??
                oppData['team']?['name']?.toString() ?? 'Unknown',
            opponentLogo: _resolveTeamLogo(oppData['team'] ?? {}),
            opponentAbbr: oppData['team']?['abbreviation']?.toString() ?? '',
            score: '$myScore-$oppScore',
            result: result,
            date: event['date']?.toString() ?? '',
            competition: leagueEntry['name'] ?? leagueCode,
            leagueFlag: leagueEntry['flag'] ?? '⚽',
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
        } else if (normStatus == 'STATUS_SCHEDULED' && eventDate != null && eventDate.isAfter(now)) {
          final opponentId = oppData['team']?['id']?.toString() ?? '';
          final opponentName = oppData['team']?['displayName']?.toString() ??
              oppData['team']?['name']?.toString() ?? 'Unknown';
          final opponentAbbr = oppData['team']?['abbreviation']?.toString() ?? '';
          final opponentLogo = _resolveTeamLogo(oppData['team'] ?? {});

          final exists = upcoming.any((f) =>
          f.opponentId == opponentId &&
              f.date == event['date']?.toString() &&
              f.competition == leagueEntry['name']);

          if (!exists) {
            upcoming.add(TeamUpcomingFixture(
              opponentId: opponentId,
              opponentName: opponentName,
              opponentLogo: opponentLogo,
              opponentAbbr: opponentAbbr,
              competition: leagueEntry['name'] ?? leagueCode,
              leagueFlag: leagueEntry['flag'] ?? '⚽',
              date: event['date']?.toString() ?? '',
              isHome: isHome,
            ));
            print('[TeamPage] ✅ Added upcoming fixture: $opponentName on ${event['date']}');
          }
        } else if (eventDate != null && eventDate.isAfter(now) && normStatus != 'STATUS_FINAL') {
          final opponentId = oppData['team']?['id']?.toString() ?? '';
          final opponentName = oppData['team']?['displayName']?.toString() ??
              oppData['team']?['name']?.toString() ?? 'Unknown';
          final opponentAbbr = oppData['team']?['abbreviation']?.toString() ?? '';
          final opponentLogo = _resolveTeamLogo(oppData['team'] ?? {});

          final exists = upcoming.any((f) =>
          f.opponentId == opponentId &&
              f.date == event['date']?.toString());

          if (!exists) {
            print('[TeamPage] ⚠️ Fallback: Adding future event with status "$normStatus" as upcoming');
            upcoming.add(TeamUpcomingFixture(
              opponentId: opponentId,
              opponentName: opponentName,
              opponentLogo: opponentLogo,
              opponentAbbr: opponentAbbr,
              competition: leagueEntry['name'] ?? leagueCode,
              leagueFlag: leagueEntry['flag'] ?? '⚽',
              date: event['date']?.toString() ?? '',
              isHome: isHome,
            ));
          }
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

  // ══════════════════════════════════════════════════════════════════════════════
  // ROSTER & SQUAD METHODS
  // ══════════════════════════════════════════════════════════════════════════════

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

      final cachedHeadshots =
      await _cache.getCachedSquadHeadshots(teamId);

      final List<TeamSquadPlayer> players = [];
      for (final a in athletes) {
        String playerId = a['id']?.toString() ?? '';

        if (playerId.isEmpty) {
          final ref = a['\$ref']?.toString() ?? '';
          if (ref.isNotEmpty) {
            final match = RegExp(r'/athletes/(\d+)').firstMatch(ref);
            if (match != null) playerId = match.group(1)!;
          }
        }

        if (playerId.isEmpty) continue;

        String headshot = '';

        final links = a['links'] as List? ?? [];
        for (final link in links) {
          if (link is! Map) continue;
          final rels = (link['rel'] as List? ?? [])
              .map((r) => r.toString().toLowerCase())
              .toList();
          if (rels.contains('photo') ||
              rels.contains('headshot') ||
              rels.contains('athlete-headshot') ||
              (rels.contains('athlete') && rels.contains('desktop')) ||
              (rels.contains('athlete') && rels.contains('image'))) {
            headshot = link['href']?.toString() ?? '';
            if (headshot.isNotEmpty) break;
          }
        }

        if (headshot.isEmpty) {
          final hs = a['headshot'];
          if (hs is String && hs.isNotEmpty) {
            headshot = hs;
          } else if (hs is Map) {
            headshot = hs['href']?.toString() ?? '';
            if (headshot.isEmpty) {
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

        final posAbbr =
        (a['position']?['abbreviation'] ?? a['position'] ?? '').toString();
        final posName =
        (a['position']?['name'] ?? a['position']?['displayName'] ?? '')
            .toString()
            .toLowerCase();
        final cat = _positionCategory(posAbbr, posName);

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

      if (cachedHeadshots != null && players.isNotEmpty) {
        final hits = players.where((p) => (cachedHeadshots[p.id] ?? '').isNotEmpty).length;
        final hitRate = hits / players.length;

        if (hitRate >= 0.6) {
          final merged = players.map((p) {
            final cached = cachedHeadshots[p.id] ?? '';
            final url = cached.isNotEmpty ? cached : p.headshotUrl;
            if (url == p.headshotUrl) return p;
            return TeamSquadPlayer(
              id: p.id,
              name: p.name,
              jersey: p.jersey,
              position: p.position,
              positionCategory: p.positionCategory,
              nationality: p.nationality,
              age: p.age,
              headshotUrl: url,
              rating: p.rating,
            );
          }).toList();

          print('[TeamPage] ✅ Headshot cache HIT — '
              '$hits/${players.length} players have photos (${(hitRate * 100).toStringAsFixed(0)}%, skipping enrichment)');
          return merged;
        } else {
          print('[TeamPage] ⚠️ Headshot cache STALE/POOR — '
              'only $hits/${players.length} players have photos (${(hitRate * 100).toStringAsFixed(0)}%, '
              're-running enrichment instead of trusting cache)');
          for (int i = 0; i < players.length; i++) {
            final cached = cachedHeadshots[players[i].id] ?? '';
            if (cached.isNotEmpty && players[i].headshotUrl.isEmpty) {
              players[i] = TeamSquadPlayer(
                id: players[i].id,
                name: players[i].name,
                jersey: players[i].jersey,
                position: players[i].position,
                positionCategory: players[i].positionCategory,
                nationality: players[i].nationality,
                age: players[i].age,
                headshotUrl: cached,
                rating: players[i].rating,
              );
            }
          }
        }
      }

      return players;
    } catch (e) {
      print('[TeamPage] Roster error: $e');
      return [];
    }
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

  Future<List<TeamSquadPlayer>> _enrichRosterHeadshots(
      List<TeamSquadPlayer> players, String leagueCode,
      {required String teamId}) async {
    if (players.isEmpty) return players;

    final headers = {
      ..._headers,
      'Referer': 'https://www.espn.com/',
      'Origin':  'https://www.espn.com',
    };

    final enriched = <String, String>{
      for (final p in players) p.id: p.headshotUrl,
    };

    final missing = players
        .where((p) => p.id.isNotEmpty && p.headshotUrl.isEmpty)
        .toList();

    print('[Headshot] ${players.length} total players, ${missing.length} missing headshots');

    final Map<String, String> bulkHeadshots = {};
    if (missing.isNotEmpty) {
      try {
        final bulkUrl =
            'https://sports.core.api.espn.com/v3/sports/soccer/'
            '$leagueCode/athletes?limit=200&active=true';
        final res = await _client
            .get(Uri.parse(bulkUrl), headers: headers)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final items = data['athletes'] as List? ?? data['items'] as List? ?? [];
          for (final item in items) {
            if (item is! Map) continue;
            final athleteData = item as Map<String, dynamic>;
            final id = athleteData['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final found = _extractHeadshotFromAthleteData(athleteData);
            if (found != null && found.isNotEmpty) {
              bulkHeadshots[id] = found;
            }
          }
          print('[Headshot] Bulk v3 lookup: ${bulkHeadshots.length} headshots available');
        }
      } catch (e) {
        print('[Headshot] Bulk v3 lookup failed (non-fatal): $e');
      }
    }

    const batchSize = 10;
    for (int i = 0; i < missing.length; i += batchSize) {
      final batch = missing.sublist(i, (i + batchSize).clamp(0, missing.length));

      await Future.wait(batch.map((player) async {
        final pid = player.id;

        final bulkMatch = bulkHeadshots[pid];
        if (bulkMatch != null && bulkMatch.isNotEmpty) {
          enriched[pid] = bulkMatch;
          return;
        }

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
        } catch (_) {}

        try {
          final webUrl =
              'https://site.web.api.espn.com/apis/common/v3/sports/soccer/'
              '$leagueCode/athletes/$pid';
          final res = await _client
              .get(Uri.parse(webUrl), headers: headers)
              .timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            final athleteData = data['athlete'] is Map
                ? data['athlete'] as Map<String, dynamic>
                : data;
            final found = _extractHeadshotFromAthleteData(athleteData);
            if (found != null && found.isNotEmpty) {
              enriched[pid] = found;
              return;
            }
          }
        } catch (_) {}

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
        } catch (_) {}
      }));
    }

    final gotHeadshot = enriched.values.where((v) => v.isNotEmpty).length;
    print('[Headshot] Enrichment complete: $gotHeadshot/${players.length} have URLs');

    try {
      await _cache.cacheSquadHeadshots(teamId, Map<String, String>.from(enriched));
    } catch (e) {
      print('[Headshot] Failed to persist headshot cache: $e');
    }

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



  Future<String?> _fetchTeamCoach(String teamId, String leagueCode) async {
    try {
      final url = '${AppConstants.baseUrl}/$leagueCode/teams/$teamId';
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final teamData = data['team'] as Map<String, dynamic>?;
        if (teamData != null) {
          final coaches = teamData['coaches'] as List?;
          if (coaches != null && coaches.isNotEmpty) {
            return coaches.first['fullName']?.toString();
          }
        }
      }
    } catch (e) {
      print('[TeamPage] Error fetching coach: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STANDING & ANALYTICS METHODS
  // ══════════════════════════════════════════════════════════════════════════════

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

    final totalSot   = sotN > 0 ? sotSum : (shotsN > 0 ? shotsSum : null);
    final avgSot     = sotN > 0 ? sotSum / sotN : null;

    final conv = totalSot != null && totalSot > 0
        ? gf / totalSot
        : null;

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
      avgShotsPerGame: avgShots ?? effectiveShotsPerGame,
      avgShotsOnTarget: totalSot,
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

  // ══════════════════════════════════════════════════════════════════════════════
  // EXTRA HELPER METHODS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<List<Game>> _fetchAllLeaguesForLocalDayRange(
      DateTime startDate,
      DateTime endDate,
      List<String> leagueCodes,
      ) async {
    print('[API] Fetching matches from ${_fmt(startDate)} to ${_fmt(endDate)} for ${leagueCodes.length} leagues');

    final leagues = AppConstants.allLeagues
        .where((l) => leagueCodes.contains(l['code']))
        .toList();

    if (leagues.isEmpty) {
      for (final code in leagueCodes) {
        leagues.add({'code': code, 'name': code, 'flag': '⚽'});
      }
    }

    final allGames = <Game>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final games = await _fetchAllLeaguesForLocalDay(current, leagues);
      allGames.addAll(games);
      current = current.add(const Duration(days: 1));
    }

    final seen = <String>{};
    final unique = <Game>[];
    for (final g in allGames) {
      if (seen.add(g.id)) unique.add(g);
    }

    print('[API] Found ${unique.length} unique matches in date range');
    return unique;
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
}