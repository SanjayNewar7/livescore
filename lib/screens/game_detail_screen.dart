import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/utils/helpers.dart';
import 'package:livescore/utils/theme.dart';
import '../models/team_model.dart';

import 'package:livescore/widgets/football_pitch_lineup.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF0F4FF);
  static const surface   = Color(0xFFFFFFFF);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFDDE3F0);
  static const text      = Color(0xFF0D1B3E);
  static const muted     = Color(0xFF6B7A96);
  static const textWhite = Color(0xFFFFFFFF);
  static const blue      = Color(0xFF1A56DB);
  static const blueSoft  = Color(0xFFEEF4FF);
  static const blueLight = Color(0xFF4A7FE5);
  static const liveRed   = Color(0xFFDC2626);
  static const liveRedBg = Color(0x1ADC2626);
  static const liveGlow  = Color(0x22DC2626);
  static const green     = Color(0xFF16A34A);
  static const yellow    = Color(0xFFCA8A04);
  static const red       = Color(0xFFDC2626);
  static const pitchGreen  = Color(0xFF166534);
  static const pitchLight  = Color(0xFF15803D);
  static const pitchLine   = Color(0x88FFFFFF);
  static const homeAccent  = Color(0xFF1A56DB);
  static const awayAccent  = Color(0xFFEA580C);
  static const purple     = Color(0xFF7C3AED);
  static const pink       = Color(0xFFEC4899);
  static const orange     = Color(0xFFF97316);
  static const teal       = Color(0xFF14B8A6);
  static const indigo     = Color(0xFF4F46E5);
  static const darkSurface = Color(0xFF12141C);
  static const gold       = Color(0xFFD4AF37);
  static const silver     = Color(0xFF9CA3AF);
  static const bronze     = Color(0xFFCD7F32);
}

// ─── Lineup data models ───────────────────────────────────────────────────────
class LineupPlayer {
  final String id;
  final String name;
  final String shortName;
  final String number;
  final String position;
  final bool isStarter;
  final bool isHome;
  final double? rating;
  final String headshot;

  const LineupPlayer({
    required this.id,
    required this.name,
    required this.shortName,
    required this.number,
    required this.position,
    required this.isStarter,
    required this.isHome,
    this.rating,
    this.headshot = '',
  });
}

class MatchLineup {
  final String homeFormation;
  final String awayFormation;
  final List<LineupPlayer> homePlayers;
  final List<LineupPlayer> awayPlayers;

  const MatchLineup({
    required this.homeFormation,
    required this.awayFormation,
    required this.homePlayers,
    required this.awayPlayers,
  });
}

// ─── Analytics Models ─────────────────────────────────────────────────────────
class TeamAnalyticsData {
  final double possession;
  final int totalPasses;
  final int accuratePasses;
  final int totalShots;
  final int shotsOnTarget;
  final int totalCrosses;
  final int accurateCrosses;
  final int yellowCards;
  final int redCards;
  final int saves;
  final int offsides;
  final int fouls;
  final int corners;
  final int goals;
  final double passingAccuracy;
  final double shotAccuracy;
  final double crossAccuracy;

  TeamAnalyticsData({
    this.possession = 0,
    this.totalPasses = 0,
    this.accuratePasses = 0,
    this.totalShots = 0,
    this.shotsOnTarget = 0,
    this.totalCrosses = 0,
    this.accurateCrosses = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.saves = 0,
    this.offsides = 0,
    this.fouls = 0,
    this.corners = 0,
    this.goals = 0,
    this.passingAccuracy = 0,
    this.shotAccuracy = 0,
    this.crossAccuracy = 0,
  });

  factory TeamAnalyticsData.fromStats(Map<String, String> stats) {
    final possession = double.tryParse(stats['possessionPct']?.replaceAll('%', '') ?? '0') ?? 0;
    final totalPasses = int.tryParse(stats['passes'] ?? '0') ?? 0;
    final accuratePasses = int.tryParse(stats['passingAccuracy']?.replaceAll('%', '') ?? '0') ?? 0;
    final totalShots = int.tryParse(stats['totalShots'] ?? '0') ?? 0;
    final shotsOnTarget = int.tryParse(stats['shotsOnTarget'] ?? '0') ?? 0;
    final totalCrosses = int.tryParse(stats['crosses'] ?? '0') ?? 0;
    final accurateCrosses = int.tryParse(stats['accurateCrosses'] ?? '0') ?? 0;
    final yellowCards = int.tryParse(stats['yellowCards'] ?? '0') ?? 0;
    final redCards = int.tryParse(stats['redCards'] ?? '0') ?? 0;
    final saves = int.tryParse(stats['saves'] ?? '0') ?? 0;
    final offsides = int.tryParse(stats['offsides'] ?? '0') ?? 0;
    final fouls = int.tryParse(stats['fouls'] ?? '0') ?? 0;
    final corners = int.tryParse(stats['corners'] ?? '0') ?? 0;
    final goals = int.tryParse(stats['goals'] ?? '0') ?? 0;

    return TeamAnalyticsData(
      possession: possession,
      totalPasses: totalPasses,
      accuratePasses: accuratePasses,
      totalShots: totalShots,
      shotsOnTarget: shotsOnTarget,
      totalCrosses: totalCrosses,
      accurateCrosses: accurateCrosses,
      yellowCards: yellowCards,
      redCards: redCards,
      saves: saves,
      offsides: offsides,
      fouls: fouls,
      corners: corners,
      goals: goals,
      passingAccuracy: totalPasses > 0 ? accuratePasses / totalPasses * 100 : 0,
      shotAccuracy: totalShots > 0 ? shotsOnTarget / totalShots * 100 : 0,
      crossAccuracy: totalCrosses > 0 ? accurateCrosses / totalCrosses * 100 : 0,
    );
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class GameDetailScreen extends StatefulWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<GameDetail> _detailFuture;
  late Future<List<Standing>> _standingsFuture;
  late Future<MatchLineup?> _lineupFuture;
  late Future<Map<String, TeamAnalyticsData>> _analyticsFuture;

  final SportService _sport = SportService();
  Timer? _clockTimer;
  Timer? _analyticsTimer;
  int _liveTick = 0;
  Duration _countdown = Duration.zero;

  bool get _isLive     => widget.game.status == 'STATUS_LIVE' || widget.game.isActuallyLive;
  bool get _isDone     => widget.game.status == 'STATUS_FINAL';
  bool get _isUpcoming => !_isLive && !_isDone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _refresh();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _liveTick++;
        if (_isUpcoming) {
          try {
            final kickoff = DateTime.parse(widget.game.date);
            final diff = kickoff.difference(DateTime.now());
            _countdown = diff.isNegative ? Duration.zero : diff;
          } catch (_) {}
        }
      });
    });

    _analyticsTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted || !_isLive) return;
      _analyticsFuture = _fetchAnalytics();
      setState(() {});
    });
  }

  void _refresh() {
    _detailFuture    = _sport.getGameDetail(widget.game.id);
    _standingsFuture = _fetchStandings();
    _lineupFuture    = _fetchLineup();
    _analyticsFuture = _fetchAnalytics();
  }

  Future<Map<String, TeamAnalyticsData>> _fetchAnalytics() async {
    try {
      final detail = await _sport.getGameDetail(widget.game.id);
      final teams = detail.boxScore['teams'] as List? ?? [];

      Map<String, String> awayStats = {};
      Map<String, String> homeStats = {};

      for (final team in teams) {
        if (team is! Map) continue;
        final teamName = (team['team'] as Map?)?['displayName']?.toString() ?? '';
        final stats = _parseStatsForAnalytics(team['statistics']);

        if (teamName == widget.game.awayTeam.displayName ||
            teamName == widget.game.awayTeam.name) {
          awayStats = stats;
        } else if (teamName == widget.game.homeTeam.displayName ||
            teamName == widget.game.homeTeam.name) {
          homeStats = stats;
        }
      }

      return {
        'away': TeamAnalyticsData.fromStats(awayStats),
        'home': TeamAnalyticsData.fromStats(homeStats),
      };
    } catch (e) {
      print('Error fetching analytics: $e');
      return {
        'away': TeamAnalyticsData(),
        'home': TeamAnalyticsData(),
      };
    }
  }

  Map<String, String> _parseStatsForAnalytics(dynamic rawList) {
    final Map<String, String> out = {};
    if (rawList is! List) return out;
    for (final s in rawList) {
      if (s is! Map) continue;
      final name = s['name']?.toString();
      final val = s['displayValue']?.toString() ?? s['value']?.toString() ?? '0';
      if (name != null && name.isNotEmpty) out[name] = val;
    }
    return out;
  }

  Future<List<Standing>> _fetchStandings() async {
    final leagueEntry = AppConstants.allLeagues.firstWhere(
          (l) => l['name'] == widget.game.leagueName ||
          l['flag'] == widget.game.leagueFlag,
      orElse: () => {'code': 'eng.1'},
    );
    _sport.setLeague(leagueEntry['code']!);
    return _sport.getStandings(forceRefresh: false);
  }

  Future<MatchLineup?> _fetchLineup() async {
    try { return await _sport.getMatchLineup(widget.game.id); }
    catch (_) { return null; }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clockTimer?.cancel();
    _analyticsTimer?.cancel();
    super.dispose();
  }

  Color _teamColor(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return _C.blue;
  }

  // Derives a darker "secondary" tone from a club's primary color so the
  // header gradient always feels tied to the team's own identity, even
  // when only a single brand color is available.
  Color _darken(Color c, [double amt = 0.28]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * (1 - amt)).clamp(0.0, 1.0)).toColor();
  }

  Color _lighten(Color c, [double amt = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final awayColor = _teamColor(widget.game.awayTeam.color);
    final homeColor = _teamColor(widget.game.homeTeam.color);

    return Scaffold(
      backgroundColor: _C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            elevation: 0,
            backgroundColor: _C.surface,
            leading: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _GlassIconButton(
                icon: Icons.arrow_back_ios_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _GlassIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: () => setState(_refresh),
                ),
              ),
            ],
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    'https://a.espncdn.com/i/leaguelogos/soccer/500/${_leagueLogoId()}.png',
                    width: 20, height: 20,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.emoji_events_rounded, size: 18, color: _C.muted),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.game.leagueName,
                  style: const TextStyle(color: _C.muted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Base gradient built from each club's own primary color,
                  // deepened toward the edges for a clean, futuristic feel.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _darken(awayColor, 0.32).withOpacity(0.92),
                          awayColor.withOpacity(0.46),
                          _C.surface,
                          homeColor.withOpacity(0.46),
                          _darken(homeColor, 0.32).withOpacity(0.92),
                        ],
                        stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
                      ),
                    ),
                  ),
                  // Soft radial glow behind the score for depth/focus.
                  Align(
                    alignment: const Alignment(0, 0.35),
                    child: Container(
                      width: 260, height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _C.surface.withOpacity(0.9),
                            _C.surface.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // A hairline top-to-bottom fade so the AppBar title stays legible.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.05), Colors.transparent],
                        stops: const [0.0, 0.3],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                      child: _HeroScore(
                        game: widget.game,
                        isLive: _isLive,
                        isDone: _isDone,
                        isUpcoming: _isUpcoming,
                        liveTick: _liveTick,
                        countdown: _countdown,
                        awayColor: awayColor,
                        homeColor: homeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: _C.surface,  // ← MOVED HERE
                border: const Border(
                  bottom: BorderSide(color: _C.border, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                splashBorderRadius: BorderRadius.circular(24),
                indicator: BoxDecoration(
                  color: _C.blue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _C.blue.withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(vertical: 2),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.zero,
                labelColor: Colors.white,
                unselectedLabelColor: _C.muted,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                dividerColor: Colors.transparent,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(height: 36, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('MATCH'),
                  )),
                  Tab(height: 36, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('STATS'),
                  )),
                  Tab(height: 36, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('LINEUP'),
                  )),
                  Tab(height: 36, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('ANALYTICS'),
                  )),
                  Tab(height: 36, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('TIMELINE'),
                  )),
                  Tab(height: 36, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('STANDINGS'),
                  )),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<GameDetail>(
                future: _detailFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _C.blue));
                  }
                  final detail = snap.data;
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _MatchTab(game: widget.game, detail: detail),
                      _StatsTab(game: widget.game, detail: detail, isUpcoming: _isUpcoming, countdown: _countdown, liveTick: _liveTick),
                      _LineupTab(lineupFuture: _lineupFuture, game: widget.game, isUpcoming: _isUpcoming),
                      _AnalyticsTab(
                        analyticsFuture: _analyticsFuture,
                        game: widget.game,
                        isLive: _isLive,
                        isUpcoming: _isUpcoming,
                        awayColor: awayColor,
                        homeColor: homeColor,
                      ),
                      _TimelineTab(game: widget.game, detail: detail),
                      _StandingsTab(future: _standingsFuture, game: widget.game),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _leagueLogoId() {
    const map = {
      'Premier League': '23', 'La Liga': '15', 'Serie A': '12',
      'Bundesliga': '10', 'Ligue 1': '9', 'Champions League': '2',
      'Europa League': '5', 'Conference League': '682', 'MLS': '19',
      'Brasileirão': '85', 'Liga MX': '26', 'Liga Profesional': '27',
      'Eredivisie': '11', 'Primeira Liga': '24', 'Nations League': '15157',
      'FIFA World Cup': '4', 'Copa América': '26', 'UEFA Euro': '21',
      'International Friendly': '55',
    };
    return map[widget.game.leagueName] ?? '1';
  }
}

