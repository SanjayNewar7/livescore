// lib/screens/favorites_screen.dart
//
// Lets the user pick a favorite club and a favorite player. Search
// results (including team crests and player headshots) come from
// AppProvider.search(), which calls ESPN's undocumented search API -
// the same source already used across the app.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:livescore/models/search_model.dart';
import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/services/profile_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF1A62C8);
  static const Color _green = Color(0xFF16A34A);
  static const Color _ink = Color(0xFF0F1623);

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  UserProfile _profile = UserProfile.empty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _profile = ProfileService().profile;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    Provider.of<AppProvider>(context, listen: false).clearSearch();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    Provider.of<AppProvider>(context, listen: false).searchWithDebounce(query);
  }

  Future<void> _selectClub(SearchResult club) async {
    final updated = await ProfileService().setFavoriteClub(
      id: club.id,
      name: club.displayName,
      logo: club.displayImageUrl,
    );
    if (mounted) {
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${club.displayName} set as your favorite club'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectPlayer(SearchResult player) async {
    final updated = await ProfileService().setFavoritePlayer(
      id: player.id,
      name: player.displayName,
      image: player.displayImageUrl,
      team: player.teamName ?? '',
    );
    if (mounted) {
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${player.displayName} set as your favorite player'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearClub() async {
    final updated = await ProfileService().clearFavoriteClub();
    if (mounted) setState(() => _profile = updated);
  }

  Future<void> _clearPlayer() async {
    final updated = await ProfileService().clearFavoritePlayer();
    if (mounted) setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Favorites', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context, _profile),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _blue,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: _blue,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Club'),
            Tab(text: 'Player'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                style: const TextStyle(fontSize: 15, color: _ink),
                decoration: InputDecoration(
                  hintText: 'Search clubs or players',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: _blue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _onQueryChanged('');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ClubResultsTab(profile: _profile, onSelect: _selectClub, onClear: _clearClub),
                _PlayerResultsTab(profile: _profile, onSelect: _selectPlayer, onClear: _clearPlayer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubResultsTab extends StatelessWidget {
  final UserProfile profile;
  final ValueChanged<SearchResult> onSelect;
  final VoidCallback onClear;

  const _ClubResultsTab({required this.profile, required this.onSelect, required this.onClear});

  static const Color _blue = Color(0xFF1A62C8);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final query = provider.searchResults;
        final showEmptyState = !provider.isSearching && query.teams.isEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (profile.hasFavoriteClub) _CurrentFavoriteCard(
              title: 'Current favorite club',
              name: profile.favoriteClubName ?? '',
              imageUrl: profile.favoriteClubLogo ?? '',
              onClear: onClear,
            ),
            if (profile.hasFavoriteClub) const SizedBox(height: 16),
            if (provider.isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: _blue)),
              )
            else if (showEmptyState)
              const _EmptySearchHint(text: 'Search for a club to set as your favorite')
            else
              ...query.teams.map((team) => _SearchResultTile(result: team, onTap: () => onSelect(team))),
          ],
        );
      },
    );
  }
}

class _PlayerResultsTab extends StatelessWidget {
  final UserProfile profile;
  final ValueChanged<SearchResult> onSelect;
  final VoidCallback onClear;

  const _PlayerResultsTab({required this.profile, required this.onSelect, required this.onClear});

  static const Color _blue = Color(0xFF1A62C8);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final query = provider.searchResults;
        final showEmptyState = !provider.isSearching && query.players.isEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (profile.hasFavoritePlayer) _CurrentFavoriteCard(
              title: 'Current favorite player',
              name: profile.favoritePlayerName ?? '',
              imageUrl: profile.favoritePlayerImage ?? '',
              onClear: onClear,
            ),
            if (profile.hasFavoritePlayer) const SizedBox(height: 16),
            if (provider.isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: _blue)),
              )
            else if (showEmptyState)
              const _EmptySearchHint(text: 'Search for a player to set as your favorite')
            else
              ...query.players.map((player) => _SearchResultTile(result: player, onTap: () => onSelect(player))),
          ],
        );
      },
    );
  }
}

class _CurrentFavoriteCard extends StatelessWidget {
  final String title;
  final String name;
  final String imageUrl;
  final VoidCallback onClear;

  const _CurrentFavoriteCard({required this.title, required this.name, required this.imageUrl, required this.onClear});

  static const Color _blue = Color(0xFF1A62C8);
  static const Color _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_blue, _green], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 48, height: 48, color: Colors.white24,
                child: const Icon(Icons.sports_soccer_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                const SizedBox(height: 2),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  static const Color _blue = Color(0xFF1A62C8);
  static const Color _ink = Color(0xFF0F1623);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: result.displayImageUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 44, height: 44,
              color: _blue.withOpacity(0.08),
            ),
            errorWidget: (context, url, error) => Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(result.initials, style: const TextStyle(color: _blue, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        title: Text(result.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
        subtitle: Text(result.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7A96)),
      ),
    );
  }
}

class _EmptySearchHint extends StatelessWidget {
  final String text;
  const _EmptySearchHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.search, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}