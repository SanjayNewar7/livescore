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
            // Taller pitch = more breathing room between lines, so cards never crowd each other.
            final h = customHeight ?? (w * 1.68).clamp(600.0, 900.0);
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
            left: positions[i].dx - _PlayerCircle.cardWidth / 2,
            top: positions[i].dy - _PlayerCircle.anchorOffsetY,
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
    final lines = formation.split('-').map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
    final validLines = lines.isEmpty
        ? (players.length <= 11 ? [1, 4, 3, 3] : [1, 4, 4, 2])
        : [1, ...lines];

    final List<Offset> positions = [];

    // Each team owns just under half the pitch, leaving a clear gap around the
    // halfway line so the two backlines never visually merge.
    final zoneStart = isHome ? h * 0.535 : h * 0.055;
    final zoneEnd   = isHome ? h * 0.955 : h * 0.455;
    final zoneH     = (zoneEnd - zoneStart).abs();

    int playerIndex = 0;
    final lineCount = validLines.length;
    final outfieldLines = lineCount - 1;

    // GK gets a small, fixed slice near the byline; outfield lines then divide
    // the *remaining* space evenly, so a 5-line formation (e.g. 4-2-3-1) gets
    // just as much breathing room per line as a 3-line one.
    const gkBandFrac = 0.15;
    const halfwayGapFrac = 0.08; // keeps the most advanced line off the centre circle

    for (int li = 0; li < lineCount; li++) {
      final n = validLines[li];

      double frac; // 0 = byline, 1 = halfway line
      if (li == 0) {
        frac = gkBandFrac * 0.45;
      } else {
        final t = outfieldLines <= 1 ? 0.0 : (li - 1) / (outfieldLines - 1);
        frac = gkBandFrac + (1 - gkBandFrac - halfwayGapFrac) * t;
      }

      final lineY = isHome ? zoneEnd - zoneH * frac : zoneStart + zoneH * frac;

      // Wider side margins for small lines (e.g. a lone striker or two centre-backs)
      // keeps players from feeling stranded near the touchline, while full-width
      // lines (back four/five) still spread edge to edge.
      final margin = n <= 1 ? 0.5 : (n == 2 ? 0.24 : (n <= 3 ? 0.16 : 0.10));

      for (int j = 0; j < n && playerIndex < players.length; j++) {
        final xFrac = n == 1 ? 0.5 : (margin + j * ((1 - margin * 2) / (n - 1)));
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

  // Shared layout constants — keep in sync with _PlayersLayer's anchor math.
  static const double cardWidth = 52;
  static const double avatarSize = 38;
  static const double anchorOffsetY = avatarSize / 2 + 6; // room for the rating badge overhang

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
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── Avatar circle ───────────────────────────────────────────
                Container(
                  width: avatarSize, height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: teamColor, width: 2.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 5, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ClipOval(
                    child: (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                        ? Image.network(
                      player.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlayerFallbackAvatar(
                        name: player.name,
                        color: teamColor,
                      ),
                    )
                        : _PlayerFallbackAvatar(
                      name: player.name,
                      color: teamColor,
                    ),
                  ),
                ),

                // ── Jersey number badge (bottom-right, overlapping avatar) ──
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 16, height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: teamColor,
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                    child: Text(
                      player.number.isEmpty ? '?' : player.number,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, height: 1),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ),

                // Note: player ratings aren't reliably available from ESPN or
                // SportsDB for these leagues, so no rating badge is shown here.
              ],
            ),

            const SizedBox(height: 4),

            // ── Player name pill — compact, high-contrast, single line ──────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.42),
                borderRadius: BorderRadius.circular(5),
              ),
              constraints: const BoxConstraints(maxWidth: cardWidth + 6),
              child: Text(
                player.shortName.isNotEmpty ? player.shortName : player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Fallback avatar with initials or person icon
class _PlayerFallbackAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _PlayerFallbackAvatar({
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    String initials = '?';
    if (parts.length >= 2) {
      initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      initials = name[0].toUpperCase();
    }

    // If initials is just '?' or empty, show a person icon
    if (initials == '?' || initials.isEmpty) {
      return Container(
        color: color.withOpacity(0.12),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            color: color.withOpacity(0.5),
            size: 18,
          ),
        ),
      );
    }

    return Container(
      color: color.withOpacity(0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
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
        // Avatar
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: (player.imageUrl != null && player.imageUrl!.isNotEmpty)
              ? ClipOval(
            child: Image.network(
              player.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _SubChipFallbackAvatar(
                name: player.name,
                number: player.number,
                color: color,
              ),
            ),
          )
              : _SubChipFallbackAvatar(
            name: player.name,
            number: player.number,
            color: color,
          ),
        ),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            player.shortName.isNotEmpty ? player.shortName : player.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1B3E)),
          ),
          Text(player.position, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7A96))),
        ]),
        // Note: ratings aren't shown here — ESPN/SportsDB don't reliably
        // provide per-match player ratings for these leagues.
      ]),
    );
  }
}

/// Fallback avatar for substitute chips
class _SubChipFallbackAvatar extends StatelessWidget {
  final String name;
  final String number;
  final Color color;

  const _SubChipFallbackAvatar({
    required this.name,
    required this.number,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    String initials = '?';
    if (parts.length >= 2) {
      initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      initials = name[0].toUpperCase();
    }

    // If initials is just '?' or empty, show a person icon
    if (initials == '?' || initials.isEmpty) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          color: color.withOpacity(0.4),
          size: 14,
        ),
      );
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}