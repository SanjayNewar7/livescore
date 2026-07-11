// lib/screens/search_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/models/search_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/screens/team_detail_screen.dart';
import 'package:livescore/models/team_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (value.trim().isNotEmpty) {
        context.read<AppProvider>().searchWithDebounce(value);
      } else {
        context.read<AppProvider>().clearSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
            ),
            Expanded(
              child: _SearchResults(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () {
                context.read<AppProvider>().clearSearch();
                Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F1623),
                ),
                decoration: InputDecoration(
                  hintText: 'Search players, teams, leagues...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7A96),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF6B7A96),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      context.read<AppProvider>().clearSearch();
                      focusNode.requestFocus();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isSearching = provider.isSearching;
    final results = provider.searchResults;
    final query = provider.searchQuery;

    if (isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A62C8),
        ),
      );
    }

    if (query.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for anything',
        subtitle: 'Find players, teams, and leagues',
      );
    }

    if (results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try searching for something else',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (results.leagues.isNotEmpty) ...[
          _SectionHeader('LEAGUES', results.leagues.length),
          ...results.leagues.map((result) => _SearchResultTile(result: result)),
        ],
        if (results.teams.isNotEmpty) ...[
          if (results.leagues.isNotEmpty) const SizedBox(height: 16),
          _SectionHeader('TEAMS', results.teams.length),
          ...results.teams.map((result) => _SearchResultTile(result: result)),
        ],
        if (results.players.isNotEmpty) ...[
          if (results.teams.isNotEmpty || results.leagues.isNotEmpty)
            const SizedBox(height: 16),
          _SectionHeader('PLAYERS', results.players.length),
          ...results.players.map((result) => _SearchResultTile(result: result)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader(this.title, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7A96),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A62C8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Avatar(result: result),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F1623),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getSubtitle(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7A96),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: result.type),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF6B7A96),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSubtitle() {
    switch (result.type) {
      case 'player':
        final parts = <String>[];
        if (result.position != null && result.position!.isNotEmpty) {
          parts.add(result.position!);
        }
        if (result.teamName != null && result.teamName!.isNotEmpty) {
          parts.add(result.teamName!);
        }
        if (result.jerseyNumber != null && result.jerseyNumber!.isNotEmpty) {
          parts.add('#${result.jerseyNumber}');
        }
        if (result.rating != null && result.rating!.isNotEmpty) {
          parts.add('⭐ ${result.rating}');
        }
        if (result.nationality != null && result.nationality!.isNotEmpty) {
          parts.add(result.nationality!);
        }
        return parts.isNotEmpty ? parts.join(' • ') : 'Player';
      case 'team':
        if (result.leagueName != null && result.leagueName!.isNotEmpty) {
          return result.leagueName!;
        }
        return 'Team';
      case 'league':
        return 'League';
      default:
        return '';
    }
  }

  void _onTap(BuildContext context) {
    final provider = context.read<AppProvider>();
    provider.clearSearch();

    switch (result.type) {
      case 'team':
        final team = TeamInfo(
          id: result.id,
          name: result.name,
          displayName: result.displayName,
          abbreviation: result.name.length > 3
              ? result.name.substring(0, 3).toUpperCase()
              : result.name.toUpperCase(),
          logo: result.imageUrl ?? 'https://a.espncdn.com/i/teamlogos/soccer/500/${result.id}.png',
          color: '#1A62C8',
          alternateColor: '#FFFFFF',
          record: '0-0-0',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(
              team: team,
              leagueCode: result.leagueCode,
            ),
          ),
        );
        break;
      case 'player':
        _showPlayerInfo(context);
        break;
      case 'league':
        _showLeagueInfo(context);
        break;
    }
  }

  void _showPlayerInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _Avatar(result: result, size: 80),
            const SizedBox(height: 12),
            Text(
              result.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F1623),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getSubtitle(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7A96),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: 'Player', icon: Icons.person_rounded),
                if (result.position != null)
                  _InfoChip(label: result.position!, icon: Icons.sports_soccer_rounded),
                if (result.jerseyNumber != null)
                  _InfoChip(label: '#${result.jerseyNumber}', icon: Icons.numbers_rounded),
                if (result.nationality != null)
                  _InfoChip(label: result.nationality!, icon: Icons.flag_rounded),
                if (result.rating != null)
                  _InfoChip(label: '⭐ ${result.rating}', icon: Icons.star_rounded),
                if (result.age != null)
                  _InfoChip(label: '${result.age} yrs', icon: Icons.cake_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLeagueInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _Avatar(result: result, size: 64),
            const SizedBox(height: 12),
            Text(
              result.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F1623),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'League',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7A96),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to standings for this league
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A62C8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'VIEW STANDINGS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final SearchResult result;
  final double size;

  const _Avatar({required this.result, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFFE8F0FC);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: const Color(0xFFE2E8F2), width: 1.5),
      ),
      child: ClipOval(
        child: result.imageUrl != null && result.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: result.imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Placeholder(result: result, size: size),
          errorWidget: (_, __, ___) => _Placeholder(result: result, size: size),
        )
            : _Placeholder(result: result, size: size),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final SearchResult result;
  final double size;

  const _Placeholder({required this.result, required this.size});

  @override
  Widget build(BuildContext context) {
    String text;
    if (result.type == 'player') {
      final parts = result.displayName.split(' ');
      text = parts.map((s) => s.isNotEmpty ? s[0] : '').join('').toUpperCase();
    } else {
      text = result.displayName.isNotEmpty ? result.displayName[0].toUpperCase() : '?';
    }

    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE8F0FC),
      child: Center(
        child: Text(
          text.isNotEmpty ? (text.length > 2 ? text.substring(0, 2) : text) : '?',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A62C8),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'player': const Color(0xFF10B981),
      'team': const Color(0xFF1A62C8),
      'league': const Color(0xFF8B5CF6),
    };

    final labels = {
      'player': 'Player',
      'team': 'Team',
      'league': 'League',
    };

    final color = colors[type] ?? const Color(0xFF6B7A96);
    final label = labels[type] ?? type;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7A96)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F1623),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 36,
                color: const Color(0xFF1A62C8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1623),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7A96),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}