// ─── Glass Icon Button ────────────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _C.surface.withOpacity(0.65),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: _C.text, size: 18),
        ),
      ),
    );
  }
}

// ─── Hero Score Block ─────────────────────────────────────────────────────────
class _HeroScore extends StatelessWidget {
  final Game game;
  final bool isLive, isDone, isUpcoming;
  final int liveTick;
  final Duration countdown;
  final Color awayColor;
  final Color homeColor;

  const _HeroScore({
    required this.game, required this.isLive, required this.isDone,
    required this.isUpcoming, required this.liveTick, required this.countdown,
    required this.awayColor, required this.homeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _TeamHero(team: game.awayTeam, isHome: false, accent: awayColor)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _C.surface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLive || isDone) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScoreDigit(game.awayScore),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: TextStyle(color: _C.muted, fontSize: 28, fontWeight: FontWeight.w300)),
                    ),
                    _ScoreDigit(game.homeScore),
                  ],
                ),
                const SizedBox(height: 6),
                if (isLive)
                  _LivePill(clock: game.clock, period: game.period, tick: liveTick)
                else
                  _Pill('FT', _C.muted, _C.blueSoft),
              ] else ...[
                const Text('VS', style: TextStyle(color: _C.muted, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  Helpers.formatGameTime(game.date),
                  style: const TextStyle(color: _C.blue, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                if (countdown.inSeconds > 0) ...[
                  const SizedBox(height: 4),
                  _CountdownPill(countdown: countdown),
                ],
              ],
            ],
          ),
        ),
        Expanded(child: _TeamHero(team: game.homeTeam, isHome: true, accent: homeColor)),
      ],
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final Duration countdown;
  const _CountdownPill({required this.countdown});

  @override
  Widget build(BuildContext context) {
    final h = countdown.inHours;
    final m = countdown.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = countdown.inSeconds.remainder(60).toString().padLeft(2, '0');
    final label = h > 0 ? '${h}h ${m}m' : '$m:$s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _C.blueSoft, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.blue.withOpacity(0.3)),
      ),
      child: Text('Starts in $label',
          style: const TextStyle(color: _C.blue, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ScoreDigit extends StatelessWidget {
  final String value;
  const _ScoreDigit(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value.isEmpty ? '0' : value,
      style: const TextStyle(color: _C.text, fontSize: 44, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1),
    );
  }
}

class _TeamHero extends StatelessWidget {
  final TeamInfo team;
  final bool isHome;
  final Color accent;
  const _TeamHero({required this.team, required this.isHome, this.accent = _C.blue});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 62, height: 62,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.35), width: 1.4),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Image.network(
            team.logo, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, color: _C.muted, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          team.abbreviation.isNotEmpty ? team.abbreviation : team.name,
          style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        if ((team.displayName.isNotEmpty && team.displayName != team.abbreviation) ||
            (team.name.isNotEmpty && team.name != team.abbreviation))
          Text(
            team.displayName.isNotEmpty ? team.displayName : team.name,
            style: const TextStyle(color: _C.muted, fontSize: 9, fontWeight: FontWeight.w500, height: 1.3),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        Text(team.record, style: const TextStyle(color: _C.muted, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  final String clock, period;
  final int tick;
  const _LivePill({required this.clock, required this.period, required this.tick});

  @override
  Widget build(BuildContext context) {
    final dot = tick % 2 == 0;
    String label = 'LIVE';
    if (clock.isNotEmpty) label = "$clock'";
    if (period == '2') label += ' 2H';
    if (period == 'HT') label = 'HT';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _C.liveGlow, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.liveRed.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: dot ? 1.0 : 0.2,
            duration: const Duration(milliseconds: 400),
            child: Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: _C.liveRed, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: _C.liveRed, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label; final Color fg, bg;
  const _Pill(this.label, this.fg, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — MATCH
// ═══════════════════════════════════════════════════════════════════════════════
class _MatchTab extends StatelessWidget {
  final Game game;
  final GameDetail? detail;
  const _MatchTab({required this.game, required this.detail});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _card(Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                'https://a.espncdn.com/i/leaguelogos/soccer/500/${_leagueLogoId(game.leagueName)}.png',
                width: 40, height: 40,
                errorBuilder: (_, __, ___) => Icon(Icons.emoji_events_rounded, size: 30, color: _C.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(game.leagueName,
                    style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  game.isNationalTeamGame
                      ? 'International • ${_matchRound(detail)}'
                      : 'Club Football • ${_matchRound(detail)}',
                  style: const TextStyle(color: _C.muted, fontSize: 11),
                ),
              ]),
            ),
          ],
        )),
        const SizedBox(height: 12),
        _card(Column(children: [
          _InfoRow(Icons.calendar_today_rounded, 'Date', Helpers.formatGameTime(game.date, showBothTimezones: true)),
          _divider(),
          _InfoRow(Icons.location_on_rounded, 'Location',
              game.venue.fullName.isNotEmpty
                  ? '${game.venue.fullName}${game.venue.locationDisplay.isNotEmpty ? ", ${game.venue.locationDisplay}" : ""}'
                  : 'TBD'),
          if (game.venue.capacity > 0) ...[
            _divider(),
            _InfoRow(Icons.people_rounded, 'Capacity', _fmtNum(game.venue.capacity)),
          ],
          _divider(),
          _InfoRow(Icons.home_rounded, 'Home/Away',
              '${game.homeTeam.displayName.isNotEmpty ? game.homeTeam.displayName : game.homeTeam.name} (Home)'),
          _divider(),
          _InfoRow(Icons.sports_rounded, 'Status', _statusLabel(game.status)),
          if (detail != null && _matchRound(detail).isNotEmpty) ...[
            _divider(),
            _InfoRow(Icons.format_list_numbered_rounded, 'Round', _matchRound(detail)),
          ],
        ])),
        const SizedBox(height: 14),
        if (game.awayLineScores.isNotEmpty) ...[
          _SectionTitle('MATCH SCORE BREAKDOWN'),
          _card(_HalfTimeTable(game: game)),
          const SizedBox(height: 14),
        ],
        if (game.goalScorers.isNotEmpty) ...[
          _SectionTitle('GOALS'),
          _card(_GoalScorerList(game: game)),
          const SizedBox(height: 14),
        ],
        if (game.venue.fullName.isNotEmpty) ...[
          _SectionTitle('VENUE'),
          _card(_VenueCard(venue: game.venue)),
        ],
      ],
    );
  }

  String _matchRound(GameDetail? d) {
    if (d == null) return '';
    try {
      final note = d.boxScore['notes'];
      if (note is List && note.isNotEmpty) return note.first['headline']?.toString() ?? '';
    } catch (_) {}
    return '';
  }

  String _statusLabel(String s) {
    if (s == 'STATUS_LIVE') return 'Live';
    if (s == 'STATUS_FINAL') return 'Full Time';
    return 'Upcoming';
  }

  String _leagueLogoId(String name) {
    const map = {
      'Premier League': '23', 'La Liga': '15', 'Serie A': '12',
      'Bundesliga': '10', 'Ligue 1': '9', 'Champions League': '2',
      'Europa League': '5', 'Conference League': '682', 'MLS': '19',
      'Brasileirão': '85', 'Copa América': '26', 'UEFA Euro': '21',
      'Nations League': '15157', 'FIFA World Cup': '4', 'International Friendly': '55',
    };
    return map[name] ?? '1';
  }

  Widget _divider() => const Divider(color: _C.border, height: 1, thickness: 1);
}

