import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/league_leader_model.dart';
import 'package:livescore/services/sportsdb_service.dart';
import 'package:livescore/services/api_service.dart';

import '../models/search_model.dart';
import '../models/team_model.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
// Premium, minimalist palette — primary GREEN, secondary BLUE.
class _C {
  // Primary — brand green. Used for selection states, primary buttons,
  // positive stats and the dominant World Cup accent.
  static const primary      = Color(0xFF0E9F6E);
  static const primaryDark  = Color(0xFF0A7A55);
  static const primaryLight = Color(0xFFE3F6EC);

  // Secondary — accent blue. Used sparingly for contrast (table headers,
  // the Top Scorer card, a handful of secondary highlights).
  static const secondary      = Color(0xFF2A63E4);
  static const secondaryDark  = Color(0xFF17408F);
  static const secondaryLight = Color(0xFFE9F0FE);

  // Neutrals
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF6F9F8);
  static const border    = Color(0xFFE3E9E6);
  static const text      = Color(0xFF10201A);
  static const muted     = Color(0xFF67766F);

  // Status
  static const red   = Color(0xFFDC3545);
  static const amber = Color(0xFFC98A1B);

  // Medal accents — reserved strictly for rank badges (1st/2nd/3rd), never
  // used as a general brand color.
  static const gold   = Color(0xFFC9A227);
  static const silver = Color(0xFF93A0AA);
  static const bronze = Color(0xFFB0703A);
}

class StandingsScreen extends StatefulWidget {
  /// Optional league code to open the standings screen directly on
  /// (e.g. 'uefa.champions'). Defaults to the FIFA World Cup view when
  /// not provided, preserving existing behaviour.
  final String? initialLeagueCode;

  const StandingsScreen({super.key, this.initialLeagueCode});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  late String _selectedLeagueCode =
      widget.initialLeagueCode ?? 'fifa.world';
  String _selectedSeason = AppConstants.standingsSeasons.first['value']!;

  bool _isLoading = false;
  List<Standing> _standings = [];
  LeagueLeaders _leaders = LeagueLeaders.empty;
  bool _isLoadingLeaders = false;
  String? _error;

  String _selectedGroup = 'All';
  List<String> _groups = ['All'];

  // ─── FIFA World Cup 2026 — Final Tournament Stat Leaders ──────────────────
  // Sourced from FIFA's official tournament statistics at the close of the
  // competition. Enriched with SportsDB headshots at load time.
  final List<Map<String, dynamic>> _worldCupTopScorers = [
    {'name': 'Kylian Mbappé', 'goals': 10, 'team': 'France'},
    {'name': 'Lionel Messi', 'goals': 8, 'team': 'Argentina'},
    {'name': 'Jude Bellingham', 'goals': 7, 'team': 'England'},
    {'name': 'Erling Haaland', 'goals': 7, 'team': 'Norway'},
    {'name': 'Ousmane Dembélé', 'goals': 6, 'team': 'France'},
  ];

  final List<Map<String, dynamic>> _worldCupTopAssists = [
    {'name': 'Michael Olise', 'assists': 7, 'team': 'France'},
    {'name': 'Bruno Guimarães', 'assists': 4, 'team': 'Brazil'},
    {'name': 'Martin Ødegaard', 'assists': 4, 'team': 'Norway'},
    {'name': 'Kylian Mbappé', 'assists': 4, 'team': 'France'},
    {'name': 'Brahim Díaz', 'assists': 4, 'team': 'Morocco'},
  ];

  final List<Map<String, dynamic>> _worldCupMostYellowCards = [
    {'name': 'Issa Diop', 'cards': 3, 'team': 'Morocco'},
    {'name': 'Mohanad Lashin', 'cards': 2, 'team': 'Egypt'},
    {'name': 'Marawan Attia', 'cards': 2, 'team': 'Egypt'},
    {'name': 'Luc De Fougerolles', 'cards': 2, 'team': 'Canada'},
    {'name': 'Haissem Hassan', 'cards': 2, 'team': 'Egypt'},
  ];

  final List<Map<String, dynamic>> _worldCupMostRedCards = [
    {'name': 'Jarell Quansah', 'cards': 1, 'team': 'England'},
    {'name': 'Nathan Ngoy', 'cards': 1, 'team': 'Belgium'},
    {'name': 'Tarik Muharemovic', 'cards': 1, 'team': 'Bosnia & Herzegovina'},
    {'name': 'Agustín Canobbio', 'cards': 1, 'team': 'Uruguay'},
    {'name': 'Piero Hincapié', 'cards': 1, 'team': 'Ecuador'},
  ];

