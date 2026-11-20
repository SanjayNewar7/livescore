import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/services/notification_service.dart';

void main() {
  late Directory directory;
  final service = NotificationService();

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('livegoal_notifications_');
    Hive.init(directory.path);
    await Hive.openBox('notifications_box');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  NewsArticle article(String id) => NewsArticle(
        id: id,
        headline: 'Manchester United team news',
        description: '',
        body: '',
        imageUrl: '',
        publishedAt: DateTime.now().toIso8601String(),
        author: 'ESPN',
        categories: const [],
      );

  test('opening an article marks its existing notification read', () async {
    await service.generateNewsNotifications(
      articles: [article('already-notified')],
      favoriteTeamNames: ['Manchester United'],
    );
    expect(service.unreadCount, 1);
    await service.markNewsArticleRead('already-notified');
    expect(service.unreadCount, 0);
  });

  test('opening an article before a news refresh keeps it read', () async {
    await service.markNewsArticleRead('read-before-refresh');
    await service.generateNewsNotifications(
      articles: [article('read-before-refresh')],
      favoriteTeamNames: ['Manchester United'],
    );
    expect(service.getAll().singleWhere((n) => n.article?.id ==
        'read-before-refresh').isRead, isTrue);
  });
}
