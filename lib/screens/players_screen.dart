import 'package:flutter/material.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/widgets/player_card.dart';
import 'package:livescore/utils/theme.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final SportService _sportService = SportService();
  List<TeamInfo> _teams = [];
  String? _selectedTeamId;
  List<Player> _players = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      _teams = await _sportService.getAllTeams();
      if (_teams.isNotEmpty && mounted) {
        setState(() {
          _selectedTeamId = _teams.first.id;
        });
        await _loadPlayers();
      }
    } catch (e) {
      debugPrint('Error loading teams: $e');
    }
  }

  Future<void> _loadPlayers() async {
    if (_selectedTeamId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _players = await _sportService.getTeamRoster(_selectedTeamId!);
    } catch (e) {
      debugPrint('Error loading players: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Team selector dropdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkGray : AppTheme.pureWhite,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedTeamId,
            dropdownColor: isDarkMode ? AppTheme.darkGray : AppTheme.pureWhite,
            decoration: const InputDecoration(
              labelText: 'Select Team',
              border: OutlineInputBorder(),
            ),
            items: _teams.map((team) {
              return DropdownMenuItem(
                value: team.id,
                child: Row(
                  children: [
                    Image.network(
                      team.logo,
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, size: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        team.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTeamId = value;
              });
              _loadPlayers();
            },
          ),
        ),

        // Players list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _players.isEmpty
              ? const Center(child: Text('No players found'))
              : RefreshIndicator(
            onRefresh: _loadPlayers,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _players.length,
              itemBuilder: (context, index) {
                return PlayerCard(player: _players[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
}