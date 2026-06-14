import 'dart:async';
import 'dart:math' as math;
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
  static const liveGlow  = Color(0x22DC2626);
  static const green     = Color(0xFF16A34A);
  static const yellow    = Color(0xFFCA8A04);
  static const red       = Color(0xFFDC2626);
  static const pitchGreen  = Color(0xFF166534);
  static const pitchLight  = Color(0xFF15803D);
  static const pitchLine   = Color(0x88FFFFFF);
  static const homeAccent  = Color(0xFF1A56DB);
  static const awayAccent  = Color(0xFFEA580C);
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

class H2HResult {
  final String date;
  final String homeTeam;
  final String awayTeam;
  final String homeScore;
  final String awayScore;
  final String result;

  const H2HResult({
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.result,
  });
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
  late Future<List<H2HResult>> _h2hFuture;

  final SportService _sport = SportService();

  Timer? _clockTimer;
  int _liveTick = 0;
  Duration _countdown = Duration.zero;

  bool get _isLive     => widget.game.status == 'STATUS_LIVE';
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
  }

  void _refresh() {
    _detailFuture    = _sport.getGameDetail(widget.game.id);
    _standingsFuture = _fetchStandings();
    _lineupFuture    = _fetchLineup();
    _h2hFuture       = _fetchH2H();
  }

  Future<List<Standing>> _fetchStandings() async {
    // Find league code by matching leagueName or leagueFlag
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

  Future<List<H2HResult>> _fetchH2H() async {
    try {
      return await _sport.getH2H(
        widget.game.awayTeam.id,
        widget.game.homeTeam.id,
        widget.game.id,
      );
    } catch (_) { return []; }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  Color _teamColor(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return _C.blue;
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: _C.text, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _C.muted, size: 20),
                onPressed: () => setState(_refresh),
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      awayColor.withOpacity(0.25),
                      _C.surface,
                      homeColor.withOpacity(0.25),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                    child: _HeroScore(
                      game: widget.game,
                      isLive: _isLive,
                      isDone: _isDone,
                      isUpcoming: _isUpcoming,
                      liveTick: _liveTick,
                      countdown: _countdown,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Container(
              color: _C.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _C.blue, width: 2.5)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: _C.blue,
                unselectedLabelColor: _C.muted,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                dividerColor: _C.border,
                tabs: const [
                  Tab(text: 'MATCH'),
                  Tab(text: 'STATS'),
                  Tab(text: 'LINEUP'),
                  Tab(text: 'TIMELINE'),
                  Tab(text: 'STANDINGS'),
                  Tab(text: 'H2H'),
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
                      _TimelineTab(game: widget.game, detail: detail),
                      _StandingsTab(future: _standingsFuture, game: widget.game),
                      _H2HTab(future: _h2hFuture, game: widget.game),
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

// ─── Hero Score Block ─────────────────────────────────────────────────────────
class _HeroScore extends StatelessWidget {
  final Game game;
  final bool isLive, isDone, isUpcoming;
  final int liveTick;
  final Duration countdown;

  const _HeroScore({
    required this.game, required this.isLive, required this.isDone,
    required this.isUpcoming, required this.liveTick, required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _TeamHero(team: game.awayTeam, isHome: false)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
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
        Expanded(child: _TeamHero(team: game.homeTeam, isHome: true)),
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
  const _TeamHero({required this.team, required this.isHome});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60, height: 60,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
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

  // REQ 1: No emojis — use Flutter Icons only
  String _statusLabel(String s) {
    if (s == 'STATUS_LIVE') return 'Live';
    if (s == 'STATUS_FINAL') return 'Full Time';
    return 'Upcoming';
  }

  Widget _statusIcon(String s) {
    if (s == 'STATUS_LIVE') return const Icon(Icons.circle, color: _C.liveRed, size: 10);
    if (s == 'STATUS_FINAL') return const Icon(Icons.check_circle_rounded, color: _C.green, size: 14);
    return const Icon(Icons.schedule_rounded, color: _C.blue, size: 14);
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
        // REQ 1: Use Icon instead of emoji ball
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
//  TAB 2 — STATS  (REQ 2: Top 10 stats + See More)
// ═══════════════════════════════════════════════════════════════════════════════
class _StatsTab extends StatefulWidget {
  final Game game;
  final GameDetail? detail;
  final bool isUpcoming;
  final Duration countdown;
  final int liveTick;

  const _StatsTab({
    required this.game, required this.detail,
    required this.isUpcoming, required this.countdown, required this.liveTick,
  });

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  bool _showAll = false;

  // REQ 2: Exactly these 10 stats shown first, all in CAPS
  static const List<String> _primaryKeys = [
    'possessionPct',
    'totalShots',
    'shotsOnTarget',
    'saves',
    'yellowCards',
    'redCards',
    'passes',
    'passingAccuracy',
    'tackles',
    'effectiveTackles',
  ];

  static const Map<String, String> _labels = {
    'possessionPct':    'POSSESSION',
    'totalShots':       'TOTAL SHOTS',
    'shotsOnTarget':    'SHOTS ON TARGET',
    'saves':            'SAVES',
    'yellowCards':      'YELLOW CARDS',
    'redCards':         'RED CARDS',
    'passes':           'TOTAL PASSES',
    'passingAccuracy':  'ACCURATE PASSES',
    'tackles':          'TOTAL TACKLES',
    'effectiveTackles': 'EFFECTIVE TACKLES',
    // extras still shown under See More:
    'goals':            'GOALS',
    'assists':          'ASSISTS',
    'passesAttempted':  'PASSES ATTEMPTED',
    'fouls':            'FOULS',
    'offsides':         'OFFSIDES',
    'corners':          'CORNERS',
    'penalties':        'PENALTIES',
    'blockedShots':     'BLOCKED SHOTS',
    'clearances':       'CLEARANCES',
    'aerialDuels':      'AERIAL DUELS WON',
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

    // Build ordered list: primary first, then rest
    final allAvailableKeys = <String>{...awayStats.keys, ...homeStats.keys};
    final primaryAvailable  = _primaryKeys.where(allAvailableKeys.contains).toList();
    final extraKeys = allAvailableKeys.where((k) => !_primaryKeys.contains(k)).toList();

    final displayedKeys = _showAll ? [...primaryAvailable, ...extraKeys] : primaryAvailable;

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
            ...displayedKeys.map((key) => _StatBarRow(
              label: _labels[key] ?? _camelToTitle(key),
              awayValue: awayStats[key] ?? '0',
              homeValue: homeStats[key] ?? '0',
              awayColor: _C.awayAccent,
              homeColor: _C.homeAccent,
              isPossession: key == 'possessionPct',
            )),
            // See More / See Less button
            if (extraKeys.isNotEmpty) ...[
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
                        _showAll ? 'SEE LESS' : 'SEE MORE (${extraKeys.length} more stats)',
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
                    _CountdownColon(),
                  ],
                  _CountdownUnit('${h.remainder(24).toString().padLeft(2, '0')}', 'HRS'),
                  _CountdownColon(),
                  _CountdownUnit(m, 'MIN'),
                  _CountdownColon(),
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

class _CountdownUnit extends StatelessWidget {
  final String value, label;
  const _CountdownUnit(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.blueSoft, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.blue.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(color: _C.blue, fontSize: 30, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
        Text(label, style: const TextStyle(color: _C.muted, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _CountdownColon extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.only(bottom: 14), child: Text(':', style: TextStyle(color: _C.blue, fontSize: 28, fontWeight: FontWeight.w700)));
}

class _TeamStatHeader extends StatelessWidget {
  final TeamInfo team;
  final CrossAxisAlignment align;
  const _TeamStatHeader({required this.team, required this.align});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: align, children: [
      Image.network(team.logo, width: 34, height: 34,
          errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, color: _C.muted, size: 24)),
      const SizedBox(height: 4),
      Text(team.abbreviation, style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _StatBarRow extends StatelessWidget {
  final String label, awayValue, homeValue;
  final Color awayColor, homeColor;
  final bool isPossession;

  const _StatBarRow({
    required this.label, required this.awayValue, required this.homeValue,
    required this.awayColor, required this.homeColor, required this.isPossession,
  });

  @override
  Widget build(BuildContext context) {
    final aNum  = _toNum(awayValue);
    final hNum  = _toNum(homeValue);
    final total = aNum + hNum;
    final aFrac = total > 0 ? aNum / total : 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 44, child: Text(
            isPossession ? '$awayValue%' : awayValue,
            style: TextStyle(color: awayColor, fontSize: 14, fontWeight: FontWeight.w800),
          )),
          Expanded(child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w600))),
          SizedBox(width: 44, child: Text(
            isPossession ? '$homeValue%' : homeValue,
            style: TextStyle(color: homeColor, fontSize: 14, fontWeight: FontWeight.w800),
            textAlign: TextAlign.right,
          )),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(children: [
            Expanded(flex: (aFrac * 100).round().clamp(5, 95),
                child: Container(height: 5, color: awayColor)),
            Expanded(flex: ((1 - aFrac) * 100).round().clamp(5, 95),
                child: Container(height: 5, color: homeColor)),
          ]),
        ),
      ]),
    );
  }

  double _toNum(String v) => double.tryParse(v.replaceAll('%', '').replaceAll(',', '')) ?? 0;
}


// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 3 — LINEUP  (uses FootballPitch from football_pitch_lineup.dart)
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
  // Formation can be changed interactively; initialised from API data.
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

  // Convert our MatchLineup → FootballPitch TeamLineup models
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
        // ── Header row: away formation | toggle | home formation ─────────────
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
          // ── Away formation selector ───────────────────────────────────────
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

          // ── Football pitch ────────────────────────────────────────────────
          FootballPitch(
            homeTeam: homeLineup,
            awayTeam: awayLineup,
            showRatings: !widget.isUpcoming,
            onPlayerTap: (player) => _showPlayerSheet(context, player),
          ),

          // ── Home formation selector ───────────────────────────────────────
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

          // ── Rating note for upcoming ──────────────────────────────────────
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
          // ── Substitutes section ───────────────────────────────────────────
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

// ─── Player bottom sheet on tap ────────────────────────────────────────────────
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
        // Avatar
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

// ─── Formation header chip (shows team logo + name + formation badge) ──────────
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

// ─── Starters/Subs toggle ──────────────────────────────────────────────────────
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
//  TAB 4 — TIMELINE  (REQ 4: centered events, kickoff/HT/FT with Flutter icons)
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
        // Column headers
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

    // REQ 4: Kickoff as centered event with Flutter icon
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

    // REQ 4: Half Time as centered milestone with score
    if (game.awayLineScores.isNotEmpty) {
      final ah = game.awayLineScores[0];
      final hh = game.homeLineScores.isNotEmpty ? game.homeLineScores[0] : 0;
      events.add(_TLEvent(
        minute: 45, type: _TLType.halfTime,
        label: 'HALF TIME', sub: '$ah – $hh', isHome: null,
      ));
    }

    // REQ 4: Full Time as centered milestone with final score
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

// REQ 4: Redesigned timeline row — centered milestones with a continuous vertical
// line, left/right player events that stay properly aligned on screen.
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
      // REQ 4: Milestone row — centered with horizontal dividers on each side
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

    // REQ 4: Left/right player events — minute badge always in center column,
    // player info fills the correct side, no off-center drift.
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
          // Home: left side empty, center min, right side player
          const Expanded(child: SizedBox()),
          minBadge,
          const SizedBox(width: 8),
          Expanded(child: playerBlock),
        ]
            : [
          // Away: left side player, center min, right side empty
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
    // REQ 1: No emoji — use Flutter official icons for all events
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
//  TAB 5 — STANDINGS  (REQ 5: Full league table for that game's league)
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
            // League header
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
            // Both teams at a glance
            _card(Row(children: [
              _MiniTeamTag(team: game.awayTeam, color: _C.awayAccent, standing: _findStanding(list, game.awayTeam.id)),
              const Spacer(),
              const Text('vs', style: TextStyle(color: _C.muted, fontSize: 11)),
              const Spacer(),
              _MiniTeamTag(team: game.homeTeam, color: _C.homeAccent, standing: _findStanding(list, game.homeTeam.id)),
            ])),
            const SizedBox(height: 12),
            // Full standings table
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
//  TAB 6 — H2H  (REQ 6: Head-to-head collision details)
// ═══════════════════════════════════════════════════════════════════════════════
class _H2HTab extends StatelessWidget {
  final Future<List<H2HResult>> future;
  final Game game;
  const _H2HTab({required this.future, required this.game});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<H2HResult>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.blue));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _NoDataWidget(icon: Icons.compare_arrows_rounded, message: 'No head-to-head history found');
        }

        int awayWins = 0, homeWins = 0, draws = 0;
        int awayGoals = 0, homeGoals = 0;
        for (final r in list) {
          final aG = int.tryParse(r.awayScore) ?? 0;
          final hG = int.tryParse(r.homeScore) ?? 0;
          final awayIsAwayNow = r.awayTeam == game.awayTeam.abbreviation || r.awayTeam == game.awayTeam.id;
          awayGoals += awayIsAwayNow ? aG : hG;
          homeGoals += awayIsAwayNow ? hG : aG;

          if (r.result == 'draw') draws++;
          else if ((r.result == 'home_win' && (r.homeTeam == game.homeTeam.id || r.homeTeam == game.homeTeam.abbreviation)) ||
              (r.result == 'away_win' && (r.awayTeam == game.homeTeam.id || r.awayTeam == game.homeTeam.abbreviation))) {
            homeWins++;
          } else {
            awayWins++;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _card(_H2HSummary(
              awayTeam: game.awayTeam, homeTeam: game.homeTeam,
              awayWins: awayWins, draws: draws, homeWins: homeWins,
              awayGoals: awayGoals, homeGoals: homeGoals,
            )),
            const SizedBox(height: 14),
            _SectionTitle('LAST ${list.length} MEETING${list.length == 1 ? "" : "S"}'),
            const SizedBox(height: 8),
            ...list.map((r) => _H2HRow(result: r, game: game)),
          ],
        );
      },
    );
  }
}

class _H2HSummary extends StatelessWidget {
  final TeamInfo awayTeam, homeTeam;
  final int awayWins, draws, homeWins, awayGoals, homeGoals;
  const _H2HSummary({
    required this.awayTeam, required this.homeTeam,
    required this.awayWins, required this.draws, required this.homeWins,
    required this.awayGoals, required this.homeGoals,
  });

  @override
  Widget build(BuildContext context) {
    final total = awayWins + draws + homeWins;
    final aF = total > 0 ? awayWins / total : 0.33;
    final dF = total > 0 ? draws / total : 0.34;
    final hF = total > 0 ? homeWins / total : 0.33;

    return Column(children: [
      Row(children: [
        _H2HTeamStat(team: awayTeam, wins: awayWins, goals: awayGoals, color: _C.awayAccent),
        Expanded(child: Column(children: [
          Text('$draws', style: const TextStyle(color: _C.muted, fontSize: 24, fontWeight: FontWeight.w900)),
          const Text('DRAWS', style: TextStyle(color: _C.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ])),
        _H2HTeamStat(team: homeTeam, wins: homeWins, goals: homeGoals, color: _C.homeAccent),
      ]),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(children: [
          if (awayWins > 0) Expanded(flex: (aF * 100).round(), child: Container(height: 8, color: _C.awayAccent)),
          if (draws > 0)    Expanded(flex: (dF * 100).round(), child: Container(height: 8, color: _C.muted.withOpacity(0.4))),
          if (homeWins > 0) Expanded(flex: (hF * 100).round(), child: Container(height: 8, color: _C.homeAccent)),
          if (total == 0)   Expanded(child: Container(height: 8, color: _C.border)),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Text('$awayGoals goals scored', style: const TextStyle(color: _C.muted, fontSize: 10)),
        const Spacer(),
        Text('$homeGoals goals scored', style: const TextStyle(color: _C.muted, fontSize: 10)),
      ]),
    ]);
  }
}

class _H2HTeamStat extends StatelessWidget {
  final TeamInfo team; final int wins, goals; final Color color;
  const _H2HTeamStat({required this.team, required this.wins, required this.goals, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Image.network(team.logo, width: 38, height: 38,
          errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, color: _C.muted, size: 28)),
      const SizedBox(height: 4),
      Text('$wins', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
      const Text('WINS', style: TextStyle(color: _C.muted, fontSize: 9, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _H2HRow extends StatelessWidget {
  final H2HResult result; final Game game;
  const _H2HRow({required this.result, required this.game});

  @override
  Widget build(BuildContext context) {
    final isHomWin  = result.result == 'home_win';
    final isAwayWin = result.result == 'away_win';
    final dot = result.result == 'draw' ? _C.muted : isHomWin ? _C.homeAccent : _C.awayAccent;

    String dateStr = '';
    try {
      final d = DateTime.parse(result.date);
      dateStr = '${d.day}/${d.month}/${d.year}';
    } catch (_) { dateStr = result.date; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 10, color: _C.muted),
            const SizedBox(width: 4),
            Text(dateStr, style: const TextStyle(color: _C.muted, fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(result.awayTeam,
                style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: dot.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dot.withOpacity(0.35)),
              ),
              child: Text('${result.awayScore}  –  ${result.homeScore}',
                  style: TextStyle(color: dot, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
            Expanded(child: Text(result.homeTeam,
                style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              result.result == 'draw' ? Icons.horizontal_rule_rounded : Icons.emoji_events_rounded,
              size: 11, color: dot,
            ),
            const SizedBox(width: 3),
            Text(
              result.result == 'draw' ? 'Draw'
                  : (isHomWin ? '${result.homeTeam} Won' : '${result.awayTeam} Won'),
              style: TextStyle(color: dot, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ])),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
Widget _card(Widget child) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
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