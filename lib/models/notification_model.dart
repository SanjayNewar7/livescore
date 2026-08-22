// lib/models/notification_model.dart
//
// Local-only notification item. Persisted through NotificationService as a
// plain Map inside a Hive box — the same pattern ProfileService/
// PreferencesService already use in this codebase (toMap()/fromMap(), no
// generated Hive adapter/typeId needed, so nothing here requires a
// build_runner run to work).
//
// Two kinds of notifications for this first version:
//  • NotificationType.news        — a favorite club or favorite player was
//                                    mentioned in a fetched news article.
//                                    Tapping opens ArticleDetailScreen with
//                                    the *original* NewsArticle so it renders
//                                    exactly like the News tab does.
//  • NotificationType.matchResult — a favorite team's match went final.
//                                    Tapping opens GameDetailScreen with the
//                                    full Game payload for that match.

import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/game_model.dart';

enum NotificationType { news, matchResult }

NotificationType _typeFromString(String? value) {
  switch (value) {
    case 'matchResult':
      return NotificationType.matchResult;
    case 'news':
    default:
      return NotificationType.news;
  }
}

String _typeToString(NotificationType type) {
  switch (type) {
    case NotificationType.matchResult:
      return 'matchResult';
    case NotificationType.news:
      return 'news';
  }
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;
  final String? matchedEntityName;
  final String? matchedEntityType;
  final NewsArticle? article;
  final Game? game;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.imageUrl,
    this.isRead = false,
    this.matchedEntityName,
    this.matchedEntityType,
    this.article,
    this.game,
  });

  bool get isNews => type == NotificationType.news;
  bool get isMatchResult => type == NotificationType.matchResult;

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      createdAt: createdAt,
      imageUrl: imageUrl,
      isRead: isRead ?? this.isRead,
      matchedEntityName: matchedEntityName,
      matchedEntityType: matchedEntityType,
      article: article,
      game: game,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': _typeToString(type),
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'matchedEntityName': matchedEntityName,
      'matchedEntityType': matchedEntityType,
      'article': article?.toJson(),
      'game': game?.toJson(),
    };
  }

  factory NotificationItem.fromMap(Map map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    NewsArticle? article;
    final rawArticle = map['article'];
    if (rawArticle is Map) {
      try {
        // This will now succeed because fromJson handles the map safely
        article = NewsArticle.fromJson(Map<String, dynamic>.from(rawArticle));
      } catch (_) {
        article = null;
      }
    }

    Game? game;
    final rawGame = map['game'];
    if (rawGame is Map) {
      try {
        game = Game.fromJson(Map<String, dynamic>.from(rawGame));
      } catch (_) {
        game = null;
      }
    }

    return NotificationItem(
      id: map['id']?.toString() ?? '',
      type: _typeFromString(map['type']?.toString()),
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      createdAt: parsedDate,
      isRead: map['isRead'] == true,
      matchedEntityName: map['matchedEntityName']?.toString(),
      matchedEntityType: map['matchedEntityType']?.toString(),
      article: article,
      game: game,
    );
  }
}