extension _GameExt on Game {
  bool get isNationalTeamGame {
    final internationalCodes = ['fifa.world', 'fifa.worldq', 'uefa.euro', 'uefa.nations',
      'conmebol.america', 'concacaf.gold', 'afc.cup', 'caf.nations', 'fifa.friendly', 'ofc.nations'];
    return internationalCodes.any((c) => leagueName.toLowerCase().contains(c.toLowerCase()) ||
        leagueName.contains('National') || leagueName.contains('International') ||
        leagueName.contains('World Cup') || leagueName.contains('Euro') ||
        leagueName.contains('Nations') || leagueName.contains('Copa') ||
        leagueName.contains('Friendly'));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: _C.blue, size: 16),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: _C.muted, fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2)),
        ],
      ),
    );
  }
}

class _HalfTimeTable extends StatelessWidget {
  final Game game;
  const _HalfTimeTable({required this.game});

  @override
  Widget build(BuildContext context) {
    final awayH1 = game.awayLineScores.isNotEmpty ? game.awayLineScores[0] : 0;
    final awayH2 = game.awayLineScores.length > 1 ? game.awayLineScores[1] : 0;
    final homeH1 = game.homeLineScores.isNotEmpty ? game.homeLineScores[0] : 0;
    final homeH2 = game.homeLineScores.length > 1 ? game.homeLineScores[1] : 0;
    final awayET = game.awayLineScores.length > 2 ? game.awayLineScores[2] : null;
    final homeET = game.homeLineScores.length > 2 ? game.homeLineScores[2] : null;
    final cols = <String>['', '1ST', '2ND', if (awayET != null) 'ET', 'FT'];

    return Table(
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(1)},
      children: [
        _tRow(cols, isHeader: true),
        _tRow([game.awayTeam.abbreviation, '$awayH1', '$awayH2', if (awayET != null) '$awayET', game.awayScore]),
        _tRow([game.homeTeam.abbreviation, '$homeH1', '$homeH2', if (homeET != null) '$homeET', game.homeScore]),
      ],
    );
  }

  TableRow _tRow(List<String> vals, {bool isHeader = false}) {
    return TableRow(
      decoration: isHeader
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: _C.border)))
          : null,
      children: vals.map((v) {
        final isFirst = v == vals.first;
        final isLast  = v == vals.last;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Text(v,
            textAlign: isFirst ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              color: isHeader ? _C.muted : (isLast && !isFirst ? _C.blue : _C.text),
              fontSize: isHeader ? 10 : 13,
              fontWeight: isHeader ? FontWeight.w600 : (isLast ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoalScorerList extends StatelessWidget {
  final Game game;
  const _GoalScorerList({required this.game});

  @override
  Widget build(BuildContext context) {
    final all = [...game.goalScorers]..sort((a, b) => a.minute.compareTo(b.minute));
    return Column(
      children: all.map((g) {
        final ballIcon = Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: g.isOwnGoal ? _C.red.withOpacity(0.12) : _C.green.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.sports_soccer_rounded,
              size: 12, color: g.isOwnGoal ? _C.red : _C.green),
        );
        final penLabel = g.isPenalty ? ' (P)' : '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: !g.isHomeTeam ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ballIcon, const SizedBox(width: 5),
                    Flexible(child: Text('${g.playerName}$penLabel',
                        style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                  if (g.assistPlayerName?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(left: 23),
                      child: Text('Ast: ${g.assistPlayerName}',
                          style: const TextStyle(color: _C.muted, fontSize: 10)),
                    ),
                ]) : const SizedBox(),
              ),
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                    color: _C.green.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
                child: Text(g.minuteDisplay, textAlign: TextAlign.center,
                    style: const TextStyle(color: _C.green, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: g.isHomeTeam ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text('${g.playerName}$penLabel',
                        style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 5), ballIcon,
                  ]),
                  if (g.assistPlayerName?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 23),
                      child: Text('Ast: ${g.assistPlayerName}',
                          style: const TextStyle(color: _C.muted, fontSize: 10)),
                    ),
                ]) : const SizedBox(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Venue venue;
  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.stadium_rounded, color: _C.blue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(venue.fullName,
                style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 14)),
            if (venue.locationDisplay.isNotEmpty)
              Text(venue.locationDisplay, style: const TextStyle(color: _C.muted, fontSize: 12)),
            if (venue.capacity > 0)
              Text('Capacity: ${_fmtNum(venue.capacity)}',
                  style: const TextStyle(color: _C.muted, fontSize: 11)),
          ]),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — STATS
// ═══════════════════════════════════════════════════════════════════════════════
class _StatsTab extends StatefulWidget {
  final Game game;
  final GameDetail? detail;
  final bool isUpcoming;
  final Duration countdown;
  final int liveTick;

  const _StatsTab({
    required this.game,
    required this.detail,
    required this.isUpcoming,
    required this.countdown,
    required this.liveTick,
  });

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  bool _showAll = false;

  // ─── UPDATED STATS ORDER ──────────────────────────────────────────────
  static const List<String> _primaryKeys = [
    'possessionPct',      // 1. Possession
    'passes',             // 2. Total passes
    'passingAccuracy',    // 3. Accurate passes (shown as %)
    'totalShots',         // 4. Total shots
    'shotsOnTarget',      // 5. Shots on target
    'crosses',            // 6. Total crosses
    'accurateCrosses',    // 7. Accurate crosses
    'fouls',              // 8. Fouls
    'offsides',           // 9. Offsides
    'yellowCards',        // 10. Yellow cards
    'redCards',           // 11. Red cards
  ];

  // Extra stats for "See more"
  static const List<String> _extraKeys = [
    'saves',
    'corners',
    'goals',
    'assists',
    'penalties',
    'blockedShots',
    'clearances',
    'aerialDuels',
    'interceptions',
    'tackles',
  ];

  static const Map<String, String> _labels = {
    'possessionPct':    'POSSESSION',
    'passes':           'TOTAL PASSES',
    'passingAccuracy':  'ACCURATE PASSES',
    'totalShots':       'TOTAL SHOTS',
    'shotsOnTarget':    'SHOTS ON TARGET',
    'crosses':          'TOTAL CROSSES',
    'accurateCrosses':  'ACCURATE CROSSES',
    'fouls':            'FOULS',
    'offsides':         'OFFSIDES',
    'yellowCards':      'YELLOW CARDS',
    'redCards':         'RED CARDS',
    'saves':            'SAVES',
    'corners':          'CORNERS',
    'goals':            'GOALS',
    'assists':          'ASSISTS',
    'penalties':        'PENALTIES',
    'blockedShots':     'BLOCKED SHOTS',
    'clearances':       'CLEARANCES',
    'aerialDuels':      'AERIAL DUELS WON',
    'interceptions':    'INTERCEPTIONS',
    'tackles':          'TACKLES',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.isUpcoming) return _buildUpcomingCountdown(context);
    if (widget.detail == null) return _emptyStats('Stats not yet available');

    final teams = (widget.detail!.boxScore['teams'] as List?)
        ?.whereType<Map<String, dynamic>>().toList() ?? [];
    if (teams.isEmpty) return _emptyStats('Stats not available for this match');

    Map<String, dynamic>? awayData, homeData;
    for (final t in teams) {
      final dn = (t['team'] as Map<String, dynamic>?)?['displayName']?.toString() ?? '';
      if (dn == widget.game.awayTeam.displayName || dn == widget.game.awayTeam.name) awayData = t;
      else if (dn == widget.game.homeTeam.displayName || dn == widget.game.homeTeam.name) homeData = t;
    }
    if (awayData == null && teams.isNotEmpty) awayData = teams[0];
    if (homeData == null && teams.length > 1) homeData = teams[1];

    final awayStats = _parseStats(awayData?['statistics']);
    final homeStats = _parseStats(homeData?['statistics']);

    final allAvailableKeys = <String>{...awayStats.keys, ...homeStats.keys};
    final primaryAvailable = _primaryKeys.where(allAvailableKeys.contains).toList();
    final extraKeysAvailable = _extraKeys.where(allAvailableKeys.contains).toList();
    final otherKeys = allAvailableKeys
        .where((k) => !_primaryKeys.contains(k) && !_extraKeys.contains(k))
        .toList();

    final displayedKeys = _showAll
        ? [...primaryAvailable, ...extraKeysAvailable, ...otherKeys]
        : primaryAvailable;

    if (displayedKeys.isEmpty) return _emptyStats('No stats available for this match');

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _card(Row(children: [
          _TeamStatHeader(team: widget.game.awayTeam, align: CrossAxisAlignment.start),
          const Spacer(),
          const Text('STATS', style: TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const Spacer(),
          _TeamStatHeader(team: widget.game.homeTeam, align: CrossAxisAlignment.end),
        ])),
        const SizedBox(height: 10),
        _card(Column(
          children: [
            ...displayedKeys.map((key) {
              final isPercent = key == 'possessionPct' ||
                  key == 'passingAccuracy' ||
                  key == 'shotAccuracy' ||
                  key == 'crossAccuracy';

              return _StatBarRow(
                label: _labels[key] ?? _camelToTitle(key),
                awayValue: awayStats[key] ?? '0',
                homeValue: homeStats[key] ?? '0',
                awayColor: _C.awayAccent,
                homeColor: _C.homeAccent,
                isPossession: key == 'possessionPct',
                isPercentage: isPercent,
              );
            }),
            if (extraKeysAvailable.isNotEmpty || otherKeys.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(color: _C.border, height: 1),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAll ? 'SEE LESS' : 'SEE MORE (${extraKeysAvailable.length + otherKeys.length} more stats)',
                        style: const TextStyle(color: _C.blue, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: _C.blue, size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        )),
      ],
    );
  }

  Widget _buildUpcomingCountdown(BuildContext context) {
    final h    = widget.countdown.inHours;
    final m    = widget.countdown.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s    = widget.countdown.inSeconds.remainder(60).toString().padLeft(2, '0');
    final days = widget.countdown.inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _card(Column(
            children: [
              const Text('MATCH STARTS IN', style: TextStyle(color: _C.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (days > 0) ...[
                    _CountdownUnit('$days', 'DAYS'),
                    const _CountdownColon(),
                  ],
                  _CountdownUnit('${h.remainder(24).toString().padLeft(2, '0')}', 'HRS'),
                  const _CountdownColon(),
                  _CountdownUnit(m, 'MIN'),
                  const _CountdownColon(),
                  _CountdownUnit(s, 'SEC'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  Helpers.formatGameTime(widget.game.date, showBothTimezones: true),
                  style: const TextStyle(color: _C.blue, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          )),
          const SizedBox(height: 16),
          if (widget.game.venue.fullName.isNotEmpty)
            _card(_VenueCard(venue: widget.game.venue)),
          const SizedBox(height: 16),
          _card(Column(
            children: [
              const Icon(Icons.bar_chart_rounded, color: _C.blue, size: 40),
              const SizedBox(height: 8),
              const Text('Live stats will appear here once the match begins',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _C.muted, fontSize: 13)),
            ],
          )),
        ],
      ),
    );
  }

  Map<String, String> _parseStats(dynamic rawList) {
    final Map<String, String> out = {};
    if (rawList is! List) return out;
    for (final s in rawList) {
      if (s is! Map) continue;
      final name = s['name']?.toString();
      final val  = s['displayValue']?.toString() ?? s['value']?.toString() ?? '0';
      if (name != null && name.isNotEmpty) out[name] = val;
    }
    return out;
  }

  String _camelToTitle(String s) =>
      s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}').trim().toUpperCase();

  Widget _emptyStats(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.bar_chart_rounded, color: _C.muted, size: 52),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: _C.muted, fontSize: 14)),
    ]),
  );
}

