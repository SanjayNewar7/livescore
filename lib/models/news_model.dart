import 'package:hive/hive.dart';

part 'news_model.g.dart';

@HiveType(typeId: 8)
class NewsArticle {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String headline;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String body;

  @HiveField(4)
  final String imageUrl;

  @HiveField(5)
  final String publishedAt;

  @HiveField(6)
  final String author;

  @HiveField(7)
  final List<String> categories;

  @HiveField(8)
  final String? videoUrl;

  @HiveField(9)
  final Map<String, dynamic>? links;

  @HiveField(10)
  final String imageCaption;

  @HiveField(11)
  final String? webUrl;

  @HiveField(12)
  final String articleType;

  const NewsArticle({
    required this.id,
    required this.headline,
    required this.description,
    required this.body,
    required this.imageUrl,
    required this.publishedAt,
    required this.author,
    required this.categories,
    this.videoUrl,
    this.links,
    this.imageCaption = '',
    this.webUrl,
    this.articleType = 'story',
  });

  bool get isVideo => articleType == 'video' || videoUrl != null;

  String? get openUrl => webUrl ?? videoUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'headline': headline,
      'description': description,
      'body': body,
      'imageUrl': imageUrl,
      'publishedAt': publishedAt,
      'author': author,
      'categories': categories,
      'videoUrl': videoUrl,
      'links': links,
      'imageCaption': imageCaption,
      'webUrl': webUrl,
      'articleType': articleType,
    };
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      publishedAt: json['publishedAt']?.toString() ?? '',
      author: json['author']?.toString() ?? 'ESPN',
      categories: (json['categories'] as List?)?.map((c) => c.toString()).toList() ?? [],
      videoUrl: json['videoUrl']?.toString(),
      // ✅ FIX: safe conversion for Hive-deserialized maps
      links: json['links']?.cast<String, dynamic>(),
      imageCaption: json['imageCaption']?.toString() ?? '',
      webUrl: json['webUrl']?.toString(),
      articleType: json['articleType']?.toString() ?? 'story',
    );
  }
}