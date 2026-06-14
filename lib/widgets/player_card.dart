import 'package:flutter/material.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/helpers.dart';

class PlayerCard extends StatelessWidget {
  final Player player;

  const PlayerCard({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Player headshot
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.pureBlack,
              shape: BoxShape.circle,
              image: player.headshot.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(player.headshot),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: player.headshot.isEmpty
                ? const Icon(Icons.person, size: 30, color: AppTheme.lightGray)
                : null,
          ),
          const SizedBox(width: 12),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        player.position,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (player.injuryStatus != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          player.injuryStatus!,
                          style: const TextStyle(fontSize: 10, color: AppTheme.dangerRed),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '#${player.jersey} • ${Helpers.formatPlayerHeight(player.height)} • ${player.weight} lbs',
                  style: const TextStyle(fontSize: 12, color: AppTheme.lightGray),
                ),
                if (player.college.isNotEmpty)
                  Text(
                    player.college,
                    style: const TextStyle(fontSize: 12, color: AppTheme.lightGray),
                  ),
              ],
            ),
          ),

          // Key stat
          if (player.statistics.containsKey('passingYards'))
            Column(
              children: [
                const Text(
                  'PASS YDS',
                  style: TextStyle(fontSize: 10, color: AppTheme.lightGray),
                ),
                const SizedBox(height: 4),
                Text(
                  player.statistics['passingYards'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }
}