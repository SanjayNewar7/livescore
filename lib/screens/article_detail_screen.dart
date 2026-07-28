import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/helpers.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
// LiveGoal palette: green is the primary brand color, blue is the secondary /
// informational accent (links, category chips).
class _C {
  static const primary      = Color(0xFF16A34A); // brand green
  static const primaryDark  = Color(0xFF0E7C39);
  static const primaryLight = Color(0xFFE7F7ED);
  static const secondary      = Color(0xFF1A62C8); // brand blue
  static const secondaryLight = Color(0xFFE8F0FC);
  static const border   = Color(0xFFE2E8F2);
  static const text     = Color(0xFF0F1623);
  static const muted    = Color(0xFF6B7A96);
  static const offWhite = Color(0xFFF5F7FB);
  static const liveRed  = Color(0xFFE53535);
  static const white    = Color(0xFFFFFFFF);
}

class ArticleDetailScreen extends StatefulWidget {
  final NewsArticle article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final ScrollController _scroll = ScrollController();

  // ── Perf note ────────────────────────────────────────────────────────────
  // These used to be plain fields updated via setState() inside the scroll
  // listener. That reruns build() on *every* scroll frame, which re-parses
  // the flutter_html body on every frame — that's what was tanking FPS while
  // reading an article. ValueNotifiers + ValueListenableBuilder scope the
  // rebuild to just the progress bar / app bar chrome, so the (expensive,
  // scroll-independent) article body is built exactly once.
  final ValueNotifier<double> _readProgress = ValueNotifier(0);
  final ValueNotifier<bool> _collapsed = ValueNotifier(false);

  // Cache the parsed HTML widget instead of rebuilding/reparsing it — it
  // never changes after the article is loaded.
  Widget? _cachedHtmlContent;

  NewsArticle get article => widget.article;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _readProgress.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final offset = _scroll.offset;

    final rawProgress = max > 0 ? (offset / max).clamp(0.0, 1.0) : 0.0;
    // Round to avoid firing a notifier update (and rebuild) on every single
    // pixel of scroll — a visually-imperceptible 0.5% step is plenty.
    final progress = (rawProgress * 200).round() / 200;
    final collapsed = offset > 220;