  // In-memory cache for SportsDB headshots so we don't re-fetch a player
  // that appears in more than one leaderboard (e.g. Mbappé).
  final Map<String, String> _headshotCache = {};

  // ─── FIFA World Cup 2026 — Final Standings ─────────────────────────────────
  // Built directly from the official final tournament table (rank, team,
  // MP, W, D, L, GF, GA, GD, PTS). The tournament is complete, so this is
  // static data rather than a live API fetch — every row here mirrors the
  // attached results CSV exactly. `iso` is the ISO 3166-1 alpha-2 code used
  // to pull each nation's flag as its "team crest".
  static const List<Map<String, dynamic>> _worldCup2026Table = [
    {'rank': 1,  'team': 'Spain',                 'iso': 'es',    'mp': 8, 'w': 7, 'd': 1, 'l': 0, 'gf': 16, 'ga': 2,  'pts': 22},
    {'rank': 2,  'team': 'Argentina',              'iso': 'ar',    'mp': 8, 'w': 6, 'd': 0, 'l': 2, 'gf': 19, 'ga': 8,  'pts': 18},
    {'rank': 3,  'team': 'England',                'iso': 'gb-eng','mp': 8, 'w': 6, 'd': 1, 'l': 1, 'gf': 22, 'ga': 14, 'pts': 19},
    {'rank': 4,  'team': 'France',                 'iso': 'fr',    'mp': 8, 'w': 5, 'd': 0, 'l': 3, 'gf': 19, 'ga': 11, 'pts': 15},
    {'rank': 5,  'team': 'Morocco',                'iso': 'ma',    'mp': 5, 'w': 3, 'd': 2, 'l': 0, 'gf': 10, 'ga': 5,  'pts': 11},
    {'rank': 6,  'team': 'Norway',                 'iso': 'no',    'mp': 5, 'w': 3, 'd': 1, 'l': 1, 'gf': 12, 'ga': 11, 'pts': 10},
    {'rank': 7,  'team': 'Switzerland',             'iso': 'ch',    'mp': 5, 'w': 3, 'd': 1, 'l': 1, 'gf': 10, 'ga': 7,  'pts': 10},
    {'rank': 8,  'team': 'Belgium',                 'iso': 'be',    'mp': 5, 'w': 2, 'd': 2, 'l': 1, 'gf': 9,  'ga': 6,  'pts': 8},
    {'rank': 9,  'team': 'Mexico',                  'iso': 'mx',    'mp': 4, 'w': 3, 'd': 0, 'l': 1, 'gf': 7,  'ga': 2,  'pts': 9},
    {'rank': 10, 'team': 'Netherlands',              'iso': 'nl',    'mp': 4, 'w': 2, 'd': 1, 'l': 1, 'gf': 11, 'ga': 6,  'pts': 7},
    {'rank': 11, 'team': 'Brazil',                   'iso': 'br',    'mp': 4, 'w': 2, 'd': 1, 'l': 1, 'gf': 8,  'ga': 3,  'pts': 7},
    {'rank': 12, 'team': 'Colombia',                 'iso': 'co',    'mp': 4, 'w': 2, 'd': 1, 'l': 1, 'gf': 5,  'ga': 3,  'pts': 7},
    {'rank': 13, 'team': 'United States',            'iso': 'us',    'mp': 4, 'w': 2, 'd': 0, 'l': 2, 'gf': 9,  'ga': 6,  'pts': 6},
    {'rank': 14, 'team': 'Canada',                   'iso': 'ca',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 9,  'ga': 5,  'pts': 4},
    {'rank': 15, 'team': 'Japan',                    'iso': 'jp',    'mp': 4, 'w': 1, 'd': 2, 'l': 1, 'gf': 8,  'ga': 5,  'pts': 5},
    {'rank': 16, 'team': 'Paraguay',                 'iso': 'py',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 3,  'ga': 6,  'pts': 4},
    {'rank': 17, 'team': 'Germany',                  'iso': 'de',    'mp': 4, 'w': 2, 'd': 0, 'l': 2, 'gf': 11, 'ga': 6,  'pts': 6},
    {'rank': 18, 'team': 'Croatia',                  'iso': 'hr',    'mp': 4, 'w': 2, 'd': 0, 'l': 2, 'gf': 6,  'ga': 7,  'pts': 6},
    {'rank': 19, 'team': 'Ivory Coast',               'iso': 'ci',    'mp': 4, 'w': 2, 'd': 0, 'l': 2, 'gf': 5,  'ga': 4,  'pts': 6},
    {'rank': 20, 'team': 'Portugal',                  'iso': 'pt',    'mp': 4, 'w': 1, 'd': 2, 'l': 1, 'gf': 7,  'ga': 3,  'pts': 5},
    {'rank': 21, 'team': 'Egypt',                     'iso': 'eg',    'mp': 4, 'w': 1, 'd': 2, 'l': 1, 'gf': 6,  'ga': 5,  'pts': 5},
    {'rank': 22, 'team': 'Australia',                 'iso': 'au',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 2,  'ga': 4,  'pts': 4},
    {'rank': 23, 'team': 'South Africa',              'iso': 'za',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 3,  'ga': 5,  'pts': 4},
    {'rank': 24, 'team': 'Bosnia & Herzegovina',      'iso': 'ba',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 6,  'ga': 8,  'pts': 4},
    {'rank': 25, 'team': 'DR Congo',                  'iso': 'cd',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 5,  'ga': 5,  'pts': 4},
    {'rank': 26, 'team': 'Sweden',                    'iso': 'se',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 8,  'ga': 9,  'pts': 4},
    {'rank': 27, 'team': 'Ecuador',                   'iso': 'ec',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 3,  'ga': 4,  'pts': 4},
    {'rank': 28, 'team': 'Austria',                   'iso': 'at',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 7,  'ga': 8,  'pts': 4},
    {'rank': 29, 'team': 'Algeria',                   'iso': 'dz',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 6,  'ga': 9,  'pts': 4},
    {'rank': 30, 'team': 'Ghana',                     'iso': 'gh',    'mp': 4, 'w': 1, 'd': 1, 'l': 2, 'gf': 3,  'ga': 4,  'pts': 4},
    {'rank': 31, 'team': 'Cabo Verde',                'iso': 'cv',    'mp': 4, 'w': 0, 'd': 3, 'l': 1, 'gf': 3,  'ga': 4,  'pts': 3},
    {'rank': 32, 'team': 'Senegal',                   'iso': 'sn',    'mp': 4, 'w': 1, 'd': 0, 'l': 3, 'gf': 9,  'ga': 8,  'pts': 3},
    {'rank': 33, 'team': 'Iran',                      'iso': 'ir',    'mp': 3, 'w': 0, 'd': 3, 'l': 0, 'gf': 3,  'ga': 3,  'pts': 3},
    {'rank': 34, 'team': 'Scotland',                  'iso': 'gb-sct','mp': 3, 'w': 1, 'd': 0, 'l': 2, 'gf': 1,  'ga': 4,  'pts': 3},
    {'rank': 35, 'team': 'South Korea',                'iso': 'kr',    'mp': 3, 'w': 1, 'd': 0, 'l': 2, 'gf': 2,  'ga': 3,  'pts': 3},
    {'rank': 36, 'team': 'Türkiye',                    'iso': 'tr',    'mp': 3, 'w': 1, 'd': 0, 'l': 2, 'gf': 3,  'ga': 5,  'pts': 3},
    {'rank': 37, 'team': 'Uruguay',                    'iso': 'uy',    'mp': 3, 'w': 0, 'd': 2, 'l': 1, 'gf': 3,  'ga': 4,  'pts': 2},
    {'rank': 38, 'team': 'Saudi Arabia',                'iso': 'sa',    'mp': 3, 'w': 0, 'd': 2, 'l': 1, 'gf': 1,  'ga': 5,  'pts': 2},
    {'rank': 39, 'team': 'Czech Republic',              'iso': 'cz',    'mp': 3, 'w': 0, 'd': 1, 'l': 2, 'gf': 2,  'ga': 6,  'pts': 1},
    {'rank': 40, 'team': 'Qatar',                       'iso': 'qa',    'mp': 3, 'w': 0, 'd': 1, 'l': 2, 'gf': 2,  'ga': 10, 'pts': 1},
    {'rank': 41, 'team': 'Curaçao',                     'iso': 'cw',    'mp': 3, 'w': 0, 'd': 1, 'l': 2, 'gf': 1,  'ga': 9,  'pts': 1},
    {'rank': 42, 'team': 'New Zealand',                 'iso': 'nz',    'mp': 3, 'w': 0, 'd': 1, 'l': 2, 'gf': 4,  'ga': 10, 'pts': 1},
    {'rank': 43, 'team': 'Panama',                      'iso': 'pa',    'mp': 3, 'w': 0, 'd': 0, 'l': 3, 'gf': 0,  'ga': 4,  'pts': 0},
    {'rank': 44, 'team': 'Jordan',                      'iso': 'jo',    'mp': 3, 'w': 0, 'd': 0, 'l': 3, 'gf': 3,  'ga': 8,  'pts': 0},
    {'rank': 45, 'team': 'Haiti',                       'iso': 'ht',    'mp': 3, 'w': 0, 'd': 0, 'l': 3, 'gf': 2,  'ga': 8,  'pts': 0},
    {'rank': 46, 'team': 'Uzbekistan',                  'iso': 'uz',    'mp': 3, 'w': 0, 'd': 0, 'l': 3, 'gf': 2,  'ga': 11, 'pts': 0},
    {'rank': 47, 'team': 'Tunisia',                     'iso': 'tn',    'mp': 3, 'w': 0, 'd': 0, 'l': 3, 'gf': 2,  'ga': 12, 'pts': 0},
    {'rank': 48, 'team': 'Iraq',                        'iso': 'iq',    'mp': 3, 'w': 0, 'd': 0, 'l': 3, 'gf': 1,  'ga': 12, 'pts': 0},
  ];