// ─── Countdown Unit ──────────────────────────────────────────────────────────
class _CountdownUnit extends StatelessWidget {
  final String value, label;
  const _CountdownUnit(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.blueSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.blue.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(
            value,
            style: const TextStyle(
                color: _C.blue,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()]
            )
        ),
        Text(label, style: const TextStyle(color: _C.muted, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Countdown Colon ──────────────────────────────────────────────────────────
class _CountdownColon extends StatelessWidget {
  const _CountdownColon();

  @override
  Widget build(BuildContext context) =>
      const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
              ':',
              style: TextStyle(color: _C.blue, fontSize: 28, fontWeight: FontWeight.w700)
          )
      );
}

// ─── Team Stat Header ─────────────────────────────────────────────────────────
class _TeamStatHeader extends StatelessWidget {
  final TeamInfo team;
  final CrossAxisAlignment align;
  const _TeamStatHeader({required this.team, required this.align});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: align, children: [
      Image.network(
        team.logo,
        width: 34,
        height: 34,
        errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, color: _C.muted, size: 24),
      ),
      const SizedBox(height: 4),
      Text(
          team.abbreviation,
          style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w700)
      ),
    ]);
  }
}

// ─── Stat Bar Row ─────────────────────────────────────────────────────────────
class _StatBarRow extends StatelessWidget {
  final String label, awayValue, homeValue;
  final Color awayColor, homeColor;
  final bool isPossession;
  final bool isPercentage;

  const _StatBarRow({
    required this.label,
    required this.awayValue,
    required this.homeValue,
    required this.awayColor,
    required this.homeColor,
    this.isPossession = false,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final aNum  = _toNum(awayValue);
    final hNum  = _toNum(homeValue);
    final total = aNum + hNum;
    final aFrac = total > 0 ? aNum / total : 0.5;

    // Format display values
    final awayDisplay = isPossession || isPercentage ? '$awayValue%' : awayValue;
    final homeDisplay = isPossession || isPercentage ? '$homeValue%' : homeValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 50,
            child: Text(
              awayDisplay,
              style: TextStyle(color: awayColor, fontSize: 14, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              homeDisplay,
              style: TextStyle(color: homeColor, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(children: [
            Expanded(
              flex: (aFrac * 100).round().clamp(5, 95),
              child: Container(height: 5, color: awayColor),
            ),
            Expanded(
              flex: ((1 - aFrac) * 100).round().clamp(5, 95),
              child: Container(height: 5, color: homeColor),
            ),
          ]),
        ),
      ]),
    );
  }

  double _toNum(String v) => double.tryParse(v.replaceAll('%', '').replaceAll(',', '')) ?? 0;
}
// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 3 — LINEUP
// ═══════════════════════════════════════════════════════════════════════════════
class _LineupTab extends StatelessWidget {
  final Future<MatchLineup?> lineupFuture;
  final Game game;
  final bool isUpcoming;
  const _LineupTab({required this.lineupFuture, required this.game, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchLineup?>(
      future: lineupFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.blue));
        }
        final lineup = snap.data;
        if (lineup == null || (lineup.homePlayers.isEmpty && lineup.awayPlayers.isEmpty)) {
          return _NoDataWidget(
            icon: Icons.people_alt_rounded,
            message: 'Lineup not yet announced',
          );
        }
        return _LineupView(lineup: lineup, game: game, isUpcoming: isUpcoming);
      },
    );
  }
}

class _LineupView extends StatefulWidget {
  final MatchLineup lineup;
  final Game game;
  final bool isUpcoming;
  const _LineupView({required this.lineup, required this.game, required this.isUpcoming});

  @override
  State<_LineupView> createState() => _LineupViewState();
}

class _LineupViewState extends State<_LineupView> {
  bool _showStarters = true;
  late String _homeFormation;
  late String _awayFormation;

  @override
  void initState() {
    super.initState();
    _homeFormation = widget.lineup.homeFormation.isNotEmpty
        ? widget.lineup.homeFormation
        : '4-3-3';
    _awayFormation = widget.lineup.awayFormation.isNotEmpty
        ? widget.lineup.awayFormation
        : '4-3-3';
  }

