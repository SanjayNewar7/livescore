import 'package:flutter/material.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/screens/article_detail_screen.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/helpers.dart';

class NewsCard extends StatelessWidget {
  final NewsArticle article;

  const NewsCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(article: article),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: article.imageUrl.isNotEmpty
                    ? Image.network(
                  article.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),

              // Content — Expanded to avoid Row overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category tag + video badge
                    if (article.categories.isNotEmpty || article.isVideo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            if (article.categories.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    article.categories.first,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            if (article.isVideo) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.play_circle_filled, size: 14, color: Colors.red),
                            ],
                          ],
                        ),
                      ),

                    // Headline
                    Text(
                      article.headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.pureBlack,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Description
                    if (article.description.isNotEmpty)
                      Text(
                        article.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.lightGray,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),

                    // Author + time — using Flexible to prevent overflow
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            article.author,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.lightGray,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(fontSize: 10, color: AppTheme.lightGray),
                        ),
                        Text(
                          Helpers.formatDateAgo(article.publishedAt),
                          style: const TextStyle(fontSize: 10, color: AppTheme.lightGray),
                        ),
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

  Widget _placeholder() => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: AppTheme.lightBlue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.article_rounded, color: AppTheme.primaryBlue, size: 32),
  );
}