  /// Tournament stage label for a given final rank, used to power the
  /// group filter chips for the World Cup table (Champion, Runner-up, ...).
  static String _stageForRank(int rank) {
    if (rank == 1) return 'Champion';
    if (rank == 2) return 'Runner-up';
    if (rank <= 4) return 'Semi-finalists';
    if (rank <= 8) return 'Quarter-finalists';
    if (rank <= 16) return 'Round of 16';
    if (rank <= 32) return 'Round of 32';
    return 'Group Stage';
  }

  static const List<String> _stageOrder = [
    'Champion', 'Runner-up', 'Semi-finalists', 'Quarter-finalists',
    'Round of 16', 'Round of 32', 'Group Stage',
  ];

  List<Standing> _buildWorldCupStandings() {
    return _worldCup2026Table.map((row) {
      final rank = row['rank'] as int;
      final team = row['team'] as String;
      final iso = row['iso'] as String;
      final wins = row['w'] as int;
      final draws = row['d'] as int;
      final losses = row['l'] as int;
      final mp = row['mp'] as int;
      final gf = row['gf'] as int;
      final ga = row['ga'] as int;
      final gd = gf - ga;
      final pts = row['pts'] as int;

      return Standing(
        rank: rank,
        team: TeamInfo(
          id: 'wc26-$iso',
          name: team,
          displayName: team,
          abbreviation: team.length >= 3 ? team.substring(0, 3).toUpperCase() : team.toUpperCase(),
          logo: 'https://flagcdn.com/w160/$iso.png',
          color: '#0E9F6E',
          alternateColor: '#2A63E4',
          record: '$wins-$losses-$draws',
        ),
        wins: '$wins',
        losses: '$losses',
        ties: '$draws',
        winPercentage: mp > 0 ? ((wins / mp) * 100).toStringAsFixed(1) : '0.0',
        pointsFor: '$gf',
        pointsAgainst: '$ga',
        streak: '',
        clinchedPlayoffs: rank <= 4,
        conference: _stageForRank(rank),
        division: '',
        stats: const {},
        points: pts,
        goalsFor: gf,
        goalsAgainst: ga,
        goalDifference: gd,
        matchesPlayed: mp,
      );
    }).toList();
  }