  TeamLineup _toTeamLineup({required bool isHome}) {
    final players = isHome ? widget.lineup.homePlayers : widget.lineup.awayPlayers;
    final team    = isHome ? widget.game.homeTeam : widget.game.awayTeam;
    final formation = isHome ? _homeFormation : _awayFormation;
    final color   = isHome ? _C.homeAccent : _C.awayAccent;

    PitchPlayer toPitch(LineupPlayer p) => PitchPlayer(
      id: p.id,
      name: p.name,
      shortName: p.shortName,
      number: p.number,
      position: p.position,
      imageUrl: p.headshot.isNotEmpty ? p.headshot : null,
      isStarter: p.isStarter,
      isHome: isHome,
      rating: p.rating,
    );

    return TeamLineup(
      teamName: team.displayName.isNotEmpty ? team.displayName : team.name,
      teamLogo: team.logo,
      formation: formation,
      starters: players.where((p) => p.isStarter).take(11).map(toPitch).toList(),
      substitutes: players.where((p) => !p.isStarter).map(toPitch).toList(),
      primaryColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeLineup = _toTeamLineup(isHome: true);
    final awayLineup = _toTeamLineup(isHome: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(children: [
          _FormationHeader(
            team: widget.game.awayTeam,
            formation: _awayFormation,
            color: _C.awayAccent,
          ),
          const Spacer(),
          _ToggleChip(
            selected: _showStarters,
            onTab: (v) => setState(() => _showStarters = v),
          ),
          const Spacer(),
          _FormationHeader(
            team: widget.game.homeTeam,
            formation: _homeFormation,
            color: _C.homeAccent,
          ),
        ]),
        const SizedBox(height: 12),

        if (_showStarters) ...[
          Row(children: [
            const Text('AWAY', style: TextStyle(color: _C.muted, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Expanded(
              child: FormationSelector(
                selectedFormation: _awayFormation,
                onFormationChanged: (f) => setState(() => _awayFormation = f),
                accentColor: _C.awayAccent,
              ),
            ),
          ]),
          const SizedBox(height: 4),

          FootballPitch(
            homeTeam: homeLineup,
            awayTeam: awayLineup,
            showRatings: !widget.isUpcoming,
            onPlayerTap: (player) => _showPlayerSheet(context, player),
          ),

          const SizedBox(height: 4),
          Row(children: [
            const Text('HOME', style: TextStyle(color: _C.muted, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Expanded(
              child: FormationSelector(
                selectedFormation: _homeFormation,
                onFormationChanged: (f) => setState(() => _homeFormation = f),
                accentColor: _C.homeAccent,
              ),
            ),
          ]),

          if (widget.isUpcoming) ...[
            const SizedBox(height: 10),
            _card(Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.info_outline_rounded, color: _C.blue, size: 14),
                SizedBox(width: 6),
                Text(
                  'Player ratings appear after the match',
                  style: TextStyle(color: _C.muted, fontSize: 12),
                ),
              ],
            )),
          ],
        ] else ...[
          SubstitutesSection(homeTeam: homeLineup, awayTeam: awayLineup),
        ],
      ],
    );
  }

  void _showPlayerSheet(BuildContext context, PitchPlayer player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerBottomSheet(player: player),
    );
  }
}

class _PlayerBottomSheet extends StatelessWidget {
  final PitchPlayer player;
  const _PlayerBottomSheet({required this.player});

  @override
  Widget build(BuildContext context) {
    final rColor = player.rating != null ? _ratingColor(player.rating!) : _C.blue;
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: rColor, width: 3),
            boxShadow: [BoxShadow(color: rColor.withOpacity(0.3), blurRadius: 12)],
          ),
          child: ClipOval(
            child: (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                ? Image.network(player.imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials())
                : _initials(),
          ),
        ),
        const SizedBox(height: 12),
        Text(player.name,
            style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Pill('#${player.number}', _C.muted, _C.blueSoft),
          const SizedBox(width: 6),
          _Pill(player.position, _C.blue, _C.blueSoft),
          if (player.rating != null) ...[
            const SizedBox(width: 6),
            _Pill(player.rating!.toStringAsFixed(1), Colors.white, rColor),
          ],
        ]),
      ]),
    );
  }

  Widget _initials() {
    final parts = player.name.trim().split(' ');
    final txt = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (player.name.isNotEmpty ? player.name[0].toUpperCase() : '?');
    return Container(
      color: _C.blueSoft,
      child: Center(child: Text(txt, style: const TextStyle(color: _C.blue, fontSize: 24, fontWeight: FontWeight.w900))),
    );
  }

  Color _ratingColor(double r) {
    if (r >= 8) return _C.green;
    if (r >= 6.5) return _C.blue;
    if (r >= 5) return _C.yellow;
    return _C.red;
  }
}

class _FormationHeader extends StatelessWidget {
  final TeamInfo team;
  final String formation;
  final Color color;
  const _FormationHeader({required this.team, required this.formation, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.network(team.logo, width: 20, height: 20,
            errorBuilder: (_, __, ___) => Icon(Icons.sports_soccer, color: color, size: 18)),
        const SizedBox(width: 4),
        Text(
          team.abbreviation.isNotEmpty ? team.abbreviation : team.name,
          style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ]),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.grid_view_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            formation.isEmpty ? '–' : formation,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    ]);
  }
}

