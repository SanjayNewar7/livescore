import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/screens/article_detail_screen.dart';
import 'package:livescore/utils/helpers.dart';
import 'package:livescore/screens/standings_screen.dart';
import 'package:livescore/screens/teams_screen.dart';
import 'package:livescore/screens/settings_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
// LiveGoal palette: green is the primary brand color, blue is the secondary /
// informational accent (category tags, links).
class _C {
  static const primary      = Color(0xFF16A34A); // brand green
  static const primaryDark  = Color(0xFF0E7C39);
  static const primaryLight = Color(0xFFE7F7ED);
  static const secondary      = Color(0xFF1A62C8); // brand blue
  static const secondaryLight = Color(0xFFE8F0FC);
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF5F7FB);
  static const border    = Color(0xFFE2E8F2);
  static const text      = Color(0xFF0F1623);
  static const muted     = Color(0xFF6B7A96);
  static const liveRed   = Color(0xFFE53535);
  static const shimmer1  = Color(0xFFEEF2F8);
  static const shimmer2  = Color(0xFFDDE5F5);
}

// ─── Gradient palettes for image fallback (green/blue brand mix) ──────────────
const List<List<Color>> _gradientPalettes = [
  [Color(0xFF16A34A), Color(0xFF0E7C39)],
  [Color(0xFF1A62C8), Color(0xFF0D4A9E)],
  [Color(0xFF12805F), Color(0xFF0B5C43)],
  [Color(0xFF1565C0), Color(0xFF0D47A1)],
  [Color(0xFF1E8E5A), Color(0xFF0F5C39)],
  [Color(0xFF0277BD), Color(0xFF01579B)],
];

List<Color> _paletteFor(String id) {
  final idx = id.hashCode.abs() % _gradientPalettes.length;
  return _gradientPalettes[idx];
}