  static List<Map<String, String>> _buildLeagueStrip() {
    final all = List<Map<String, String>>.from(AppConstants.allLeagues);

    final removeCodes = {
      'fin.1', 'isl.1', 'cze.1', 'pol.1', 'cro.1', 'ukr.1',
      'hun.1', 'svk.1', 'cyp.1', 'kr.1', 'egy.1', 'fifa.friendly',
      'conmebol.america', 'uefa.euro', 'uefa.nations',
    };

    all.removeWhere((league) => removeCodes.contains(league['code']));

    final keepCodes = {
      'fifa.world', 'eng.1', 'esp.1', 'ita.1', 'ger.1', 'fra.1',
      'por.1', 'ned.1', 'tur.1', 'bel.1', 'sco.1',
      'aut.1', 'sui.1', 'bra.1', 'usa.1', 'mex.1',
      'arg.1', 'jpn.1', 'swe.1', 'nor.1', 'den.1',
      'eng.2', 'eng.3', 'eng.4', 'isr.1', 'rus.1',
      'rou.1', 'chn.1', 'ind.1', 'tha.1', 'aus.1',
      'rsa.1', 'uefa.champions', 'uefa.europa', 'uefa.conference',
      'conmebol.libertadores', 'conmebol.sudamericana',
      'concacaf.champions', 'afc.champions', 'caf.champions',
      'fifa.clubworld', 'fifa.worldq.uefa', 'fifa.worldq.conmebol',
      'fifa.worldq.afc', 'fifa.worldq.caf', 'fifa.worldq.concacaf',
      'concacaf.gold', 'afc.cup', 'caf.nations', 'ofc.nations',
    };

    all.retainWhere((league) => keepCodes.contains(league['code']));

    final wcIndex = all.indexWhere((l) => l['code'] == 'fifa.world');
    if (wcIndex > 0) {
      final wc = all.removeAt(wcIndex);
      all.insert(0, wc);
    }

    return all;
  }