class _ToggleChip extends StatelessWidget {
  final bool selected;
  final Function(bool) onTab;
  const _ToggleChip({required this.selected, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.blueSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        _Seg('Starters', selected, () => onTab(true)),
        _Seg('Subs', !selected, () => onTab(false)),
      ]),
    );
  }

  Widget _Seg(String label, bool active, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _C.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _C.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 4 — TIMELINE
// ═══════════════════════════════════════════════════════════════════════════════
class _TimelineTab extends StatelessWidget {
  final Game game;
  final GameDetail? detail;
  const _TimelineTab({required this.game, required this.detail});

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();
    if (events.isEmpty) {
      return _NoDataWidget(icon: Icons.timeline_rounded, message: 'Timeline not yet available');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Row(children: [
          Expanded(child: Center(child: Text(game.awayTeam.abbreviation,
              style: const TextStyle(color: _C.awayAccent, fontSize: 12, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 56),
          Expanded(child: Center(child: Text(game.homeTeam.abbreviation,
              style: const TextStyle(color: _C.homeAccent, fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 8),
        ...events.map((e) => _TimelineRow(event: e, game: game)),
      ],
    );
  }

  List<_TLEvent> _buildEvents() {
    final List<_TLEvent> events = [];

    events.add(_TLEvent(minute: 0, type: _TLType.kickoff, label: 'KICK OFF', sub: null, isHome: null));

    for (final g in game.goalScorers) {
      events.add(_TLEvent(
        minute: g.minute,
        type: g.isOwnGoal ? _TLType.ownGoal : _TLType.goal,
        label: '${g.playerName}${g.isPenalty ? ' (pen)' : ''}',
        sub: (g.assistPlayerName?.isNotEmpty == true) ? 'Ast: ${g.assistPlayerName}' : null,
        isHome: g.isHomeTeam,
      ));
    }

    if (detail != null) {
      for (final p in detail!.plays) {
        final min = _parseMin(p);
        if (p.isCard) {
          final isYellow = p.text.toLowerCase().contains('yellow');
          events.add(_TLEvent(
            minute: min,
            type: isYellow ? _TLType.yellowCard : _TLType.redCard,
            label: p.playerName ?? _extractPlayerFromText(p.text),
            sub: p.text.length <= 60 ? p.text : '${p.text.substring(0, 58)}…',
            isHome: null,
          ));
        } else if (p.isSubstitution) {
          events.add(_TLEvent(
            minute: min, type: _TLType.substitution,
            label: p.text.length > 45 ? '${p.text.substring(0, 43)}…' : p.text,
            sub: null, isHome: null,
          ));
        } else if (p.type.toLowerCase().contains('corner') || p.text.toLowerCase().contains('corner kick')) {
          events.add(_TLEvent(minute: min, type: _TLType.corner, label: 'Corner', sub: null, isHome: null));
        } else if (p.type.toLowerCase().contains('foul') || p.text.toLowerCase().contains('foul by')) {
          events.add(_TLEvent(minute: min, type: _TLType.foul, label: _extractFoulFrom(p.text), sub: null, isHome: null));
        } else if (p.type.toLowerCase().contains('freekick') || p.text.toLowerCase().contains('free kick')) {
          events.add(_TLEvent(minute: min, type: _TLType.freekick, label: 'Free Kick', sub: null, isHome: null));
        } else if (p.type.toLowerCase().contains('penalty') || p.text.toLowerCase().contains('penalty')) {
          if (!p.isGoal) {
            events.add(_TLEvent(minute: min, type: _TLType.penalty, label: 'Penalty', sub: p.text.length <= 50 ? p.text : null, isHome: null));
          }
        } else if (p.type.toLowerCase().contains('offsid') || p.text.toLowerCase().contains('offside')) {
          events.add(_TLEvent(minute: min, type: _TLType.offside, label: 'Offside', sub: null, isHome: null));
        }
      }
    }

    if (game.awayLineScores.isNotEmpty) {
      final ah = game.awayLineScores[0];
      final hh = game.homeLineScores.isNotEmpty ? game.homeLineScores[0] : 0;
      events.add(_TLEvent(
        minute: 45, type: _TLType.halfTime,
        label: 'HALF TIME', sub: '$ah – $hh', isHome: null,
      ));
    }

    if (game.status == 'STATUS_FINAL') {
      events.add(_TLEvent(
        minute: 90, type: _TLType.fullTime,
        label: 'FULL TIME', sub: '${game.awayScore} – ${game.homeScore}',
        isHome: null,
      ));
    } else if (game.status == 'STATUS_LIVE' && (game.period == '3' || game.clock.contains('+'))) {
      events.add(_TLEvent(minute: 90, type: _TLType.extraTime, label: 'EXTRA TIME', sub: null, isHome: null));
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    return events;
  }

  int _parseMin(Play p) {
    final m = RegExp(r'(\d+)').firstMatch(p.time);
    return m != null ? (int.tryParse(m.group(1)!) ?? 0) : 0;
  }

  String _extractPlayerFromText(String t) {
    final m = RegExp(r'(?:on|to|by)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)', caseSensitive: false).firstMatch(t);
    return m?.group(1) ?? t.split(' ').take(3).join(' ');
  }

  String _extractFoulFrom(String t) {
    final m = RegExp(r'foul by\s+(.+?)(?:\s+on|\.|$)', caseSensitive: false).firstMatch(t);
    return m != null ? 'Foul by ${m.group(1)}' : 'Foul';
  }
}

enum _TLType {
  kickoff, goal, ownGoal, yellowCard, redCard, substitution,
  halfTime, fullTime, extraTime, corner, foul, freekick, penalty, offside,
}

class _TLEvent {
  final int minute;
  final _TLType type;
  final String label;
  final String? sub;
  final bool? isHome;
  const _TLEvent({required this.minute, required this.type, required this.label, required this.sub, required this.isHome});
}

class _TimelineRow extends StatelessWidget {
  final _TLEvent event;
  final Game game;
  const _TimelineRow({required this.event, required this.game});

  @override
  Widget build(BuildContext context) {
    final isMilestone = event.isHome == null;
    final isHome      = event.isHome == true;
    final evColor     = _eventColor(event.type);
    final iconW       = _eventIconWidget(event.type, evColor);

    if (isMilestone) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Container(height: 1, color: evColor.withOpacity(0.3))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: evColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: evColor.withOpacity(0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  iconW,
                  const SizedBox(width: 6),
                  Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text(event.label,
                        style: TextStyle(color: evColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    if (event.sub != null) ...[
                      const SizedBox(height: 1),
                      Text(event.sub!,
                          style: TextStyle(color: evColor, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 1, color: evColor.withOpacity(0.3))),
            ],
          ),
        ),
      );
    }

    final minBadge = Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
          color: evColor.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
      child: Text("${event.minute}'",
          textAlign: TextAlign.center,
          style: TextStyle(color: evColor, fontSize: 10, fontWeight: FontWeight.w800)),
    );

    final playerBlock = Column(
      crossAxisAlignment: isHome ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: isHome
              ? [iconW, const SizedBox(width: 5),
            Flexible(child: Text(event.label,
                style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w600)))]
              : [Flexible(child: Text(event.label,
              style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(width: 5), iconW],
        ),
        if (event.sub != null)
          Padding(
            padding: EdgeInsets.only(left: isHome ? 27 : 0, right: isHome ? 0 : 27),
            child: Text(event.sub!, style: const TextStyle(color: _C.muted, fontSize: 10)),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: isHome
            ? [
          const Expanded(child: SizedBox()),
          minBadge,
          const SizedBox(width: 8),
          Expanded(child: playerBlock),
        ]
            : [
          Expanded(child: playerBlock),
          const SizedBox(width: 8),
          minBadge,
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Color _eventColor(_TLType t) {
    switch (t) {
      case _TLType.goal:         return _C.green;
      case _TLType.ownGoal:      return _C.red;
      case _TLType.yellowCard:   return _C.yellow;
      case _TLType.redCard:      return _C.red;
      case _TLType.substitution: return _C.blue;
      case _TLType.halfTime:     return _C.blue;
      case _TLType.fullTime:     return _C.text;
      case _TLType.extraTime:    return _C.blue;
      case _TLType.corner:       return _C.muted;
      case _TLType.foul:         return _C.yellow;
      case _TLType.freekick:     return _C.muted;
      case _TLType.penalty:      return _C.awayAccent;
      case _TLType.offside:      return _C.muted;
      case _TLType.kickoff:      return _C.green;
    }
  }

  Widget _eventIconWidget(_TLType t, Color color) {
    IconData icon;
    switch (t) {
      case _TLType.goal:         icon = Icons.sports_soccer_rounded; break;
      case _TLType.ownGoal:      icon = Icons.sports_soccer_rounded; break;
      case _TLType.yellowCard:   icon = Icons.rectangle_rounded; break;
      case _TLType.redCard:      icon = Icons.rectangle_rounded; break;
      case _TLType.substitution: icon = Icons.swap_horiz_rounded; break;
      case _TLType.halfTime:     icon = Icons.pause_circle_filled_rounded; break;
      case _TLType.fullTime:     icon = Icons.sports_score_rounded; break;
      case _TLType.extraTime:    icon = Icons.more_time_rounded; break;
      case _TLType.corner:       icon = Icons.flag_outlined; break;
      case _TLType.foul:         icon = Icons.warning_amber_rounded; break;
      case _TLType.freekick:     icon = Icons.sports_rounded; break;
      case _TLType.penalty:      icon = Icons.radio_button_checked_rounded; break;
      case _TLType.offside:      icon = Icons.block_rounded; break;
      case _TLType.kickoff:      icon = Icons.play_circle_filled_rounded; break;
    }
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 5 — STANDINGS
// ═══════════════════════════════════════════════════════════════════════════════
class _StandingsTab extends StatelessWidget {
  final Future<List<Standing>> future;
  final Game game;
  const _StandingsTab({required this.future, required this.game});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Standing>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.blue));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _NoDataWidget(icon: Icons.format_list_numbered_rounded, message: 'Standings not available for this competition');
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _card(Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.emoji_events_rounded, color: _C.blue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(game.leagueName, style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${list.length} clubs', style: const TextStyle(color: _C.muted, fontSize: 11)),
              ])),
            ])),
            const SizedBox(height: 12),
            _card(Row(children: [
              _MiniTeamTag(team: game.awayTeam, color: _C.awayAccent, standing: _findStanding(list, game.awayTeam.id)),
              const Spacer(),
              const Text('vs', style: TextStyle(color: _C.muted, fontSize: 11)),
              const Spacer(),
              _MiniTeamTag(team: game.homeTeam, color: _C.homeAccent, standing: _findStanding(list, game.homeTeam.id)),
            ])),
            const SizedBox(height: 12),
            _card(Column(children: [
              _StandingsHeader(),
              ...list.map((s) => _StandingsRow(
                standing: s,
                isAway: s.team.id == game.awayTeam.id,
                isHome: s.team.id == game.homeTeam.id,
              )),
            ])),
          ],
        );
      },
    );
  }

  Standing? _findStanding(List<Standing> list, String teamId) {
    try { return list.firstWhere((s) => s.team.id == teamId); }
    catch (_) { return null; }
  }
}

class _MiniTeamTag extends StatelessWidget {
  final TeamInfo team; final Color color; final Standing? standing;
  const _MiniTeamTag({required this.team, required this.color, this.standing});

  @override
  Widget build(BuildContext context) {
    final rank = standing?.rank;
    final pts  = standing?.stats['points'] ?? standing?.stats['pts'];
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.network(team.logo, width: 22, height: 22,
            errorBuilder: (_, __, ___) => Text(team.abbreviation, style: const TextStyle(fontSize: 10))),
        const SizedBox(width: 6),
        Text(team.abbreviation, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
      if (rank != null)
        Text('Rank #$rank${pts != null ? " • $pts pts" : ""}',
            style: const TextStyle(color: _C.muted, fontSize: 10)),
    ]);
  }
}

class _StandingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.border))),
      child: Row(children: [
        const SizedBox(width: 22, child: Text('#', style: _hS)),
        const SizedBox(width: 8),
        const Expanded(child: Text('CLUB', style: _hS)),
        ...['P','W','D','L','GD','Pts'].map((h) =>
            SizedBox(width: 28, child: Text(h, style: _hS, textAlign: TextAlign.center))),
      ]),
    );
  }

  static const _hS = TextStyle(color: _C.muted, fontSize: 10, fontWeight: FontWeight.w700);
}

