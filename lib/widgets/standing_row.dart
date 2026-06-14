import 'package:flutter/material.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/utils/theme.dart';

class StandingRow extends StatelessWidget {
  final Standing standing;

  const StandingRow({super.key, required this.standing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: standing.clinchedPlayoffs
            ? AppTheme.primaryBlue.withOpacity(0.15)
            : AppTheme.darkGray,
        borderRadius: BorderRadius.circular(12),
        border: standing.clinchedPlayoffs
            ? Border(left: BorderSide(color: AppTheme.primaryBlue, width: 4))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 40,
              child: Text(
                '${standing.rank}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: standing.clinchedPlayoffs ? AppTheme.primaryBlue : AppTheme.pureWhite,
                ),
              ),
            ),

            // Team logo and name
            SizedBox(
              width: 44,
              child: Image.network(
                standing.team.logo,
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(Icons.sports_football, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                standing.team.displayName,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Record
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.pureBlack,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${standing.wins}-${standing.losses}${standing.ties != '0' ? '-${standing.ties}' : ''}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),

            // Win percentage
            SizedBox(
              width: 45,
              child: Text(
                standing.winPercentage,
                style: const TextStyle(fontSize: 12, color: AppTheme.lightGray),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}