import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MODELS — shared with game_detail_screen via export
// ═══════════════════════════════════════════════════════════════════════════════

/// A player on the pitch (starter or substitute).
class PitchPlayer {
  final String id;
  final String name;
  final String shortName;
  final String number;
  final String position;   // 'GK' | 'DEF' | 'MID' | 'FWD'
  final String? imageUrl;  // ESPN headshot URL (nullable — falls back to initials)
  final bool isStarter;
  final bool isHome;
  final double? rating;    // Post-match rating (null = upcoming game)

  const PitchPlayer({
    required this.id,
    required this.name,
    required this.shortName,
    required this.number,
    required this.position,
    this.imageUrl,
    required this.isStarter,
    required this.isHome,
    this.rating,
  });
}

/// A team's full lineup data for the pitch widget.
class TeamLineup {
  final String teamName;
  final String teamLogo;
  final String formation;
  final List<PitchPlayer> starters;
  final List<PitchPlayer> substitutes;
  final Color primaryColor;

  const TeamLineup({
    required this.teamName,
    required this.teamLogo,
    required this.formation,
    required this.starters,
    required this.substitutes,
    required this.primaryColor,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MAIN WIDGET — FootballPitch
// ═══════════════════════════════════════════════════════════════════════════════

/// Full football pitch with both teams positioned by formation.
///
/// Drop this anywhere; it handles its own height via LayoutBuilder.
class FootballPitch extends StatelessWidget {
  final TeamLineup homeTeam;
  final TeamLineup awayTeam;
  final bool showRatings;
  final double? customHeight;
  final void Function(PitchPlayer player)? onPlayerTap;

  const FootballPitch({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.showRatings = false,
    this.customHeight,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = customHeight ?? (w * 1.48).clamp(480.0, 780.0);
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  // ── Pitch background ──────────────────────────────────────
                  CustomPaint(
                    size: Size(w, h),
                    painter: PitchPainter(),
                  ),
                  // ── Away team (top half, attacking downward) ───────────────
                  Positioned.fill(
                    child: _PlayersLayer(
                      players: awayTeam.starters,
                      formation: awayTeam.formation,
                      teamColor: awayTeam.primaryColor,
                      isHome: false,
                      showRatings: showRatings,
                      onPlayerTap: onPlayerTap,
                    ),
                  ),
                  // ── Home team (bottom half, attacking upward) ─────────────
                  Positioned.fill(
                    child: _PlayersLayer(
                      players: homeTeam.starters,
                      formation: homeTeam.formation,
                      teamColor: homeTeam.primaryColor,
                      isHome: true,
                      showRatings: showRatings,
                      onPlayerTap: onPlayerTap,
                    ),
                  ),
                  // ── Team name labels ──────────────────────────────────────
                  Positioned(
                    left: 10, top: 10,
                    child: _TeamLabel(
                      name: awayTeam.teamName,
                      logo: awayTeam.teamLogo,
                      formation: awayTeam.formation,
                      color: awayTeam.primaryColor,
                    ),
                  ),
                  Positioned(
                    left: 10, bottom: 10,
                    child: _TeamLabel(
                      name: homeTeam.teamName,
                      logo: homeTeam.teamLogo,
                      formation: homeTeam.formation,
                      color: homeTeam.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Team label badge ─────────────────────────────────────────────────────────
class _TeamLabel extends StatelessWidget {
  final String name, logo, formation;
  final Color color;
  const _TeamLabel({required this.name, required this.logo, required this.formation, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.network(logo, width: 18, height: 18,
            errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, color: Colors.white, size: 14)),
        const SizedBox(width: 5),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
          child: Text(formation, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PITCH PAINTER — Gradient grass + all white line markings
// ═══════════════════════════════════════════════════════════════════════════════
class PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Gradient grass base ─────────────────────────────────────────────────
    final grassGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF1A5C28), Color(0xFF2A7D38), Color(0xFF1A5C28)],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = grassGrad.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── Alternating lighter stripes ─────────────────────────────────────────
    final stripePaint = Paint()..color = const Color(0x1AFFFFFF);
    const stripeCount = 14;
    for (int i = 0; i < stripeCount; i++) {
      if (i % 2 == 0) continue;
      final sh = h / stripeCount;
      canvas.drawRect(Rect.fromLTWH(0, i * sh, w, sh), stripePaint);
    }

    // ── White line paint ────────────────────────────────────────────────────
    final lp = Paint()
      ..color = Colors.white.withOpacity(0.88)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final spot = Paint()..color = Colors.white..style = PaintingStyle.fill;

    // Outer boundary
    canvas.drawRect(Rect.fromLTWH(6, 6, w - 12, h - 12), lp);

    // Halfway line
    canvas.drawLine(Offset(6, h / 2), Offset(w - 6, h / 2), lp);

    // Centre circle
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.13, lp);

    // Centre spot
    canvas.drawCircle(Offset(w / 2, h / 2), 3.5, spot);

    // ── Penalty & goal areas (top & bottom) ─────────────────────────────────
    final penW = w * 0.52;
    final penH = h * 0.17;
    final goalW = w * 0.25;
    final goalH = h * 0.065;

    // Top penalty area
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, 6, penW, penH), lp);
    // Top goal area
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, 6, goalW, goalH), lp);
    // Top penalty spot
    canvas.drawCircle(Offset(w / 2, penH * 0.62 + 6), 3.5, spot);
    // Top penalty arc (outside the box)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, penH * 0.62 + 6), width: w * 0.23, height: w * 0.23),
      0.42, math.pi - 0.84, false, lp,
    );

    // Bottom penalty area
    canvas.drawRect(Rect.fromLTWH((w - penW) / 2, h - 6 - penH, penW, penH), lp);
    // Bottom goal area
    canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, h - 6 - goalH, goalW, goalH), lp);
    // Bottom penalty spot
    canvas.drawCircle(Offset(w / 2, h - 6 - penH * 0.62), 3.5, spot);
    // Bottom penalty arc
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h - 6 - penH * 0.62), width: w * 0.23, height: w * 0.23),
      math.pi + 0.42, math.pi - 0.84, false, lp,
    );

    // ── Corner arcs ─────────────────────────────────────────────────────────
    final cornerLp = Paint()
      ..color = Colors.white.withOpacity(0.88)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    const cr = 14.0;
    canvas.drawArc(Rect.fromLTWH(6, 6, cr * 2, cr * 2), math.pi, math.pi / 2, false, cornerLp);
    canvas.drawArc(Rect.fromLTWH(w - 6 - cr * 2, 6, cr * 2, cr * 2), 3 * math.pi / 2, math.pi / 2, false, cornerLp);
    canvas.drawArc(Rect.fromLTWH(6, h - 6 - cr * 2, cr * 2, cr * 2), math.pi / 2, math.pi / 2, false, cornerLp);
    canvas.drawArc(Rect.fromLTWH(w - 6 - cr * 2, h - 6 - cr * 2, cr * 2, cr * 2), 0, math.pi / 2, false, cornerLp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PLAYERS LAYER — positions players by formation
// ═══════════════════════════════════════════════════════════════════════════════
class _PlayersLayer extends StatelessWidget {
  final List<PitchPlayer> players;
  final String formation;
  final Color teamColor;
  final bool isHome;
  final bool showRatings;
  final void Function(PitchPlayer)? onPlayerTap;

  const _PlayersLayer({
    required this.players,
    required this.formation,
    required this.teamColor,
    required this.isHome,
    required this.showRatings,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final positions = _calculatePositions(w, h);

      return Stack(
        children: List.generate(players.length, (i) {
          if (i >= positions.length) return const SizedBox.shrink();
          return Positioned(
            left: positions[i].dx - 30,
            top: positions[i].dy - 38,
            child: _PlayerCircle(
              player: players[i],
              teamColor: teamColor,
              showRating: showRatings,
              onTap: onPlayerTap != null ? () => onPlayerTap!(players[i]) : null,
            ),
          );
        }),
      );
    });
  }

  List<Offset> _calculatePositions(double w, double h) {
    final lines = formation.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    final validLines = (lines.isEmpty || lines.every((l) => l == 0))
        ? (players.length <= 11 ? [1, 4, 3, 3] : [1, 4, 4, 2])
        : [1, ...lines];

    final List<Offset> positions = [];
    // Zone: each team occupies 44% of pitch height; GK is at 4%/96%
    final zoneStart = isHome ? h * 0.55 : h * 0.05;
    final zoneEnd   = isHome ? h * 0.96 : h * 0.45;
    final zoneH     = (zoneEnd - zoneStart).abs();

    int playerIndex = 0;
    final lineCount = validLines.length;

    for (int li = 0; li < lineCount; li++) {
      final n = validLines[li];
      if (n == 0) continue;

      // Y: GK at near end, outfield lines spread toward midfield
      double lineY;
      if (li == 0) {
        // Goalkeeper — very close to goal line
        lineY = isHome ? zoneEnd - (h * 0.025) : zoneStart + (h * 0.025);
      } else {
        final t = (li - 1) / ((lineCount - 1).clamp(1, lineCount - 1));
        // Home: outfield grows from bottom toward center; away: top toward center
        lineY = isHome
            ? zoneEnd - h * 0.025 - (zoneH * 0.85 * t)
            : zoneStart + h * 0.025 + (zoneH * 0.85 * t);
      }

      for (int j = 0; j < n && playerIndex < players.length; j++) {
        final xFrac = n == 1 ? 0.5 : (0.09 + j * (0.82 / (n - 1)));
        positions.add(Offset(w * xFrac, lineY));
        playerIndex++;
      }
    }

    return positions;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PLAYER CIRCLE — avatar + jersey number + rating badge + name
// ═══════════════════════════════════════════════════════════════════════════════
class _PlayerCircle extends StatelessWidget {
  final PitchPlayer player;
  final Color teamColor;
  final bool showRating;
  final VoidCallback? onTap;

  const _PlayerCircle({
    required this.player,
    required this.teamColor,
    required this.showRating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── Avatar circle ───────────────────────────────────────────
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: teamColor, width: 2.8),
                    boxShadow: [
                      BoxShadow(color: teamColor.withOpacity(0.45), blurRadius: 8, offset: const Offset(0, 2)),
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4),
                    ],
                  ),
                  child: ClipOval(
                    child: (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                        ? Image.network(
                      player.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Initials(name: player.name, color: teamColor),
                    )
                        : _Initials(name: player.name, color: teamColor),
                  ),
                ),

                // ── Jersey number badge (bottom-left) ───────────────────────
                Positioned(
                  bottom: -5, left: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: teamColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      player.number.isEmpty ? '?' : player.number,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                // ── Rating badge (top-right) ─────────────────────────────────
                if (showRating && player.rating != null)
                  Positioned(
                    top: -6, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _ratingColor(player.rating!),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        player.rating!.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 5),

            // ── Player name ─────────────────────────────────────────────────
            Text(
              player.shortName.isNotEmpty ? player.shortName : player.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Position badge ──────────────────────────────────────────────
            if (player.position.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: teamColor.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  player.position,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _ratingColor(double r) {
    if (r >= 8.0) return const Color(0xFF16A34A);
    if (r >= 6.5) return const Color(0xFF1A56DB);
    if (r >= 5.0) return const Color(0xFFCA8A04);
    return const Color(0xFFDC2626);
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final Color color;
  const _Initials({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      color: color.withOpacity(0.12),
      child: Center(
        child: Text(initials, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  FORMATION SELECTOR — horizontally scrollable chips
// ═══════════════════════════════════════════════════════════════════════════════
class FormationSelector extends StatelessWidget {
  final String selectedFormation;
  final ValueChanged<String> onFormationChanged;
  final Color? accentColor;

  static const formations = [
    '4-3-3', '4-4-2', '4-2-3-1', '4-1-4-1',
    '3-5-2', '3-4-3', '3-4-2-1',
    '5-3-2', '5-4-1', '4-3-2-1',
  ];

  const FormationSelector({
    super.key,
    required this.selectedFormation,
    required this.onFormationChanged,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF1A56DB);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: formations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final f = formations[i];
          final selected = f == selectedFormation;
          return GestureDetector(
            onTap: () => onFormationChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300),
                boxShadow: selected
                    ? [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 8)]
                    : null,
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SUBSTITUTES SECTION — shared widget for the lineup tab
// ═══════════════════════════════════════════════════════════════════════════════
class SubstitutesSection extends StatelessWidget {
  final TeamLineup homeTeam;
  final TeamLineup awayTeam;

  const SubstitutesSection({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubGroup(
          title: '${awayTeam.teamName} — Substitutes',
          players: awayTeam.substitutes,
          color: awayTeam.primaryColor,
        ),
        const SizedBox(height: 10),
        _SubGroup(
          title: '${homeTeam.teamName} — Substitutes',
          players: homeTeam.substitutes,
          color: homeTeam.primaryColor,
        ),
      ],
    );
  }
}

class _SubGroup extends StatelessWidget {
  final String title;
  final List<PitchPlayer> players;
  final Color color;
  const _SubGroup({required this.title, required this.players, required this.color});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7A96), letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: players.map((p) => _SubChip(player: p, color: color)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SubChip extends StatelessWidget {
  final PitchPlayer player;
  final Color color;
  const _SubChip({required this.player, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE3F0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Avatar or jersey number
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: (player.imageUrl != null && player.imageUrl!.isNotEmpty)
              ? ClipOval(child: Image.network(player.imageUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _jerseyText(player.number, color)))
              : _jerseyText(player.number, color),
        ),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            player.shortName.isNotEmpty ? player.shortName : player.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1B3E)),
          ),
          Text(player.position, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7A96))),
        ]),
        if (player.rating != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _ratingColor(player.rating!).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              player.rating!.toStringAsFixed(1),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _ratingColor(player.rating!)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _jerseyText(String number, Color color) {
    return Center(child: Text(number.isEmpty ? '?' : number,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)));
  }

  Color _ratingColor(double r) {
    if (r >= 8.0) return const Color(0xFF16A34A);
    if (r >= 6.5) return const Color(0xFF1A56DB);
    if (r >= 5.0) return const Color(0xFFCA8A04);
    return const Color(0xFFDC2626);
  }
}