class _StandingsRow extends StatelessWidget {
  final Standing standing;
  final bool isAway, isHome;
  const _StandingsRow({required this.standing, required this.isAway, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final highlight   = isAway || isHome;
    final s           = standing.stats;
    final gd          = _gd(s);
    final accentColor = isAway ? _C.awayAccent : _C.homeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: highlight ? accentColor.withOpacity(0.07) : Colors.transparent,
        border: highlight
            ? Border.all(color: accentColor.withOpacity(0.25))
            : Border(bottom: BorderSide(color: _C.border.withOpacity(0.4))),
        borderRadius: highlight ? BorderRadius.circular(8) : null,
      ),
      child: Row(children: [
        SizedBox(width: 22, child: Text('${standing.rank}',
            style: TextStyle(color: standing.rank <= 4 ? _C.green : _C.muted, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Expanded(child: Row(children: [
          Image.network(standing.team.logo, width: 18, height: 18,
              errorBuilder: (_, __, ___) => const SizedBox(width: 18)),
          const SizedBox(width: 6),
          Expanded(child: Text(
            standing.team.abbreviation.isNotEmpty ? standing.team.abbreviation : standing.team.name,
            style: TextStyle(color: highlight ? accentColor : _C.text, fontSize: 12,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          )),
        ])),
        ...[
          _cell(s['gamesPlayed'] ?? s['played'] ?? '-'),
          _cell(standing.wins),
          _cell(standing.ties),
          _cell(standing.losses),
          _cell(gd, color: gd.startsWith('-') ? _C.red : _C.green),
          _cell(s['points'] ?? s['pts'] ?? '-', bold: true),
        ],
      ]),
    );
  }

  Widget _cell(String val, {Color? color, bool bold = false}) {
    return SizedBox(width: 28, child: Text(val,
        textAlign: TextAlign.center,
        style: TextStyle(color: color ?? _C.text, fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)));
  }

  String _gd(Map<String, String> s) {
    final gf = int.tryParse(s['pointsFor'] ?? s['goalsFor'] ?? '0') ?? 0;
    final ga = int.tryParse(s['pointsAgainst'] ?? s['goalsAgainst'] ?? '0') ?? 0;
    final d  = gf - ga;
    return d >= 0 ? '+$d' : '$d';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 6 — ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 6 — ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 6 — ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════════
class _AnalyticsTab extends StatelessWidget {
  final Future<Map<String, TeamAnalyticsData>> analyticsFuture;
  final Game game;
  final bool isLive;
  final bool isUpcoming;
  final Color awayColor;
  final Color homeColor;

  const _AnalyticsTab({
    required this.analyticsFuture,
    required this.game,
    required this.isLive,
    required this.isUpcoming,
    required this.awayColor,
    required this.homeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isUpcoming) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.blueSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 48,
                color: _C.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analytics will be available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Live statistics will appear once the match starts',
              style: TextStyle(
                fontSize: 13,
                color: _C.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, TeamAnalyticsData>>(
      future: analyticsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: _C.blue,
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading analytics...',
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.muted,
                  ),
                ),
              ],
            ),
          );
        }

        final data = snap.data;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _C.blueSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    size: 48,
                    color: _C.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isLive ? 'Gathering analytics data...' : 'Analytics not available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLive ? 'Please wait while we collect the stats' : 'No stats available for this match',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _C.muted,
                  ),
                ),
              ],
            ),
          );
        }

        final awayData = data['away'] ?? TeamAnalyticsData();
        final homeData = data['home'] ?? TeamAnalyticsData();

        final awayAnalytics = _calculateTeamAnalytics(awayData);
        final homeAnalytics = _calculateTeamAnalytics(homeData);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Live Status Banner ──────────────────────────────────────────
            if (isLive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.liveRed.withOpacity(0.08),
                      _C.liveRed.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.liveRed.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _C.liveRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'LIVE • Stats update every 5 minutes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.liveRed,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _C.liveRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── AWAY TEAM PERFORMANCE ──────────────────────────────────────
            _TeamPerformanceCard(
              teamName: game.awayTeam.abbreviation,
              teamFullName: game.awayTeam.displayName,
              teamLogo: game.awayTeam.logo,
              analytics: awayAnalytics,
              color: awayColor,
              isHome: false,
            ),

            const SizedBox(height: 14),

            // ── HOME TEAM PERFORMANCE ──────────────────────────────────────
            _TeamPerformanceCard(
              teamName: game.homeTeam.abbreviation,
              teamFullName: game.homeTeam.displayName,
              teamLogo: game.homeTeam.logo,
              analytics: homeAnalytics,
              color: homeColor,
              isHome: true,
            ),

            const SizedBox(height: 14),

            // ── ATTACKING PRODUCTION ────────────────────────────────────────
            _ComparisonCard(
              title: 'ATTACKING PRODUCTION',
              children: [
                _ComparisonRow(
                  label: 'GOALS',
                  awayValue: awayData.goals.toString(),
                  homeValue: homeData.goals.toString(),
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.sports_soccer_rounded,
                ),
                _ComparisonRow(
                  label: 'TOTAL SHOTS',
                  awayValue: awayData.totalShots.toString(),
                  homeValue: homeData.totalShots.toString(),
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.shutter_speed_rounded,
                ),
                _ComparisonRow(
                  label: 'SHOTS ON TARGET',
                  awayValue: '${awayData.shotsOnTarget} (${awayData.shotAccuracy.toStringAsFixed(0)}%)',
                  homeValue: '${homeData.shotsOnTarget} (${homeData.shotAccuracy.toStringAsFixed(0)}%)',
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.my_location,  // ← FIXED: Use Icons.target
                ),
                _ComparisonRow(
                  label: 'SHOT CONVERSION',
                  awayValue: awayData.totalShots > 0
                      ? '${(awayData.goals / awayData.totalShots * 100).toStringAsFixed(0)}%'
                      : '0%',
                  homeValue: homeData.totalShots > 0
                      ? '${(homeData.goals / homeData.totalShots * 100).toStringAsFixed(0)}%'
                      : '0%',
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.timeline_rounded,
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── DEFENSIVE & DISCIPLINE ──────────────────────────────────────
            _ComparisonCard(
              title: 'DEFENSIVE & DISCIPLINE',
              children: [
                _ComparisonRow(
                  label: 'SAVES',
                  awayValue: awayData.saves.toString(),
                  homeValue: homeData.saves.toString(),
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.shield_rounded,
                ),
                _ComparisonRow(
                  label: 'OFFSIDES',
                  awayValue: awayData.offsides.toString(),
                  homeValue: homeData.offsides.toString(),
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.flag_rounded,
                ),
                _ComparisonRow(
                  label: 'FOULS',
                  awayValue: awayData.fouls.toString(),
                  homeValue: homeData.fouls.toString(),
                  awayColor: awayColor,
                  homeColor: homeColor,
                  icon: Icons.warning_amber_rounded,
                ),
                _CardComparisonRow(
                  awayYellow: awayData.yellowCards,
                  awayRed: awayData.redCards,
                  homeYellow: homeData.yellowCards,
                  homeRed: homeData.redCards,
                  awayColor: awayColor,
                  homeColor: homeColor,
                  awayName: game.awayTeam.abbreviation,
                  homeName: game.homeTeam.abbreviation,
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── TACTICAL DOMINANCE ──────────────────────────────────────────
            _ComparisonCard(
              title: 'TACTICAL DOMINANCE',
              children: [
                _TacticalRow(
                  label: 'POSSESSION',
                  awayValue: awayData.possession,
                  homeValue: homeData.possession,
                  awayColor: awayColor,
                  homeColor: homeColor,
                  suffix: '%',
                ),
                _TacticalRow(
                  label: 'PASS ACCURACY',
                  awayValue: awayData.passingAccuracy,
                  homeValue: homeData.passingAccuracy,
                  awayColor: awayColor,
                  homeColor: homeColor,
                  suffix: '%',
                ),
                _TacticalRow(
                  label: 'SHOT ACCURACY',
                  awayValue: awayData.shotAccuracy,
                  homeValue: homeData.shotAccuracy,
                  awayColor: awayColor,
                  homeColor: homeColor,
                  suffix: '%',
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Map<String, double> _calculateTeamAnalytics(TeamAnalyticsData data) {
    // ── ATTACK SCORE ──────────────────────────────────────────────────────
    // Improved attack metrics based on:
    // 1. Goals scored (direct output) - 35% weight
    // 2. Total shots (volume) - 20% weight
    // 3. Shots on target (accuracy) - 20% weight
    // 4. Shot conversion rate (efficiency) - 15% weight
    // 5. Goals per shot (clinical finishing) - 10% weight

    double attackScore = 0;

    // ── Goals (35% weight) ──────────────────────────────────────────────
    // 0 goals = 0, 1 goal = 17.5, 2 goals = 35, 3+ goals = 52.5 (max 52.5)
    double goalsScore = (data.goals * 17.5).clamp(0.0, 52.5);

    // ── Total Shots (20% weight) ────────────────────────────────────────
    // 0 shots = 0, 10 shots = 15, 20+ shots = 30 (max 30)
    double shotsScore = (data.totalShots * 1.5).clamp(0.0, 30.0);

    // ── Shots on Target (20% weight) ────────────────────────────────────
    // 0 SOT = 0, 5 SOT = 20, 10+ SOT = 30 (max 30)
    // FIXED: Convert int to double using .toDouble()
    double shotsOnTargetScore = (data.shotsOnTarget * 3.0).clamp(0.0, 30.0);

    // ── Shot Conversion Rate (15% weight) ──────────────────────────────
    // Goals / Total Shots * 100 (max 22.5 points)
    double conversionRate = data.totalShots > 0
        ? (data.goals / data.totalShots * 100)
        : 0.0;
    double conversionScore = (conversionRate / 100 * 22.5).clamp(0.0, 22.5);

    // ── Goals per Shot Efficiency (10% weight) ──────────────────────────
    // Shots on Target / Total Shots * 100 (max 15 points)
    double shotEfficiency = data.totalShots > 0
        ? (data.shotsOnTarget / data.totalShots * 100)
        : 0.0;
    double efficiencyScore = (shotEfficiency / 100 * 15).clamp(0.0, 15.0);

    attackScore = (goalsScore + shotsScore + shotsOnTargetScore + conversionScore + efficiencyScore)
        .clamp(0.0, 100.0);

    // ── DEFENSE SCORE ──────────────────────────────────────────────────────
    // Saves (40%) + Clean Sheet Bonus (30%) + Fouls (30%)
    double defenseScore = 0;

    // Saves contribution (max 40 points for 10+ saves)
    // FIXED: Convert int to double using .toDouble()
    double savesScore = (data.saves * 4.0).clamp(0.0, 40.0);

    // Clean sheet bonus (max 30 points if 0 goals conceded)
    double cleanSheetScore = data.saves >= 5 ? 20.0 : 0;

    // Fouls (lower is better) - max 30 points for 0 fouls
    double foulsScore = ((1 - (data.fouls / 30.0)) * 30).clamp(0.0, 30.0);

    defenseScore = (savesScore + cleanSheetScore + foulsScore).clamp(0.0, 100.0);

    // ── POSSESSION SCORE ──────────────────────────────────────────────────
    double possessionScore = data.possession.clamp(0.0, 100.0);

    // ── MIDFIELD SCORE ────────────────────────────────────────────────────
    // Passing Accuracy (60%) + Possession (40%)
    double midfieldScore = ((data.passingAccuracy * 0.6) + (data.possession * 0.4))
        .clamp(0.0, 100.0);

    // ── DISCIPLINE SCORE ─────────────────────────────────────────────────
    // Yellow cards (60%) + Red cards (40%)
    double disciplineScore = 0;

    // Yellow cards (max 60 points for 0 yellows)
    double yellowScore = ((1 - (data.yellowCards / 10.0)) * 60).clamp(0.0, 60.0);

    // Red cards (max 40 points for 0 reds)
    double redScore = ((1 - (data.redCards / 3.0)) * 40).clamp(0.0, 40.0);

    disciplineScore = (yellowScore + redScore).clamp(0.0, 100.0);

    // ── Debug output ──────────────────────────────────────────────────────
    print('[Analytics] Attack breakdown:');
    print('  Goals: ${data.goals} → goalsScore: $goalsScore');
    print('  Total Shots: ${data.totalShots} → shotsScore: $shotsScore');
    print('  Shots on Target: ${data.shotsOnTarget} → sotScore: $shotsOnTargetScore');
    print('  Conversion Rate: ${conversionRate.toStringAsFixed(1)}% → convScore: $conversionScore');
    print('  Shot Efficiency: ${shotEfficiency.toStringAsFixed(1)}% → effScore: $efficiencyScore');
    print('  Total Attack Score: $attackScore');

    return {
      'Attack': attackScore,
      'Defense': defenseScore,
      'Possess.': possessionScore,
      'Midfield': midfieldScore,
      'Discipline': disciplineScore,
    };
  }
}

// ─── Team Performance Card ────────────────────────────────────────────────────
class _TeamPerformanceCard extends StatelessWidget {
  final String teamName;
  final String teamFullName;
  final String teamLogo;
  final Map<String, double> analytics;
  final Color color;
  final bool isHome;

  const _TeamPerformanceCard({
    required this.teamName,
    required this.teamFullName,
    required this.teamLogo,
    required this.analytics,
    required this.color,
    required this.isHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.10), _shadeLighten(color, 0.25).withOpacity(0.05)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: color.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withOpacity(0.2),
                    ),
                  ),
                  child: Image.network(
                    teamLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.sports_soccer,
                      color: color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamFullName.isNotEmpty ? teamFullName : teamName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isHome ? 'HOME TEAM' : 'AWAY TEAM',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, _shadeDarken(color, 0.18)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    '${_calculateOverallRating(analytics).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Radar Chart ──────────────────────────────────────────────────
          // ── Radar Chart ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(  // Wrap with CustomPaint
                painter: _SingleRadarPainter(
                  stats: analytics,
                  color: color,
                  isDarkMode: false,
                ),
              ),
            ),
          ),
          // ── Stats Labels ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: analytics.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key}: ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _C.muted,
                        ),
                      ),
                      Text(
                        '${entry.value.toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateOverallRating(Map<String, double> stats) {
    final values = stats.values.toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

// ─── Single Radar Painter ─────────────────────────────────────────────────────
class _SingleRadarPainter extends CustomPainter {
  final Map<String, double> stats;
  final Color color;
  final bool isDarkMode;

  _SingleRadarPainter({
    required this.stats,
    required this.color,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.6;
    final keys = stats.keys.toList();
    final int sides = keys.length;
    final double angle = (2 * math.pi) / sides;

    // Grid lines
    final gridPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final level in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final a = i * angle - (math.pi / 2);
        final x = center.dx + radius * level * math.cos(a);
        final y = center.dy + radius * level * math.sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Radial lines
    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      canvas.drawLine(
        center,
        Offset(center.dx + radius * math.cos(a), center.dy + radius * math.sin(a)),
        gridPaint,
      );
    }

    // Build the data path first so we can size the gradient/glow to it.
    final secondary = _shadeLighten(color, 0.22);
    final dataPath = Path();
    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final val = (stats[keys[i]] ?? 0).clamp(0.0, 100.0) / 100.0;
      final x = center.dx + radius * val * math.cos(a);
      final y = center.dy + radius * val * math.sin(a);
      i == 0 ? dataPath.moveTo(x, y) : dataPath.lineTo(x, y);
    }
    dataPath.close();

    // Soft outer glow using the club's primary color for a futuristic feel.
    final glowPaint = Paint()
      ..color = color.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(dataPath, glowPaint);

    // Fill area — primary → lighter secondary gradient, radiating from center.
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [secondary.withOpacity(0.38), color.withOpacity(0.16)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..shader = LinearGradient(
        colors: [color, secondary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Data points — small dual-tone dots so each vertex pops.
    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final val = (stats[keys[i]] ?? 0).clamp(0.0, 100.0) / 100.0;
      final pt = Offset(center.dx + radius * val * math.cos(a),
          center.dy + radius * val * math.sin(a));
      canvas.drawCircle(pt, 5, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 4, Paint()..color = color);
      canvas.drawCircle(pt, 1.6, Paint()..color = secondary);
    }

    // Labels
    final textStyle = TextStyle(
      color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final lx = center.dx + (radius + 30) * math.cos(a);
      final ly = center.dy + (radius + 28) * math.sin(a);

      final labelPainter = TextPainter(
        text: TextSpan(text: keys[i].toUpperCase(), style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      labelPainter.paint(canvas,
          Offset(lx - labelPainter.width / 2, ly - labelPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SingleRadarPainter old) =>
      old.stats != stats || old.color != color;
}

// ─── Comparison Card ──────────────────────────────────────────────────────────
class _ComparisonCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ComparisonCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _C.bg.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: const Border(
                bottom: BorderSide(color: _C.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _C.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _C.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comparison Row ───────────────────────────────────────────────────────────
class _ComparisonRow extends StatelessWidget {
  final String label;
  final String awayValue;
  final String homeValue;
  final Color awayColor;
  final Color homeColor;
  final IconData icon;
  final bool isLast;

  const _ComparisonRow({
    required this.label,
    required this.awayValue,
    required this.homeValue,
    required this.awayColor,
    required this.homeColor,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: _C.muted.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.text,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: awayColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: awayColor.withOpacity(0.15),
              ),
            ),
            child: Text(
              awayValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: awayColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'vs',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _C.muted,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: homeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: homeColor.withOpacity(0.15),
              ),
            ),
            child: Text(
              homeValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: homeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Comparison Row ──────────────────────────────────────────────────────
class _CardComparisonRow extends StatelessWidget {
  final int awayYellow, awayRed, homeYellow, homeRed;
  final Color awayColor, homeColor;
  final String awayName, homeName;
  final bool isLast;

  const _CardComparisonRow({
    required this.awayYellow,
    required this.awayRed,
    required this.homeYellow,
    required this.homeRed,
    required this.awayColor,
    required this.homeColor,
    required this.awayName,
    required this.homeName,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          const Icon(
            Icons.credit_card_rounded,
            size: 14,
            color: _C.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: const Text(
              'CARDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.text,
              ),
            ),
          ),
          // Away team cards
          Row(
            children: [
              if (awayYellow > 0 || awayRed > 0) ...[
                if (awayYellow > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$awayYellow',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: awayColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                if (awayRed > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$awayRed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: awayColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(width: 6),
          const Text(
            'vs',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _C.muted,
            ),
          ),
          const SizedBox(width: 6),
          // Home team cards
          Row(
            children: [
              if (homeYellow > 0 || homeRed > 0) ...[
                if (homeYellow > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$homeYellow',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: homeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                if (homeRed > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$homeRed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: homeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tactical Row ─────────────────────────────────────────────────────────────
class _TacticalRow extends StatelessWidget {
  final String label;
  final double awayValue;
  final double homeValue;
  final Color awayColor;
  final Color homeColor;
  final String suffix;
  final bool isLast;

  const _TacticalRow({
    required this.label,
    required this.awayValue,
    required this.homeValue,
    required this.awayColor,
    required this.homeColor,
    required this.suffix,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = awayValue + homeValue;
    final awayFrac = total > 0 ? awayValue / total : 0.5;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _C.text,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${awayValue.toStringAsFixed(0)}$suffix',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: awayColor,
                    ),
                  ),
                  const Text(
                    ' / ',
                    style: TextStyle(
                      fontSize: 11,
                      color: _C.muted,
                    ),
                  ),
                  Text(
                    '${homeValue.toStringAsFixed(0)}$suffix',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: homeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                  flex: (awayFrac * 100).round().clamp(5, 95),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: awayColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        bottomLeft: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1 - awayFrac) * 100).round().clamp(5, 95),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: homeColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(3),
                        bottomRight: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared color helpers ─────────────────────────────────────────────────────
Color _shadeLighten(Color c, [double amt = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
}

Color _shadeDarken(Color c, [double amt = 0.22]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness * (1 - amt)).clamp(0.0, 1.0)).toColor();
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
Widget _card(Widget child) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _C.card, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _C.border.withOpacity(0.7)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

Widget _SectionTitle(String t) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t,
        style: const TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );
}

class _NoDataWidget extends StatelessWidget {
  final IconData icon; final String message;
  const _NoDataWidget({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: _C.muted, size: 52),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: _C.muted, fontSize: 14)),
    ]));
  }
}

String _fmtNum(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}K' : '$n';