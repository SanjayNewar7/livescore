import 'package:flutter/material.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/helpers.dart';

class WinProbabilityWidget extends StatelessWidget {
  final List<WinProbability> winProbabilities;
  final TeamInfo awayTeam;
  final TeamInfo homeTeam;

  const WinProbabilityWidget({
    super.key,
    required this.winProbabilities,
    required this.awayTeam,
    required this.homeTeam,
  });

  @override
  Widget build(BuildContext context) {
    if (winProbabilities.isEmpty) return const SizedBox();

    final latestWp = winProbabilities.last;
    final awayWp = latestWp.awayWinPercentage;
    final homeWp = latestWp.homeWinPercentage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WIN PROBABILITY',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  awayTeam.abbreviation,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(
                  homeTeam.abbreviation,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Stack(
            children: [
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: awayWp.toInt(),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: awayTeam.color.isNotEmpty
                            ? Color(int.parse('0xFF${awayTeam.color}'))
                            : AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          Helpers.formatWinProbability(awayWp),
                          style: const TextStyle(
                            color: AppTheme.pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: homeWp.toInt(),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: homeTeam.color.isNotEmpty
                            ? Color(int.parse('0xFF${homeTeam.color}'))
                            : AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          Helpers.formatWinProbability(homeWp),
                          style: const TextStyle(
                            color: AppTheme.pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (winProbabilities.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: CustomPaint(
                painter: WinProbabilityChartPainter(
                  winProbabilities: winProbabilities,
                  awayTeam: awayTeam,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WinProbabilityChartPainter extends CustomPainter {
  final List<WinProbability> winProbabilities;
  final TeamInfo awayTeam;

  WinProbabilityChartPainter({
    required this.winProbabilities,
    required this.awayTeam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winProbabilities.isEmpty) return;

    final paint = Paint()
      ..color = awayTeam.color.isNotEmpty
          ? Color(int.parse('0xFF${awayTeam.color}'))
          : AppTheme.primaryBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (winProbabilities.length - 1);

    for (int i = 0; i < winProbabilities.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - winProbabilities[i].awayWinPercentage / 100);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}