// ─── NewsScreen ───────────────────────────────────────────────────────────────
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  Timer? _autoRefreshTimer;

  // Tracks if we've done the very first load (drives skeleton visibility)
  bool _hasLoadedOnce = false;

  late AnimationController _shimmerCtrl;
  late Animation<double>   _shimmerAnim;

  // Track if we've reached the 3-day limit
  bool _reachedTimeLimit = false;

  @override
  void initState() {
    super.initState();

    // Shimmer pulse animation
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _scroll.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.paginatedNews.isEmpty && !provider.isFetchingNews) {
        provider.fetchNewsConcurrent(page: 1);
      }
      // Mark first load done once provider responds
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _hasLoadedOnce = true);
      });
    });

    // ── Silent background refresh every 60 s ──────────────────────────────────
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        context.read<AppProvider>().silentRefreshNews();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _autoRefreshTimer?.cancel();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_reachedTimeLimit) return;

    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 500) {
      final p = context.read<AppProvider>();
      if (p.hasMoreNews && !p.isLoadingMoreNews && !p.isFetchingNews) {
        p.loadMoreNews();
      }
    }
  }

  // Check if article is within last 3 days
  bool _isWithinThreeDays(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);
      return difference.inDays <= 3;
    } catch (e) {
      return true; // If date parsing fails, keep the article
    }
  }

  // Check if we've reached the 3-day limit in the loaded articles
  void _checkTimeLimit(List<NewsArticle> articles) {
    if (articles.isEmpty) return;

    // Check the oldest article (last in list)
    final oldestArticle = articles.last;
    if (!_isWithinThreeDays(oldestArticle.publishedAt)) {
      if (!_reachedTimeLimit) {
        setState(() {
          _reachedTimeLimit = true;
        });
      }
    } else {
      setState(() {
        _reachedTimeLimit = false;
      });
    }
  }

  // Filter articles to only those within last 3 days
  List<NewsArticle> _filterByThreeDays(List<NewsArticle> articles) {
    return articles.where((a) => _isWithinThreeDays(a.publishedAt)).toList();
  }

  // Pull-to-refresh: full visible refresh (user-initiated)
  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    setState(() {
      _reachedTimeLimit = false;
    });
    await context.read<AppProvider>().refreshNews();
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final allArticles = provider.paginatedNews;

    // Filter to last 3 days only
    final articles = _filterByThreeDays(allArticles);

    // Check if we've reached the time limit
    _checkTimeLimit(articles);

    final isLoading = provider.isFetchingNews && articles.isEmpty;

    return Scaffold(
      backgroundColor: _C.offWhite,
      body: Column(
        children: [
          _AppBar(
            isLoading: provider.isFetchingNews && articles.isEmpty,
            onRefresh: _onRefresh,
            reachedTimeLimit: _reachedTimeLimit,
          ),
          Expanded(child: _buildBody(provider, articles, isLoading)),
        ],
      ),
    );
  }

  Widget _buildBody(AppProvider provider, List<NewsArticle> articles, bool isLoading) {
    if (isLoading && articles.isEmpty) return _buildSkeletonList();
    if (!isLoading && articles.isEmpty) return _buildEmptyState(provider);

    // Filter articles for display (already filtered)
    final featured = articles.take(3).toList();
    final listItems = articles.length > 3 ? articles.skip(3).toList() : <NewsArticle>[];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _C.primary,
      backgroundColor: _C.white,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (featured.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Top Stories',
                icon: Icons.local_fire_department_rounded,
                topPad: 12,
              ),
            ),

          if (featured.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 252,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: featured.length,
                  itemBuilder: (_, i) => _FeaturedCard(article: featured[i], isFirst: i == 0),
                ),
              ),
            ),

          if (listItems.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Latest News',
                icon: Icons.article_rounded,
                topPad: 22,
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArticleRow(article: listItems[i]),
                ),
                childCount: listItems.length,
              ),
            ),
          ),

          // ─── "You're all caught up" message when reached 3-day limit ───
          if (_reachedTimeLimit)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _C.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: _C.primary, size: 30),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "You're all caught up!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _C.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Showing news from the last 3 days',
                      style: TextStyle(
                        fontSize: 13,
                        color: _C.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Pagination footer: only show if not reached time limit and loading more
          if (!_reachedTimeLimit && provider.isLoadingMoreNews)
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _shimmerAnim,
                builder: (_, __) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: [
                      _SkeletonRow(opacity: _shimmerAnim.value),
                      const SizedBox(height: 10),
                      _SkeletonRow(opacity: _shimmerAnim.value * 0.65),
                    ],
                  ),
                ),
              ),
            )
          else if (!_reachedTimeLimit && !provider.hasMoreNews && !provider.isLoadingMoreNews && listItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Text(
                  'No more news available',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _C.muted),
                ),
              ),
            ),

          // Bottom breathing room so the last card isn't flush with screen edge
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SkeletonFeatured(opacity: _shimmerAnim.value),
          const SizedBox(height: 16),
          _SkeletonRow(opacity: _shimmerAnim.value),
          const SizedBox(height: 10),
          _SkeletonRow(opacity: _shimmerAnim.value * 0.85),
          const SizedBox(height: 10),
          _SkeletonRow(opacity: _shimmerAnim.value * 0.70),
          const SizedBox(height: 10),
          _SkeletonRow(opacity: _shimmerAnim.value * 0.55),
          const SizedBox(height: 10),
          _SkeletonRow(opacity: _shimmerAnim.value * 0.40),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76, height: 76,
            decoration: const BoxDecoration(color: _C.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.sports_soccer_rounded, size: 38, color: _C.primary),
          ),
          const SizedBox(height: 18),
          const Text('No Football News', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text)),
          const SizedBox(height: 8),
          const Text('Pull down to refresh', style: TextStyle(fontSize: 13, color: _C.muted)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _onRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRefresh;
  final bool reachedTimeLimit;

  const _AppBar({
    required this.isLoading,
    required this.onRefresh,
    this.reachedTimeLimit = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${months[now.month - 1]} ${now.year}';

    return Container(
      color: _C.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Row(
            children: [
              // ─── Official App Icon ──────────────────────────────────────────
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _C.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(children: [
                        TextSpan(text: 'Live', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5, color: _C.primary)),
                        TextSpan(text: 'Goal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5, color: _C.secondary)),
                        TextSpan(text: '  News', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3, color: _C.text)),
                      ]),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.sports_soccer_rounded, size: 11, color: _C.muted),
                        const SizedBox(width: 4),
                        Text('Latest 3 days • $dateStr', style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w500)),
                        if (reachedTimeLimit) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _C.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Caught up',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _C.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRefresh,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: isLoading ? _C.primaryLight : _C.offWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isLoading ? _C.primary.withOpacity(0.3) : _C.border),
                  ),
                  child: isLoading
                      ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))
                      : const Icon(Icons.refresh_rounded, size: 18, color: _C.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final double topPad;
  const _SectionHeader({required this.title, this.icon, this.topPad = 16});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, topPad, 16, 10),
    child: Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text)),
        if (icon != null) ...[
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: _C.muted),
        ],
      ],
    ),
  );
}