    if (progress != _readProgress.value) _readProgress.value = progress;
    if (collapsed != _collapsed.value) _collapsed.value = collapsed;
  }

  String? get _webUrl {
    String? url = article.webUrl ??
        article.links?['web']?['href'] ??
        article.links?['source']?['href'] ??
        article.links?['mobile']?['app']?['href'];

    if (url != null && !url.startsWith('http')) {
      url = 'https://$url';
    }
    return url;
  }

  /// Rough reading time estimate based on word count of the body/description.
  int get _readMinutes {
    final content = article.body.isNotEmpty ? article.body : article.description;
    final plain = content.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final words = plain.trim().isEmpty ? 0 : plain.trim().split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    final Uri uri = Uri.parse(url);

    // NOTE: we deliberately do NOT gate this on canLaunchUrl(). On Android
    // 11+ (API 30+), canLaunchUrl() returns false for basically any URL
    // unless the app's AndroidManifest.xml declares a <queries> block —
    // it's a package-visibility restriction, not a real "nothing can open
    // this" signal. Relying on it here is what made every tap silently do
    // nothing. Calling launchUrl() directly and catching failures is the
    // reliable way to do this.
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      if (!launched) {
        _showLaunchError(url);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      _showLaunchError(url);
    }
  }

  void _showLaunchError(String url) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text("Couldn't open the link. No app is set up to handle it.")),
          ],
        ),
        backgroundColor: _C.liveRed,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _shareArticle(BuildContext context) async {
    final String shareText = '''
${article.headline}

${article.description.isNotEmpty ? '${article.description}\n\n' : ''}Read more: ${_webUrl ?? 'https://www.espn.com/soccer'}

Shared via LiveGoal
''';

    try {
      await _shareViaPlatform(shareText, article.headline);
    } catch (e) {
      await _copyToClipboard(context, shareText, message: 'Article link copied to clipboard!');
    }
  }

  Future<void> _shareViaPlatform(String text, String subject) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: '',
      queryParameters: {
        'subject': subject,
        'body': text,
      },
    );
    // Same reasoning as _launchUrl: don't gate on canLaunchUrl(), just try
    // and let the caller's catch handle the clipboard fallback.
    await launchUrl(emailUri);
  }

  Future<void> _copyToClipboard(BuildContext context, String text, {String message = 'Copied to clipboard!'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(message),
            ],
          ),
          backgroundColor: _C.primaryDark,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    final url = _webUrl;
    if (url == null) return;
    await _copyToClipboard(context, url, message: 'Link copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final String? webUrl = _webUrl;

    return Scaffold(
      backgroundColor: _C.offWhite,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            slivers: [
              ValueListenableBuilder<bool>(
                valueListenable: _collapsed,
                builder: (_, collapsed, __) => _buildSliverAppBar(context, collapsed),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTagRow(),
                      const SizedBox(height: 14),
                      _buildHeadline(),
                      const SizedBox(height: 14),
                      _buildMetaRow(),
                      const SizedBox(height: 20),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      if (article.description.isNotEmpty) _buildLeadParagraph(),
                      _buildHtmlContent(),
                      const SizedBox(height: 8),
                      _buildActionCards(webUrl),
                      const SizedBox(height: 28),
                      _buildQuickActionsRow(context, webUrl),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildProgressBar(),
        ],
      ),
    );
  }

  // ── Reading progress bar, pinned to the very top of the screen ─────────────
  // Wrapped in its own ValueListenableBuilder so only this 3px sliver of UI
  // repaints per scroll frame, not the whole screen.
  Widget _buildProgressBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 3,
          child: ValueListenableBuilder<double>(
            valueListenable: _readProgress,
            builder: (_, progress, __) => LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(_C.primary),
            ),
          ),
        ),
      ),
    );
  }

  // ── Collapsing hero image app bar ───────────────────────────────────────────
  Widget _buildSliverAppBar(BuildContext context, bool collapsed) {
    return SliverAppBar(
      pinned: true,
      stretch: true,
      backgroundColor: collapsed ? _C.white : Colors.transparent,
      elevation: collapsed ? 1 : 0,
      expandedHeight: 280,
      leading: _buildCircleButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.pop(context),
        dark: !collapsed,
      ),
      actions: [
        _buildCircleButton(
          icon: Icons.share_rounded,
          onTap: () => _shareArticle(context),
          dark: !collapsed,
        ),
        const SizedBox(width: 8),
        if (_webUrl != null)
          _buildCircleButton(
            icon: Icons.open_in_browser_rounded,
            onTap: () => _launchUrl(_webUrl!),
            dark: !collapsed,
          ),
        const SizedBox(width: 12),
      ],
      title: collapsed
          ? Text(
        article.headline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.text),
      )
          : null,
      // RepaintBoundary keeps the hero image's own repaints (e.g. the Hero
      // flight) from forcing the rest of the sliver tree to repaint too.
      flexibleSpace: RepaintBoundary(
        child: FlexibleSpaceBar(
          stretchModes: const [StretchMode.zoomBackground],
          background: _buildHeroImage(),
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap, required bool dark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: dark ? Colors.black.withOpacity(0.35) : _C.offWhite,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: dark ? Colors.white : _C.text),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    if (article.imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: article.id,
            child: Image.network(
              article.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImageFallback(),
            ),
          ),
          // Scrim so the status bar / back button stay legible over any photo
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Colors.transparent, Color(0x99000000)],
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),
          if (article.imageCaption.isNotEmpty)
            Positioned(
              left: 16, right: 16, bottom: 12,
              child: Text(
                article.imageCaption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
          if (article.isVideo)
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white70),
            ),
        ],
      );
    }
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.primary, _C.secondary],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer_rounded, color: Colors.white70, size: 34),
              const SizedBox(height: 12),
              Text(
                article.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category chips + article-type / video badges ────────────────────────────
  Widget _buildTagRow() {
    if (article.categories.isEmpty && !article.isVideo) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...article.categories.map((category) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _C.secondaryLight, borderRadius: BorderRadius.circular(6)),
          child: Text(
            category.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _C.secondary, letterSpacing: 0.4),
          ),
        )),
        if (article.isVideo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _C.liveRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill_rounded, size: 12, color: _C.liveRed),
                SizedBox(width: 4),
                Text('VIDEO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _C.liveRed, letterSpacing: 0.4)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeadline() {
    return Text(
      article.headline,
      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _C.text, height: 1.28, letterSpacing: -0.3),
    );
  }

  // ── Author / date / estimated read time ─────────────────────────────────────
  Widget _buildMetaRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: _C.primaryLight,
          child: Text(
            article.author.isNotEmpty ? article.author[0].toUpperCase() : 'E',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.primary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.author.isNotEmpty ? article.author : 'ESPN',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                Helpers.formatDateAgo(article.publishedAt),
                style: const TextStyle(fontSize: 11.5, color: _C.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _C.offWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: _C.muted),
              const SizedBox(width: 4),
              Text('$_readMinutes min read', style: const TextStyle(fontSize: 11, color: _C.muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Container(width: 28, height: 3, decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Expanded(child: Container(height: 1, color: _C.border)),
      ],
    );
  }

  // ── Description shown as a styled lead / dek, distinct from the body ───────
  Widget _buildLeadParagraph() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.primaryLight.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _C.primary, width: 3)),
        ),
        child: Text(
          article.description,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: _C.text, height: 1.5, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildHtmlContent() {
    // Parsing HTML is the most expensive thing on this screen — cache the
    // resulting widget so it is built once, not on every incidental rebuild.
    return _cachedHtmlContent ??= RepaintBoundary(child: _buildHtmlContentUncached());
  }

  Widget _buildHtmlContentUncached() {
    final content = article.body.isNotEmpty ? article.body : '';

    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasHtmlTags = RegExp(r'<[^>]*>').hasMatch(content);

    if (hasHtmlTags) {
      return Html(
        data: content,
        onAnchorTap: (url, attributes, element) {
          if (url != null && url.isNotEmpty) {
            _launchUrl(url);
          }
        },
        style: {
          "body": Style(
            fontSize: FontSize(15.5),
            color: _C.text,
            lineHeight: LineHeight(1.7),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "p": Style(
            margin: Margins.only(bottom: 16.0),
            fontSize: FontSize(15.5),
            color: _C.text,
            lineHeight: LineHeight(1.7),
          ),
          "strong": Style(fontWeight: FontWeight.w700, color: _C.text),
          "b": Style(fontWeight: FontWeight.w700, color: _C.text),
          "em": Style(fontStyle: FontStyle.italic),
          "i": Style(fontStyle: FontStyle.italic),
          "a": Style(
            color: _C.secondary,
            textDecoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
          ),
          "h1": Style(
            fontSize: FontSize(22.0),
            fontWeight: FontWeight.w800,
            color: _C.text,
            margin: Margins.only(top: 8.0, bottom: 14.0),
          ),
          "h2": Style(
            fontSize: FontSize(19.0),
            fontWeight: FontWeight.w800,
            color: _C.text,
            margin: Margins.only(top: 8.0, bottom: 12.0),
          ),
          "h3": Style(
            fontSize: FontSize(17.0),
            fontWeight: FontWeight.w700,
            color: _C.text,
            margin: Margins.only(top: 6.0, bottom: 10.0),
          ),
          "ul": Style(margin: Margins.only(bottom: 16.0, left: 4.0)),
          "ol": Style(margin: Margins.only(bottom: 16.0, left: 4.0)),
          "li": Style(
            fontSize: FontSize(15.5),
            color: _C.text,
            lineHeight: LineHeight(1.6),
            margin: Margins.only(bottom: 6.0),
          ),
          "blockquote": Style(
            margin: Margins.symmetric(vertical: 14.0),
            padding: HtmlPaddings.only(left: 16.0, top: 4.0, bottom: 4.0),
            border: const Border(left: BorderSide(color: _C.primary, width: 3)),
            fontStyle: FontStyle.italic,
            color: _C.muted,
            fontSize: FontSize(15.0),
          ),
          "img": Style(
            margin: Margins.symmetric(vertical: 12.0),
          ),
          "figcaption": Style(
            fontSize: FontSize(11.5),
            color: _C.muted,
            fontStyle: FontStyle.italic,
            textAlign: TextAlign.center,
          ),
          "hr": Style(
            margin: Margins.symmetric(vertical: 20.0),
          ),
        },
      );
    }

    return Text(
      content,
      style: const TextStyle(fontSize: 15.5, height: 1.7, color: _C.text),
    );
  }

  // ── Read on ESPN / Watch highlights cards ───────────────────────────────────
  Widget _buildActionCards(String? webUrl) {
    return Column(
      children: [
        if (webUrl != null)
          _ActionCard(
            icon: Icons.language_rounded,
            iconColor: _C.secondary,
            iconBg: _C.secondaryLight,
            title: 'Read full article',
            subtitle: 'Continue reading on ESPN',
            onTap: () => _launchUrl(webUrl),
          ),
        if (webUrl != null && article.videoUrl != null) const SizedBox(height: 10),
        if (article.videoUrl != null)
          _ActionCard(
            icon: Icons.play_circle_fill_rounded,
            iconColor: _C.liveRed,
            iconBg: _C.liveRed.withOpacity(0.1),
            title: 'Watch highlights',
            subtitle: 'Video coverage of this story',
            onTap: () => _launchUrl(article.videoUrl!),
          ),
      ],
    );
  }

  // ── Bottom quick-actions: share / copy link ─────────────────────────────────
  Widget _buildQuickActionsRow(BuildContext context, String? webUrl) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () => _shareArticle(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.link_rounded,
            label: 'Copy link',
            enabled: webUrl != null,
            onTap: () => _copyLink(context),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable "action card" (Read full article / Watch highlights) ───────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _C.text)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: _C.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable pill quick-action button (Share / Copy link) ───────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: _C.offWhite,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: _C.primary),
                const SizedBox(width: 7),
                Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}