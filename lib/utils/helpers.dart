import 'package:intl/intl.dart';

import 'constants.dart';

class Helpers {
  static String formatGameTime(String isoDate, {bool showBothTimezones = false}) {
    try {
      final gameDate = DateTime.parse(isoDate);
      final now = DateTime.now();

      final localFormat = DateFormat('h:mm a').format(gameDate.toLocal());

      if (showBothTimezones) {
        final venueFormat = DateFormat('h:mm a').format(gameDate);
        return '$localFormat (GMT: $venueFormat)';
      }

      if (gameDate.isAfter(now)) {
        return localFormat;
      } else {
        return DateFormat('MMM d, h:mm a').format(gameDate.toLocal());
      }
    } catch (e) {
      return 'TBD';
    }
  }

  static String getGameStatus(String status, String clock, String period) {
    if (status == 'STATUS_FINAL') {
      return 'Final';
    }
    if (status == 'STATUS_LIVE') {
      if (clock.isNotEmpty && period.isNotEmpty) {
        return '$clock\' $period\' Half';
      }
      return 'Live';
    }
    if (status == 'STATUS_SCHEDULED') {
      return 'Upcoming';
    }
    return status;
  }

  static String formatClock(String clock, String period) {
    if (period == '3') {
      return 'Final';
    }
    if (clock.isNotEmpty) {
      return '$clock\' $period\' Half';
    }
    return period;
  }

  static String formatWinProbability(double percentage) {
    return '${percentage.toStringAsFixed(0)}%';
  }

  static String formatDateAgo(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, y').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  static String formatPlayerHeight(int inches) {
    final feet = inches ~/ 12;
    final remainingInches = inches % 12;
    return "$feet'$remainingInches\"";
  }

  static String getLeagueFlag(String leagueCode) {
    final league = AppConstants.popularLeagues.firstWhere(
          (l) => l['code'] == leagueCode,
      orElse: () => {'flag': '⚽'},
    );
    return league['flag'] ?? '⚽';
  }

  static String getLeagueName(String leagueCode) {
    final league = AppConstants.popularLeagues.firstWhere(
          (l) => l['code'] == leagueCode,
      orElse: () => {'name': leagueCode},
    );
    return league['name'] ?? leagueCode;
  }
}