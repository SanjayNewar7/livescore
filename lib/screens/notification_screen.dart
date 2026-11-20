// lib/screens/notification_screen.dart
//
// Shows LiveGoal's local notification center:
//   • News mentioning a favorite club or favorite player  -> opens
//     ArticleDetailScreen with the exact same article the News tab uses.
//   • Full-time results for a favorite team's match (generated for up to
//     12h after the estimated final whistle) -> opens GameDetailScreen for
//     that match.
//
// Notifications are grouped into "New" (unread) and "Earlier" (read), with
// unread rows getting a green accent bar + tinted background + bold title,
// and read rows rendered in a muted, flattened style — a common
// read/unread pattern (Gmail, most notification centers).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:livescore/models/notification_model.dart';
import 'package:livescore/services/notification_service.dart';
import 'package:livescore/screens/article_detail_screen.dart';
import 'package:livescore/screens/game_detail_screen.dart';
import 'package:livescore/utils/helpers.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
// Matches the palette used across article_detail_screen.dart / home_screen.dart
// so this screen doesn't look bolted-on.
class _C {
  static const primary      = Color(0xFF16A34A);
  static const primaryDark  = Color(0xFF0E7C39);
  static const primaryLight = Color(0xFFE7F7ED);
  static const secondary      = Color(0xFF1A62C8);
  static const secondaryLight = Color(0xFFE8F0FC);
  static const border   = Color(0xFFE2E8F2);
  static const text     = Color(0xFF0F1623);
  static const muted    = Color(0xFF6B7A96);
  static const offWhite = Color(0xFFF5F7FB);
  static const liveRed  = Color(0xFFE53535);
  static const white    = Color(0xFFFFFFFF);
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();
  List<NotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _items = _service.getAll();
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    _load();
  }

  Future<void> _openNotification(NotificationItem item) async {
    if (!item.isRead) {
      await _service.markAsRead(item.id);
      _load();
    }
    if (!mounted) return;

    if (item.isNews && item.article != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: item.article!),
        ),
      );
    } else if (item.isMatchResult && item.game != null) {
      // NOTE: game_detail_screen.dart wasn't available to inspect while
      // building this integration — this assumes the common pattern used
      // by every other detail screen in this codebase (TeamDetailScreen,
      // ArticleDetailScreen, etc.): a single required `game` param. If your
      // actual GameDetailScreen constructor differs, update this call only.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameDetailScreen(game: item.game!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).toList();
    final read = _items.where((n) => n.isRead).toList();

    return Scaffold(
      backgroundColor: _C.offWhite,
      appBar: AppBar(
        backgroundColor: _C.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: _C.white,
        foregroundColor: _C.text,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _C.text),
        ),
        centerTitle: false,
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(fontWeight: FontWeight.w700, color: _C.primary, fontSize: 13),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : _items.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        color: _C.primary,
        onRefresh: () async => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (unread.isNotEmpty) ...[
              _SectionLabel('New (${unread.length})'),
              ...unread.map((n) => _NotificationTile(
                item: n,
                onTap: () => _openNotification(n),
              )),
            ],
            if (read.isNotEmpty) ...[
              _SectionLabel('Earlier'),
              ...read.map((n) => _NotificationTile(
                item: n,
                onTap: () => _openNotification(n),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
        Center(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(color: _C.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none_rounded, size: 36, color: _C.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No notifications yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _C.text),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'News about your favorite clubs and players, and full-time '
                      'results for your favorite team, will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _C.muted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Section label ("New" / "Earlier") ───────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: _C.muted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Notification row ────────────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return Material(
      color: unread ? _C.primaryLight.withOpacity(0.55) : _C.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _C.border.withOpacity(0.7), width: 1),
              left: BorderSide(
                color: unread ? _C.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildKindIcon(),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              color: unread ? _C.text : _C.muted,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: _C.liveRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: unread ? _C.text.withOpacity(0.75) : _C.muted.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Helpers.formatDateAgo(item.createdAt.toIso8601String()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: unread ? _C.primaryDark : _C.muted.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKindIcon() {
    final isMatch = item.isMatchResult;
    return Icon(
      isMatch ? Icons.sports_soccer_rounded : Icons.article_rounded,
      size: 13,
      color: isMatch ? _C.primaryDark : _C.secondary,
    );
  }

  Widget _buildThumbnail() {
    final url = item.imageUrl;
    final isMatch = item.isMatchResult;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isMatch ? _C.primaryLight : _C.secondaryLight,
        borderRadius: BorderRadius.circular(isMatch ? 10 : 12),
        border: Border.all(color: _C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
        imageUrl: url,
        fit: isMatch ? BoxFit.contain : BoxFit.cover,
        placeholder: (_, __) => _fallbackIcon(isMatch),
        errorWidget: (_, __, ___) => _fallbackIcon(isMatch),
      )
          : _fallbackIcon(isMatch),
    );
  }

  Widget _fallbackIcon(bool isMatch) {
    return Center(
      child: Icon(
        isMatch ? Icons.sports_soccer_rounded : Icons.article_rounded,
        size: 20,
        color: isMatch ? _C.primary : _C.secondary,
      ),
    );
  }
}