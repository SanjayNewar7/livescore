// lib/models/search_model.dart

class SearchResult {
  final String id;
  final String name;
  final String displayName;
  final String type; // 'player', 'team', 'league'
  final String? imageUrl;
  final String? teamName;
  final String? teamId;
  final String? leagueName;
  final String? leagueCode;
  final String? position;
  final String? jerseyNumber;
  final String? abbreviation;
  final String? nationality; // Added for players
  final int? age; // Added for players
  final String? rating; // Added for players

  SearchResult({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.imageUrl,
    this.teamName,
    this.teamId,
    this.leagueName,
    this.leagueCode,
    this.position,
    this.jerseyNumber,
    this.abbreviation,
    this.nationality,
    this.age,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'displayName': displayName,
    'type': type,
    'imageUrl': imageUrl,
    'teamName': teamName,
    'teamId': teamId,
    'leagueName': leagueName,
    'leagueCode': leagueCode,
    'position': position,
    'jerseyNumber': jerseyNumber,
    'abbreviation': abbreviation,
    'nationality': nationality,
    'age': age,
    'rating': rating,
  };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString(),
    teamName: json['teamName']?.toString(),
    teamId: json['teamId']?.toString(),
    leagueName: json['leagueName']?.toString(),
    leagueCode: json['leagueCode']?.toString(),
    position: json['position']?.toString(),
    jerseyNumber: json['jerseyNumber']?.toString(),
    abbreviation: json['abbreviation']?.toString(),
    nationality: json['nationality']?.toString(),
    age: json['age'] as int?,
    rating: json['rating']?.toString(),
  );

  // Helper to get display initials for avatar fallback
  String get initials {
    if (type == 'player') {
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
      }
      return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    } else {
      return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    }
  }

  // Helper to get display subtitle
  String get subtitle {
    switch (type) {
      case 'player':
        final parts = <String>[];
        if (position != null && position!.isNotEmpty) {
          parts.add(position!);
        }
        if (teamName != null && teamName!.isNotEmpty) {
          parts.add(teamName!);
        }
        if (jerseyNumber != null && jerseyNumber!.isNotEmpty) {
          parts.add('#${jerseyNumber}');
        }
        if (nationality != null && nationality!.isNotEmpty) {
          parts.add(nationality!);
        }
        return parts.isNotEmpty ? parts.join(' • ') : 'Player';
      case 'team':
        if (leagueName != null && leagueName!.isNotEmpty) {
          return leagueName!;
        }
        return 'Team';
      case 'league':
        return 'League';
      default:
        return '';
    }
  }

  // Helper to get the display image URL or fallback
  String get displayImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    // Fallback for teams without logos
    if (type == 'team' && id.isNotEmpty) {
      return 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
    }
    // Fallback for players without photos
    if (type == 'player' && id.isNotEmpty) {
      return 'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/$id.png&w=96&h=70';
    }
    return '';
  }
}

class SearchResponse {
  final List<SearchResult> players;
  final List<SearchResult> teams;
  final List<SearchResult> leagues;
  final bool hasMore;

  const SearchResponse({
    this.players = const [],
    this.teams = const [],
    this.leagues = const [],
    this.hasMore = false,
  });

  bool get isEmpty => players.isEmpty && teams.isEmpty && leagues.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get totalCount => players.length + teams.length + leagues.length;

  // Helper to get all results combined
  List<SearchResult> get allResults => [
    ...leagues,
    ...teams,
    ...players,
  ];

  // Helper to get results by type
  List<SearchResult> getByType(String type) {
    switch (type) {
      case 'player': return players;
      case 'team': return teams;
      case 'league': return leagues;
      default: return [];
    }
  }

  Map<String, dynamic> toJson() => {
    'players': players.map((e) => e.toJson()).toList(),
    'teams': teams.map((e) => e.toJson()).toList(),
    'leagues': leagues.map((e) => e.toJson()).toList(),
    'hasMore': hasMore,
  };

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
    players: (json['players'] as List?)
        ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    teams: (json['teams'] as List?)
        ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    leagues: (json['leagues'] as List?)
        ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    hasMore: json['hasMore'] ?? false,
  );

  // Create an empty response
  static const empty = SearchResponse();
}