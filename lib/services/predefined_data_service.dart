import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps a validated, private on-device copy of the published fallback data.
/// The Dart constants remain available if the phone has never been online.
class PredefinedDataService extends ChangeNotifier {
  PredefinedDataService._();
  static final PredefinedDataService _instance = PredefinedDataService._();
  factory PredefinedDataService() => _instance;

  static const catalogUrl = String.fromEnvironment(
    'PREDEFINED_DATA_URL',
    defaultValue: 'https://livescore-one.vercel.app/predefined_data.json',
  );

  Map<String, dynamic>? _snapshot;
  bool get hasPublishedData => _snapshot != null;
  Future<void>? _refreshing;
  DateTime? _lastCheck;

  List<Map<String, dynamic>>? get famousPlayers =>
      (_snapshot?['famousPlayers'] as List?)?.cast<Map<String, dynamic>>();
  List<Map<String, String>>? get famousClubs =>
      (_snapshot?['famousClubs'] as List?)?.cast<Map<String, String>>();
  Map<String, Map<String, dynamic>>? get predefinedPlayerStats =>
      (_snapshot?['predefinedPlayerStats'] as Map?)
          ?.cast<String, Map<String, dynamic>>();
  Map<String, String>? get clubLogoIds =>
      (_snapshot?['clubLogoIds'] as Map?)?.cast<String, String>();

  Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/predefined_data.json');
  }

  Future<void> init() async {
    try {
      final file = await _dataFile();
      if (await file.exists()) {
        final parsed = _parse(await file.readAsString());
        if (parsed != null) _snapshot = parsed;
      }
    } catch (e) {
      debugPrint('[Predefined data] Could not read cached data: $e');
    }
  }

  Future<void> refresh({bool force = false}) {
    if (_refreshing != null) return _refreshing!;
    final now = DateTime.now();
    if (!force &&
        _lastCheck != null &&
        now.difference(_lastCheck!) < const Duration(minutes: 15)) {
      return Future.value();
    }
    _lastCheck = now;
    final pending = _download();
    _refreshing = pending;
    return pending.whenComplete(() => _refreshing = null);
  }

  Future<void> _download() async {
    try {
      final uri = Uri.parse(catalogUrl);
      if (uri.scheme != 'https') return;
      final response = await http.get(uri, headers: {
        'Cache-Control': 'no-cache'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 2 * 1024 * 1024) {
        return;
      }
      final parsed = _parse(utf8.decode(response.bodyBytes));
      if (parsed == null || parsed['revision'] == _snapshot?['revision']) {
        return;
      }

      final file = await _dataFile();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      await temporary.rename(file.path);
      _snapshot = parsed;
      notifyListeners();
    } catch (e) {
      debugPrint('[Predefined data] Refresh unavailable: $e');
    }
  }

  Map<String, dynamic>? _parse(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! Map ||
          data['schemaVersion'] != 1 ||
          data['revision'] is! String ||
          (data['revision'] as String).isEmpty ||
          data['famousPlayers'] is! List ||
          data['famousClubs'] is! List ||
          data['predefinedPlayerStats'] is! Map ||
          data['clubLogoIds'] is! Map) {
        return null;
      }
      final players = (data['famousPlayers'] as List).map((item) {
        const requiredFields = [
          'id', 'name', 'imageUrl', 'teamName', 'teamId',
          'position', 'jersey', 'nationality',
        ];
        if (item is! Map ||
            requiredFields.any((field) => item[field] is! String)) {
          throw const FormatException('Invalid player');
        }
        return Map<String, dynamic>.from(item);
      }).toList();
      final clubs = (data['famousClubs'] as List)
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
      final stats = (data['predefinedPlayerStats'] as Map).map((key, value) {
        if (value is! Map ||
            value['careerStats'] is! List ||
            value['seasonStats'] is! Map) {
          throw const FormatException('Invalid player statistics');
        }
        return MapEntry(key as String, Map<String, dynamic>.from(value));
      });
      final logos = Map<String, String>.from(data['clubLogoIds'] as Map);
      if (players.isEmpty || clubs.isEmpty || stats.isEmpty || logos.isEmpty) {
        return null;
      }
      return {
        'revision': data['revision'],
        'famousPlayers': players,
        'famousClubs': clubs,
        'predefinedPlayerStats': stats,
        'clubLogoIds': logos,
      };
    } catch (_) {
      return null;
    }
  }
}