  final List<Map<String, String>> _leagues = _buildLeagueStrip();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  bool _isWorldCup() => _selectedLeagueCode == 'fifa.world';

  Future<void> _loadAll() async {
    await _loadStandings();
    _loadLeaders();
  }

  Future<void> _loadStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedGroup = 'All';
    });

    // The FIFA World Cup 2026 has concluded — use the final tournament
    // table directly rather than fetching live standings.
    if (_isWorldCup()) {
      final standings = _buildWorldCupStandings();
      final presentStages = standings.map((s) => s.conference).toSet();
      final orderedGroups = _stageOrder.where(presentStages.contains).toList();

      if (!mounted) return;
      setState(() {
        _standings = standings;
        _groups = ['All', ...orderedGroups];
        _isLoading = false;
      });
      return;
    }

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final standings = await provider.fetchStandingsDirect(
        _selectedLeagueCode,
        season: _selectedSeason,
      );

      final groups = standings
          .map((s) => s.conference)
          .where((g) => g.isNotEmpty)
          .toSet()
          .toList();

      if (!mounted) return;
      setState(() {
        _standings = standings;
        _groups = ['All', ...groups];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLeaders() async {
    setState(() {
      _isLoadingLeaders = true;
      _leaders = LeagueLeaders.empty;
    });

    try {
      // For the World Cup, use our verified final tournament leaders,
      // enriched with SportsDB headshots.
      if (_isWorldCup()) {
        final enrichedLeaders = await _enrichWorldCupLeaders();
        if (!mounted) return;
        setState(() {
          _leaders = enrichedLeaders;
          _isLoadingLeaders = false;
        });
        return;
      }

      final provider = Provider.of<AppProvider>(context, listen: false);
      final leaders = await provider.fetchLeagueLeaders(
        _selectedLeagueCode,
        season: _selectedSeason,
      );
      if (!mounted) return;
      setState(() {
        _leaders = leaders;
        _isLoadingLeaders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLeaders = false);
    }
  }

  /// Resolves a headshot for one World Cup leaderboard entry: SportsDB
  /// first (transparent cutout / thumb), falling back to an ESPN search
  /// match, with an in-memory cache so repeat names (e.g. Mbappé appearing
  /// on both the scorers and assists boards) only hit the network once.
  Future<String> _resolveHeadshot(
      String name, SportsDbService sportsDb, ApiService apiService) async {
    if (_headshotCache.containsKey(name)) return _headshotCache[name]!;

    String headshot = '';
    try {
      final playerData = await sportsDb.searchPlayerByName(name);
      if (playerData != null) {
        headshot = playerData['strCutout']?.toString().trim() ?? '';
        if (headshot.isEmpty) {
          headshot = playerData['strThumb']?.toString().trim() ?? '';
        }
      }
    } catch (e) {
      print('[Standings] SportsDB headshot lookup failed for $name: $e');
    }

    if (headshot.isEmpty) {
      try {
        final searchResults = await apiService.search(name);
        final player = searchResults.players.firstWhere(
              (p) => p.displayName.contains(name),
          orElse: () => SearchResult(
            id: '',
            name: name,
            displayName: name,
            type: 'player',
            imageUrl: null,
          ),
        );
        headshot = player.imageUrl ?? '';
      } catch (_) {}
    }

    if (headshot.isNotEmpty) {
      _headshotCache[name] = headshot;
    }
    return headshot;
  }

  Future<LeagueLeaders> _enrichWorldCupLeaders() async {
    final sportsDb = SportsDbService();
    final apiService = ApiService();

    Future<List<LeaderEntry>> enrich(
        List<Map<String, dynamic>> source, String statKey) async {
      final entries = <LeaderEntry>[];
      for (final row in source) {
        final name = row['name'] as String;
        final team = row['team'] as String;
        final headshot = await _resolveHeadshot(name, sportsDb, apiService);
        entries.add(LeaderEntry(
          athleteId: name,
          name: name,
          headshot: headshot,
          teamId: team,
          teamAbbreviation: team.length >= 3 ? team.substring(0, 3).toUpperCase() : team.toUpperCase(),
          teamLogo: '',
          value: (row[statKey] as int).toDouble(),
        ));
      }
      return entries;
    }

    final topScorers = await enrich(_worldCupTopScorers, 'goals');
    final topAssists = await enrich(_worldCupTopAssists, 'assists');
    final topYellowCards = await enrich(_worldCupMostYellowCards, 'cards');
    final topRedCards = await enrich(_worldCupMostRedCards, 'cards');

    return LeagueLeaders(
      topScorers: topScorers,
      topAssists: topAssists,
      mostYellowCards: topYellowCards,
      mostRedCards: topRedCards,
    );
  }

  List<Standing> get _filteredStandings {
    if (_selectedGroup == 'All') return _standings;
    return _standings.where((s) => s.conference == _selectedGroup).toList();
  }

  void _onLeagueChanged(String code) {
    if (code == _selectedLeagueCode) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedLeagueCode = code);
    _loadAll();
  }

  void _onSeasonChanged(String value) {
    if (value == _selectedSeason) return;
    setState(() => _selectedSeason = value);
    _loadAll();
  }

  String _getLeagueName() {
    final league = _leagues.firstWhere(
          (l) => l['code'] == _selectedLeagueCode,
      orElse: () => {'name': 'League'},
    );
    return league['name']!;
  }

  String _seasonLabel() {
    final s = AppConstants.standingsSeasons.firstWhere(
          (s) => s['value'] == _selectedSeason,
      orElse: () => {'label': _selectedSeason},
    );
    return s['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.offWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              leagueName: _getLeagueName(),
              isWorldCup: _isWorldCup(),
              selectedLeagueCode: _selectedLeagueCode,
              selectedSeasonLabel: _seasonLabel(),
              onSeasonTap: _showSeasonPicker,
            ),
            _LeagueSelectorStrip(
              leagues: _leagues,
              selectedCode: _selectedLeagueCode,
              onSelected: _onLeagueChanged,
            ),
            if (_groups.length > 1) _GroupChips(
              groups: _groups,
              selectedGroup: _selectedGroup,
              onSelected: (g) => setState(() => _selectedGroup = g),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  void _showSeasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SeasonPickerSheet(
        selected: _selectedSeason,
        onSelected: (v) {
          Navigator.pop(context);
          _onSeasonChanged(v);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingState();

    if (_error != null && _standings.isEmpty) {
      return _ErrorState(error: _error!, onRetry: _loadAll);
    }

    if (_standings.isEmpty) {
      return const _EmptyState(
        title: 'No standings available',
        subtitle: 'Try a different league or season',
      );
    }

    if (_filteredStandings.isEmpty) {
      return const _EmptyState(
        title: 'No teams in this group',
        subtitle: 'Try a different group filter',
      );
    }

    return RefreshIndicator(
      color: _C.primary,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_isWorldCup())
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'FIFA WORLD CUP 2026 · FINAL STANDINGS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _C.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          _StandingsTable(
            standings: _filteredStandings,
            isWorldCup: _isWorldCup(),
          ),
          const SizedBox(height: 8),
          _LeadersSection(
            leaders: _leaders,
            isLoading: _isLoadingLeaders,
            leagueName: _getLeagueName(),
            isWorldCup: _isWorldCup(),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String leagueName;
  final bool isWorldCup;
  final String selectedLeagueCode;
  final String selectedSeasonLabel;
  final VoidCallback onSeasonTap;

  const _Header({
    required this.leagueName,
    required this.isWorldCup,
    required this.selectedLeagueCode,
    required this.selectedSeasonLabel,
    required this.onSeasonTap,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = AppConstants.leagueLogoUrl(selectedLeagueCode);

    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWorldCup ? _C.primaryLight : _C.secondaryLight,
              border: Border.all(
                color: isWorldCup ? _C.primary : _C.border,
                width: isWorldCup ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: logoUrl != null
                ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(),
              errorWidget: (_, __, ___) =>
                  Icon(Icons.emoji_events_rounded, size: 18, color: isWorldCup ? _C.primary : _C.secondary),
            )
                : Icon(Icons.emoji_events_rounded, size: 18, color: isWorldCup ? _C.primary : _C.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        leagueName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isWorldCup ? 'FINAL TOURNAMENT TABLE' : 'STANDINGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: isWorldCup ? _C.primary : _C.muted,
                  ),
                ),
              ],
            ),
          ),
          if (isWorldCup)
          // The tournament is complete — show a static badge rather than
          // an interactive season selector.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.primary.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 13, color: _C.primary),
                  SizedBox(width: 4),
                  Text(
                    'COMPLETED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _C.primary),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: onSeasonTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.secondaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.secondary.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedSeasonLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.secondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: _C.secondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── League Selector Strip ──────────────────────────────────────────────────

class _LeagueSelectorStrip extends StatelessWidget {
  final List<Map<String, String>> leagues;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const _LeagueSelectorStrip({
    required this.leagues,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: leagues.length,
          separatorBuilder: (_, i) {
            if (i == 0 && leagues[0]['code'] == 'fifa.world') {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: VerticalDivider(width: 20, thickness: 1, color: _C.border),
              );
            }
            return const SizedBox(width: 10);
          },
          itemBuilder: (ctx, i) {
            final league = leagues[i];
            final code = league['code']!;
            final isSelected = code == selectedCode;
            final isWC = code == 'fifa.world';
            final logoUrl = AppConstants.leagueLogoUrl(code);

            return GestureDetector(
              onTap: () => onSelected(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _C.primaryLight : _C.offWhite,
                        border: Border.all(
                          color: isSelected ? _C.primary : _C.border,
                          width: isSelected ? 2 : 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: logoUrl != null
                          ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) =>
                            Icon(Icons.shield_rounded, size: 20, color: _C.muted),
                      )
                          : Icon(Icons.shield_rounded, size: 20, color: _C.muted),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _shortName(league['name']!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _C.primaryDark : _C.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _shortName(String name) {
    if (name.length <= 12) return name;
    return name.split(' ').first;
  }
}

// ─── Season Picker ──────────────────────────────────────────────────────────

class _SeasonPickerSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _SeasonPickerSheet({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('SELECT SEASON',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _C.muted)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: AppConstants.standingsSeasons.map((s) {
                  final isSel = s['value'] == selected;
                  return GestureDetector(
                    onTap: () => onSelected(s['value']!),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSel ? _C.secondaryLight : _C.offWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? _C.secondary : _C.border),
                      ),
                      child: Row(
                        children: [
                          Text(s['label']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? _C.secondary : _C.text,
                              )),
                          const Spacer(),
                          if (isSel) const Icon(Icons.check_circle_rounded, color: _C.secondary, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group Chips ─────────────────────────────────────────────────────────────

class _GroupChips extends StatelessWidget {
  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onSelected;

  const _GroupChips({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      height: 44,
      padding: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final group = groups[i];
          final isSelected = group == selectedGroup;
          return GestureDetector(
            onTap: () => onSelected(group),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _C.primary : _C.offWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? _C.primary : _C.border),
              ),
              child: Text(
                group,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _C.white : _C.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Standings Table ────────────────────────────────────────────────────────

class _StandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool isWorldCup;

  const _StandingsTable({required this.standings, required this.isWorldCup});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(
                  color: _C.secondaryLight,
                  border: Border(bottom: BorderSide(color: _C.border)),
                ),
                child: Row(
                  children: [
                    _headerCell('#', 28),
                    _headerCell('TEAM', 168, alignLeft: true),
                    _headerCell('MP', 36),
                    _headerCell('W', 30),
                    _headerCell('D', 30),
                    _headerCell('L', 30),
                    _headerCell('GF', 36),
                    _headerCell('GA', 36),
                    _headerCell('GD', 40),
                    _headerCell('PTS', 44),
                  ],
                ),
              ),
              // Rows
              ...standings.asMap().entries.map((e) => _row(e.value, e.key)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String text, double width, {bool alignLeft = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: _C.secondaryDark,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _row(Standing s, int index) {
    final isEven = index % 2 == 0;
    final wins = int.tryParse(s.wins) ?? 0;
    final draws = int.tryParse(s.ties) ?? 0;
    final losses = int.tryParse(s.losses) ?? 0;
    final mp = s.matchesPlayed ?? (wins + draws + losses);
    final gf = s.goalsFor ?? 0;
    final ga = s.goalsAgainst ?? 0;
    final gd = s.goalDifference ?? (gf - ga);
    final pts = s.points ?? 0;

    // Medal colors reserved strictly for the top 3 ranks.
    Color rankColor = _C.text;
    if (s.rank == 1) rankColor = _C.gold;
    else if (s.rank == 2) rankColor = _C.silver;
    else if (s.rank == 3) rankColor = _C.bronze;
    else if (s.rank <= 4) rankColor = _C.primary;

    final isTop4 = isWorldCup && s.rank <= 4;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isEven ? _C.white : _C.offWhite.withOpacity(0.6),
        border: const Border(bottom: BorderSide(color: _C.border, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTop4)
                  Container(
                    width: 3,
                    height: 16,
                    color: s.rank == 1 ? _C.gold : (s.rank == 2 ? Colors.grey.shade600 : (s.rank == 3 ? _C.amber : _C.secondary)),
                    margin: const EdgeInsets.only(right: 4),
                  ),
                Flexible(
                  child: Text(
                    '${s.rank}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: rankColor,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
                if (s.rank == 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(Icons.star_rounded, color: _C.gold, size: 10),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 168,
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: const BoxDecoration(color: _C.offWhite, shape: BoxShape.circle),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: s.team.logo.isNotEmpty && s.team.logo.startsWith('http')
                          ? s.team.logo
                          : 'https://a.espncdn.com/i/teamlogos/soccer/500/${s.team.id}.png',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.shield_rounded, size: 16, color: _C.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.team.displayName.isNotEmpty ? s.team.displayName : s.team.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isTop4 ? FontWeight.w800 : FontWeight.w600,
                      color: isTop4 ? _C.primaryDark : _C.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _cell('$mp', 36),
          _cell('$wins', 30, color: _C.primary),
          _cell('$draws', 30, color: _C.amber),
          _cell('$losses', 30, color: _C.red),
          _cell('$gf', 36),
          _cell('$ga', 36),
          _cell(gd > 0 ? '+$gd' : '$gd', 40,
              color: gd > 0 ? _C.primary : (gd < 0 ? _C.red : _C.muted), bold: true),
          SizedBox(
            width: 44,
            child: Text('$pts',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isTop4 ? _C.primaryDark : _C.secondary,
                )),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {Color color = _C.text, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ─── Leaders Section ────────────────────────────────────────────────────────

class _LeadersSection extends StatelessWidget {
  final LeagueLeaders leaders;
  final bool isLoading;
  final String leagueName;
  final bool isWorldCup;

  const _LeadersSection({
    required this.leaders,
    required this.isLoading,
    required this.leagueName,
    required this.isWorldCup,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
          ),
        ),
      );
    }

    if (leaders.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: const [
            Icon(Icons.bar_chart_rounded, size: 18, color: _C.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Stat leaders aren\'t available for this competition yet',
                style: TextStyle(fontSize: 12.5, color: _C.muted),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              isWorldCup ? 'WORLD CUP 2026 · STAT LEADERS' : 'LEAGUE STAT LEADERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isWorldCup ? _C.primary : _C.muted,
              ),
            ),
          ),
          if (leaders.topScorers.isNotEmpty)
            _LeaderCard(
              title: 'Top Scorer',
              icon: Icons.sports_soccer_rounded,
              accent: _C.secondary,
              entries: leaders.topScorers,
              statSuffix: 'G',
              isWorldCup: isWorldCup,
            ),
          if (leaders.topAssists.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LeaderCard(
              title: 'Top Assists',
              icon: Icons.assistant_direction_rounded,
              accent: _C.primary,
              entries: leaders.topAssists,
              statSuffix: 'A',
              isWorldCup: isWorldCup,
            ),
          ],
          if (leaders.mostYellowCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LeaderCard(
              title: 'Most Yellow Cards',
              icon: Icons.square_rounded,
              accent: _C.amber,
              entries: leaders.mostYellowCards,
              statSuffix: '',
              isWorldCup: isWorldCup,
            ),
          ],
          if (leaders.mostRedCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LeaderCard(
              title: 'Most Red Cards',
              icon: Icons.square_rounded,
              accent: _C.red,
              entries: leaders.mostRedCards,
              statSuffix: '',
              isWorldCup: isWorldCup,
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<LeaderEntry> entries;
  final String statSuffix;
  final bool isWorldCup;

  const _LeaderCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.entries,
    required this.statSuffix,
    required this.isWorldCup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _C.text,
                    )),
              ],
            ),
          ),
          ...entries.asMap().entries.map((e) => _leaderRow(e.value, e.key, e.key == entries.length - 1)),
        ],
      ),
    );
  }

  Widget _leaderRow(LeaderEntry entry, int index, bool isLast) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(top: BorderSide(color: _C.border, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: index == 0 ? _C.primary : _C.muted,
                )),
          ),
          Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: _C.offWhite, shape: BoxShape.circle),
            child: ClipOval(
              child: entry.headshot.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: entry.headshot,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(),
                errorWidget: (_, __, ___) =>
                const Icon(Icons.person_rounded, size: 16, color: _C.muted),
              )
                  : const Icon(Icons.person_rounded, size: 16, color: _C.muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name.isNotEmpty ? entry.name : 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
                if (entry.teamAbbreviation.isNotEmpty)
                  Text(
                    entry.teamAbbreviation,
                    style: const TextStyle(fontSize: 10.5, color: _C.muted),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statSuffix.isNotEmpty ? '${entry.value.toInt()} $statSuffix' : '${entry.value.toInt()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _C.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading / Error / Empty States ────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (_, i) => Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _C.border.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: _C.red),
            const SizedBox(height: 14),
            const Text('Couldn\'t load standings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
            const SizedBox(height: 6),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _C.muted)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => onRetry(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: _C.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 40, color: _C.muted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _C.muted)),
          ],
        ),
      ),
    );
  }
}