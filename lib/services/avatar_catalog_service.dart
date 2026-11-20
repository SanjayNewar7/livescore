import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class AnimeAvatar {
  final String id;
  final String url;
  const AnimeAvatar(this.id, this.url);

  static AnimeAvatar? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString() ?? '';
    final url = value['url']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (id.isEmpty ||
        uri?.scheme != 'https' ||
        uri?.host != 'res.cloudinary.com' ||
        !uri!.path.startsWith('/dkk7zqgnz/image/upload/')) return null;
    return AnimeAvatar(id, url);
  }

  Map<String, String> toJson() => {'id': id, 'url': url};
}

class AvatarCatalogService {
  static const endpoint = String.fromEnvironment('AVATAR_CATALOG_URL');
  static const _boxName = 'anime_avatar_catalog';
  static const _key = 'avatars';

  Future<List<AnimeAvatar>> getAvatars({bool refresh = true}) async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    final cached = _parse(box.get(_key));
    if (!refresh || endpoint.isEmpty) return cached;
    try {
      final uri = Uri.parse(endpoint);
      if (uri.scheme != 'https') return cached;
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return cached;
      final decoded = jsonDecode(response.body);
      final avatars = _parse(decoded is Map ? decoded['avatars'] : null);
      if (avatars.isEmpty) return cached;
      await box.put(_key, avatars.map((a) => a.toJson()).toList());
      return avatars;
    } catch (_) {
      return cached;
    }
  }

  List<AnimeAvatar> _parse(Object? value) {
    if (value is! List) return const [];
    return value.map(AnimeAvatar.fromJson).whereType<AnimeAvatar>().toList();
  }
}