// ─── Gradient fallback image ───────────────────────────────────────────────────
class _GradientFallback extends StatelessWidget {
  final String headline;
  final String id;
  final double? height;
  final double? width;
  final bool showText;

  const _GradientFallback({
    required this.headline,
    required this.id,
    this.height,
    this.width,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _paletteFor(id);
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: showText
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer_rounded, color: Colors.white54, size: 26),
              const SizedBox(height: 6),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      )
          : const Center(
        child: Icon(Icons.sports_soccer_rounded, color: Colors.white38, size: 22),
      ),
    );
  }
}

// ─── Featured horizontal card ─────────────────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final NewsArticle article;
  final bool isFirst;
  const _FeaturedCard({required this.article, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article))),
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _C.text.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              article.imageUrl.isNotEmpty
                  ? Image.network(
                article.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _GradientFallback(
                    headline: article.headline, id: article.id, showText: true),
              )
                  : _GradientFallback(headline: article.headline, id: article.id, showText: true),

              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x4D000000), Color(0xE0000000)],
                    stops: [0.15, 0.5, 1.0],
                  ),
                ),
              ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (article.categories.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _C.secondary, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            article.categories.first.toUpperCase(),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        article.headline,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 10, color: Colors.white60),
                          const SizedBox(width: 3),
                          Flexible(child: Text(article.author, style: const TextStyle(fontSize: 10, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Text(' · ', style: TextStyle(fontSize: 10, color: Colors.white70)),
                          Text(Helpers.formatDateAgo(article.publishedAt), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isFirst)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('TOP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
                ),

              if (article.isVideo)
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(color: _C.liveRed, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text('VIDEO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Article list row ─────────────────────────────────────────────────────────
class _ArticleRow extends StatelessWidget {
  final NewsArticle article;
  const _ArticleRow({required this.article});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article))),
        borderRadius: BorderRadius.circular(14),
        splashColor: _C.primaryLight,
        highlightColor: _C.primaryLight.withOpacity(0.4),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: article.imageUrl.isNotEmpty
                      ? Image.network(
                    article.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _GradientFallback(
                        headline: article.headline, id: article.id,
                        width: 84, height: 84, showText: false),
                  )
                      : _GradientFallback(
                      headline: article.headline, id: article.id,
                      width: 84, height: 84, showText: false),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.categories.isNotEmpty || article.isVideo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            if (article.categories.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: _C.secondaryLight, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    article.categories.first.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _C.secondary, letterSpacing: 0.4),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            if (article.isVideo) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.play_circle_filled_rounded, size: 14, color: _C.liveRed),
                            ],
                          ],
                        ),
                      ),

                    Text(
                      article.headline,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _C.text, height: 1.35),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),

                    if (article.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.description,
                        style: const TextStyle(fontSize: 11, color: _C.muted, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(child: Text(article.author, style: const TextStyle(fontSize: 10, color: _C.muted, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Text(' · ', style: TextStyle(fontSize: 10, color: _C.muted)),
                        Text(Helpers.formatDateAgo(article.publishedAt), style: const TextStyle(fontSize: 10, color: _C.muted)),
                      ],
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
}

// ─── Skeleton: featured placeholder ──────────────────────────────────────────
class _SkeletonFeatured extends StatelessWidget {
  final double opacity;
  const _SkeletonFeatured({required this.opacity});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      height: 248,
      decoration: BoxDecoration(color: _C.shimmer1, borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 10, width: 64, decoration: BoxDecoration(color: _C.shimmer2, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(height: 14, decoration: BoxDecoration(color: _C.shimmer2, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 14, width: 200, decoration: BoxDecoration(color: _C.shimmer2, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 10),
            Container(height: 10, width: 120, decoration: BoxDecoration(color: _C.shimmer2, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    ),
  );
}

// ─── Skeleton: row placeholder ────────────────────────────────────────────────
class _SkeletonRow extends StatelessWidget {
  final double opacity;
  const _SkeletonRow({required this.opacity});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
      child: Row(
        children: [
          Container(width: 84, height: 84, decoration: BoxDecoration(color: _C.shimmer1, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: 56, decoration: BoxDecoration(color: _C.shimmer1, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 12, decoration: BoxDecoration(color: _C.shimmer1, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 5),
                Container(height: 12, width: 180, decoration: BoxDecoration(color: _C.shimmer1, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 10),
                Container(height: 10, width: 100, decoration: BoxDecoration(color: _C.shimmer1, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}