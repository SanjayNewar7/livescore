import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/screens/game_detail_screen.dart';
import '../providers/app_provider.dart';

// ─── Design Tokens ─────────────────────────────────────────────────────────────
class _C {
  static const blue      = Color(0xFF1A62C8);
  static const blueLight = Color(0xFFE8F0FC);
  static const border    = Color(0xFFE2E8F2);
  static const surface   = Color(0xFFFFFFFF);
  static const text      = Color(0xFF0F1623);
  static const muted     = Color(0xFF6B7A96);
  static const liveRed   = Color(0xFFE53535);
  static const liveRedBg = Color(0xFFFEF2F2);
  static const red       = Color(0xFFDC2626);
  static const greenGoal = Color(0xFF16A34A);
  static const purple    = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF3F0FF);
  static const orange    = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFF7ED);
}

// ─── Public GameCard ───────────────────────────────────────────────────────────
class GameCard extends StatefulWidget {
  final Game game;
  const GameCard({super.key, required this.game});

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  Timer? _timer;
  Timer? _refreshTimer;
  Duration _countdown = Duration.zero;

  // Local copy of game data that can be updated without rebuilding parent
  late Game _currentGame;

  @override
  void initState() {
    super.initState();
    _currentGame = widget.game;
    _tick();

    if (widget.game.status == 'STATUS_SCHEDULED') {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _tick());
      });
    } else if (widget.game.status == 'STATUS_LIVE') {
      // For live matches: refresh game data every 3 seconds to get updated clock from API
      _startLiveRefreshTimer();
    }
  }

  void _startLiveRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;

      try {
        // Fetch fresh game data from provider
        final freshGame = await _getFreshGameData(_currentGame.id);

        if (freshGame != null && mounted) {
          setState(() {
            _currentGame = freshGame;
          });
        }
      } catch (e) {
        // Silently fail - keep existing data
      }
    });
  }

  Future<Game?> _getFreshGameData(String gameId) async {
    // Try to get from provider's existing games
    if (!mounted) return null;

    // Use Provider.of with listen: false to avoid rebuilds
    final provider = Provider.of<AppProvider>(context, listen: false);
    final allGames = provider.allGames;

    // Find the game in current provider data
    try {
      return allGames.firstWhere((g) => g.id == gameId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_currentGame.status == 'STATUS_SCHEDULED') {
      try {
        final kickOff = DateTime.parse(_currentGame.date).toLocal();
        final diff = kickOff.difference(DateTime.now());
        _countdown = diff.isNegative ? Duration.zero : diff;
      } catch (_) {
        _countdown = Duration.zero;
      }
    }
  }

  String get _localKickOff {
    try {
      return DateFormat('h:mm a').format(DateTime.parse(_currentGame.date).toLocal());
    } catch (_) {
      return 'TBD';
    }
  }

  String get _localDateFull {
    try {
      final d = DateTime.parse(_currentGame.date).toLocal();
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String get _countdownStr {
    if (_countdown == Duration.zero) return 'Starting soon';
    final h = _countdown.inHours;
    final m = _countdown.inMinutes % 60;
    final s = _countdown.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  // Direct from API - this is the SOURCE OF TRUTH
  String get _liveClock {
    final clock = _currentGame.clock;
    if (clock.isEmpty) return 'LIVE';

    // Return exact clock from ESPN API (e.g., "45+1", "73", "90+3", "HT")
    return "$clock'";
  }

  @override
  Widget build(BuildContext context) {
    final isLive = _currentGame.status == 'STATUS_LIVE';
    final isDone = _currentGame.status == 'STATUS_FINAL';
    final isUpcoming = _currentGame.status == 'STATUS_SCHEDULED';
    final matchNote = _currentGame.shortDetail.trim();

    final venueLine = _currentGame.venue.fullName.isNotEmpty
        ? (_currentGame.venue.city.isNotEmpty
        ? '${_currentGame.venue.fullName}, ${_currentGame.venue.city}'
        : _currentGame.venue.fullName)
        : '';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: Colors.black12,
      color: _C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameDetailScreen(game: _currentGame)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (matchNote.isNotEmpty)
                    Expanded(
                      child: _MatchNoteChip(
                        note: matchNote,
                        isLive: isLive,
                        status: _currentGame.status,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  const SizedBox(width: 8),
                  if (isLive)
                    const _LiveBadge()
                  else if (isDone)
                    _Badge('FT', bg: const Color(0xFFF1F3F8), fg: _C.muted)
                  else
                    _Badge(_localKickOff, bg: _C.blueLight, fg: _C.blue),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TeamCol(
                      logo: _currentGame.awayTeam.logo,
                      abbr: _currentGame.awayTeam.abbreviation,
                      fullName: _currentGame.awayTeamFullName.isNotEmpty
                          ? _currentGame.awayTeamFullName
                          : (_currentGame.awayTeam.displayName.isNotEmpty
                          ? _currentGame.awayTeam.displayName
                          : _currentGame.awayTeam.name),
                      score: isLive || isDone ? _currentGame.awayScore : null,
                      isLive: isLive,
                      goals: _currentGame.awayTeamGoals,
                    ),
                  ),
                  _CentreCol(
                    isLive: isLive,
                    isDone: isDone,
                    isUpcoming: isUpcoming,
                    liveClock: _liveClock,  // Uses API clock data
                    kickOffTime: _localKickOff,
                    awayScore: _currentGame.awayScore,
                    homeScore: _currentGame.homeScore,
                  ),
                  Expanded(
                    child: _TeamCol(
                      logo: _currentGame.homeTeam.logo,
                      abbr: _currentGame.homeTeam.abbreviation,
                      fullName: _currentGame.homeTeamFullName.isNotEmpty
                          ? _currentGame.homeTeamFullName
                          : (_currentGame.homeTeam.displayName.isNotEmpty
                          ? _currentGame.homeTeam.displayName
                          : _currentGame.homeTeam.name),
                      score: isLive || isDone ? _currentGame.homeScore : null,
                      isLive: isLive,
                      goals: _currentGame.homeTeamGoals,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF0F2F7)),
              const SizedBox(height: 7),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: _localDateFull,
                  ),
                  if (isUpcoming) ...[
                    if (_countdown > Duration.zero) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: 'in $_countdownStr',
                        color: _C.blue,
                      ),
                    ],
                    if (venueLine.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.stadium_rounded,
                          label: venueLine,
                          expand: true,
                        ),
                      ),
                    ],
                  ] else if (isLive || isDone) ...[
                    if (venueLine.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.stadium_rounded,
                          label: venueLine,
                          expand: true,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Match Note Chip (Clean text - no background, no emojis, +2pt) ─────────────
class _MatchNoteChip extends StatelessWidget {
  final String note;
  final bool isLive;
  final String status;

  const _MatchNoteChip({
    required this.note,
    required this.isLive,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final lowerNote = note.toLowerCase();
    final isSpecial = lowerNote.contains('final') ||
        lowerNote.contains('semi') ||
        lowerNote.contains('quarter') ||
        lowerNote.contains('clásico') ||
        lowerNote.contains('clasico') ||
        lowerNote.contains('derby') ||
        lowerNote.contains('derbi');

    final Color textColor = isLive
        ? _C.liveRed
        : (isSpecial ? _C.purple : _C.muted);

    return Text(
      note,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─── Team Column ───────────────────────────────────────────────────────────────
class _TeamCol extends StatelessWidget {
  final String logo;
  final String abbr;
  final String fullName;
  final String? score;
  final bool isLive;
  final List<GoalScorer> goals;

  const _TeamCol({
    required this.logo,
    required this.abbr,
    required this.fullName,
    required this.score,
    required this.isLive,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 44, height: 44,
          child: logo.isNotEmpty
              ? Image.network(
            logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.sports_soccer_rounded, size: 28, color: _C.muted),
          )
              : const Icon(Icons.sports_soccer_rounded, size: 28, color: _C.muted),
        ),
        const SizedBox(height: 5),
        Text(
          abbr.isNotEmpty ? abbr : fullName,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: _C.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (fullName.isNotEmpty && fullName != abbr)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              fullName,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500, color: _C.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 5),
          ...goals.map((gs) => _GoalLine(scorer: gs)),
        ],
      ],
    );
  }
}

// ─── Goal Line ─────────────────────────────────────────────────────────────────
class _GoalLine extends StatelessWidget {
  final GoalScorer scorer;
  const _GoalLine({required this.scorer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚽', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${scorer.playerName} ${scorer.minuteDisplay}',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: _C.greenGoal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (scorer.isPenalty)
            const Text(' (P)',
                style: TextStyle(fontSize: 9, color: _C.muted, fontWeight: FontWeight.w500)),
          if (scorer.isOwnGoal)
            const Text(' (OG)',
                style: TextStyle(fontSize: 9, color: _C.liveRed, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Centre Column ─────────────────────────────────────────────────────────────
class _CentreCol extends StatelessWidget {
  final bool isLive;
  final bool isDone;
  final bool isUpcoming;
  final String liveClock;
  final String kickOffTime;
  final String awayScore;
  final String homeScore;

  const _CentreCol({
    required this.isLive,
    required this.isDone,
    required this.isUpcoming,
    required this.liveClock,
    required this.kickOffTime,
    required this.awayScore,
    required this.homeScore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLive) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(awayScore,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900, color: _C.liveRed)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text('–',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _C.muted)),
                ),
                Text(homeScore,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900, color: _C.liveRed)),
              ],
            ),
            // Shows EXACT clock from ESPN API: "45+1'", "73'", "90+3'", etc.
            if (liveClock != 'LIVE')
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  liveClock,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: _C.liveRed, letterSpacing: 0.3),
                ),
              ),
          ] else if (isDone) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(awayScore,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900, color: _C.text)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text('–',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _C.muted)),
                ),
                Text(homeScore,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900, color: _C.text)),
              ],
            ),
            const SizedBox(height: 3),
            const Text('Full Time',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: _C.muted)),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: _C.border, borderRadius: BorderRadius.circular(20)),
              child: const Text('VS',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _C.muted)),
            ),
            const SizedBox(height: 5),
            Text(kickOffTime,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _C.blue)),
          ],
        ],
      ),
    );
  }
}

// ─── Info Chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool expand;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = _C.muted,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Badges ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ─── Live Badge (Just "LIVE" with blinking dot - no minute) ────────────────────
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> {
  bool _dotOn = true;
  late Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 700),
            (_) { if (mounted) setState(() => _dotOn = !_dotOn); });
  }

  @override
  void dispose() { _t.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: _C.liveRedBg, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: _dotOn ? 1.0 : 0.15,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                  color: _C.liveRed, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _C.liveRed,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}