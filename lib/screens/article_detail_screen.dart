import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/helpers.dart';

class _C {
  static const blue = Color(0xFF1A62C8);
  static const blueLight = Color(0xFFE8F0FC);
  static const border = Color(0xFFE2E8F2);
  static const text = Color(0xFF0F1623);
  static const muted = Color(0xFF6B7A96);
  static const offWhite = Color(0xFFF5F7FB);
  static const liveRed = Color(0xFFE53535);
  static const white = Color(0xFFFFFFFF);
}

class ArticleDetailScreen extends StatelessWidget {
  final NewsArticle article;

  const ArticleDetailScreen({super.key, required this.article});

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

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        debugPrint('Could not launch $url');
        if (url.startsWith('https://')) {
          final httpUrl = url.replaceFirst('https://', 'http://');
          final httpUri = Uri.parse(httpUrl);
          if (await canLaunchUrl(httpUri)) {
            await launchUrl(httpUri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _shareArticle(BuildContext context) async {
    final String shareText = '''
${article.headline}

${article.description.isNotEmpty ? '${article.description}\n\n' : ''}Read more: ${_webUrl ?? 'https://www.espn.com/soccer'}

Shared via LiveScore App
''';

    // Try using share_plus if available
    try {
      // Use dart:io for platform-specific sharing as fallback
      await _shareViaPlatform(shareText, article.headline);
    } catch (e) {
      // Fallback: Copy to clipboard
      await _copyToClipboard(context, shareText);
    }
  }

  Future<void> _shareViaPlatform(String text, String subject) async {
    // For Android/iOS - using platform channels directly
    // This is a simpler approach that doesn't rely on share_plus
    try {
      // Use url_launcher with mailto: as fallback
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: '',
        queryParameters: {
          'subject': subject,
          'body': text,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw Exception('Cannot launch share dialog');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article link copied to clipboard!'),
          backgroundColor: _C.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? webUrl = _webUrl;

    return Scaffold(
      backgroundColor: _C.offWhite,
      appBar: AppBar(
        title: const Text('NEWS', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _C.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _C.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: _C.blue),
            onPressed: () => _shareArticle(context),
          ),
          if (webUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: _C.blue),
              onPressed: () => _launchUrl(webUrl),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.categories.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: article.categories.map((category) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _C.blueLight, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          category,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.blue),
                        ),
                      )).toList(),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    article.headline,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _C.text, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: _C.muted),
                      const SizedBox(width: 4),
                      Text(
                        article.author,
                        style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded, size: 14, color: _C.muted),
                      const SizedBox(width: 4),
                      Text(
                        Helpers.formatDateAgo(article.publishedAt),
                        style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: _C.border),
                  _buildHtmlContent(),
                  const SizedBox(height: 24),
                  if (webUrl != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: _C.blueLight, borderRadius: BorderRadius.circular(12)),
                      child: TextButton(
                        onPressed: () => _launchUrl(webUrl),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_browser_rounded, size: 18, color: _C.blue),
                            SizedBox(width: 8),
                            Text('Read full article on ESPN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.blue)),
                          ],
                        ),
                      ),
                    ),
                  if (article.videoUrl != null) const SizedBox(height: 16),
                  if (article.videoUrl != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: _C.blueLight, borderRadius: BorderRadius.circular(12)),
                      child: TextButton(
                        onPressed: () => _launchUrl(article.videoUrl!),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_filled_rounded, size: 20, color: _C.liveRed),
                            SizedBox(width: 8),
                            Text('Watch highlights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.liveRed)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    if (article.imageUrl.isNotEmpty) {
      return Hero(
        tag: article.id,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: Image.network(
            article.imageUrl,
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildImageFallback(),
          ),
        ),
      );
    }
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.blue.withOpacity(0.7), _C.blue.withOpacity(0.3)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            article.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlContent() {
    final content = article.body.isNotEmpty ? article.body : article.description;

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
            fontSize: FontSize(14.0),
            color: _C.muted,
            lineHeight: LineHeight(1.6),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "p": Style(
            margin: Margins.only(bottom: 12.0),
            fontSize: FontSize(14.0),
            color: _C.muted,
            lineHeight: LineHeight(1.6),
          ),
          "strong": Style(
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
          "b": Style(
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
          "a": Style(
            color: _C.blue,
            textDecoration: TextDecoration.underline,
          ),
          "h1": Style(
            fontSize: FontSize(20.0),
            fontWeight: FontWeight.w700,
            color: _C.text,
            margin: Margins.only(bottom: 12.0),
          ),
          "h2": Style(
            fontSize: FontSize(18.0),
            fontWeight: FontWeight.w700,
            color: _C.text,
            margin: Margins.only(bottom: 10.0),
          ),
          "h3": Style(
            fontSize: FontSize(16.0),
            fontWeight: FontWeight.w700,
            color: _C.text,
            margin: Margins.only(bottom: 8.0),
          ),
        },
      );
    }

    return Text(
      content,
      style: const TextStyle(fontSize: 14, height: 1.6, color: _C.muted),
    );
  }
}