// lib/utils/constants.dart

class AppConstants {
  // ESPN API Endpoints for Football (Soccer)
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/soccer';
  static const String standingsUrl = 'https://site.api.espn.com/apis/v2/sports/soccer';
  static const String cdnUrl = 'https://cdn.espn.com';
  static const String newsUrl = 'https://now.core.api.espn.com/v1/sports/news';

  // Cache durations
  static const int cacheDurationLiveGames = 30000;
  static const int cacheDurationStandings = 300000;
  static const int cacheDurationNews = 300000;

  // ─── OFFICIAL FIFA WORLD CUP 2026 LOGO FROM ESPN API ─────────────────────────
  // Official ESPN CDN URLs for FIFA World Cup 2026
  static const String fifaWorldCup2026LogoUrl = 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/4.png&h=80&w=80&scale=crop';
  static const String fifaWorldCup2026LogoUrlLarge = 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/4.png&h=200&w=200&scale=crop';
  static const String fifaWorldCup2026LogoUrlSmall = 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/4.png&h=30&w=30&scale=crop';

  // Official FIFA World Cup trophy image fallback
  static const String fifaWorldCupTrophyUrl = 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/fifa.world.png&h=80&w=80&scale=crop';

  // ─── TIER 1: ELITE — Fetched first, shown first, always on top ────────────────
  static const List<Map<String, String>> priorityLeagues = [
    {'code': 'uefa.champions',  'name': 'Champions League',    'flag': '🏆', 'country': 'Europe'},
    {'code': 'uefa.europa',     'name': 'Europa League',       'flag': '🏆', 'country': 'Europe'},
    {'code': 'uefa.conference', 'name': 'Conference League',   'flag': '🏆', 'country': 'Europe'},
    {'code': 'eng.1', 'name': 'Premier League',  'flag': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'country': 'England'},
    {'code': 'esp.1', 'name': 'La Liga',         'flag': '🇪🇸', 'country': 'Spain'},
    {'code': 'ita.1', 'name': 'Serie A',         'flag': '🇮🇹', 'country': 'Italy'},
    {'code': 'ger.1', 'name': 'Bundesliga',      'flag': '🇩🇪', 'country': 'Germany'},
    {'code': 'fra.1', 'name': 'Ligue 1',         'flag': '🇫🇷', 'country': 'France'},
    {'code': 'por.1', 'name': 'Primeira Liga',      'flag': '🇵🇹', 'country': 'Portugal'},
    {'code': 'ned.1', 'name': 'Eredivisie',         'flag': '🇳🇱', 'country': 'Netherlands'},
    {'code': 'tur.1', 'name': 'Süper Lig',          'flag': '🇹🇷', 'country': 'Turkey'},
    {'code': 'bel.1', 'name': 'Pro League',         'flag': '🇧🇪', 'country': 'Belgium'},
    {'code': 'sco.1', 'name': 'Premiership',        'flag': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'country': 'Scotland'},
    {'code': 'aut.1', 'name': 'Austrian Bundesliga','flag': '🇦🇹', 'country': 'Austria'},
    {'code': 'sui.1', 'name': 'Super League',       'flag': '🇨🇭', 'country': 'Switzerland'},
    {'code': 'bra.1', 'name': 'Brasileirão',     'flag': '🇧🇷', 'country': 'Brazil'},
    {'code': 'usa.1', 'name': 'MLS',             'flag': '🇺🇸', 'country': 'USA'},
    {'code': 'mex.1', 'name': 'Liga MX',         'flag': '🇲🇽', 'country': 'Mexico'},
    {'code': 'arg.1', 'name': 'Liga Profesional','flag': '🇦🇷', 'country': 'Argentina'},
    {'code': 'jpn.1', 'name': 'J1 League',  'flag': '🇯🇵', 'country': 'Japan'},
    {'code': 'swe.1', 'name': 'Allsvenskan', 'flag': '🇸🇪', 'country': 'Sweden'},
    {'code': 'nor.1', 'name': 'Eliteserien', 'flag': '🇳🇴', 'country': 'Norway'},
    {'code': 'den.1', 'name': 'Superliga',   'flag': '🇩🇰', 'country': 'Denmark'},
  ];

  // ─── TIER 2: MAJOR SOUTH AMERICAN & OTHER CLUB COMPETITIONS ──────────────────
  static const List<Map<String, String>> majorClubCompetitions = [
    {'code': 'conmebol.libertadores', 'name': 'Copa Libertadores',          'flag': '🏆', 'country': 'South America'},
    {'code': 'conmebol.sudamericana', 'name': 'Copa Sudamericana',          'flag': '🏆', 'country': 'South America'},
    {'code': 'concacaf.champions',    'name': 'CONCACAF Champions League',  'flag': '🏆', 'country': 'CONCACAF'},
    {'code': 'afc.champions',         'name': 'AFC Champions League',       'flag': '🏆', 'country': 'Asia'},
    {'code': 'caf.champions',         'name': 'CAF Champions League',       'flag': '🏆', 'country': 'Africa'},
    {'code': 'fifa.clubworld',        'name': 'FIFA Club World Cup',        'flag': '🌍', 'country': 'International'},
  ];

  // ─── TIER 3: BACKGROUND LEAGUES ──────────────────────────────────────────────
  static const List<Map<String, String>> backgroundLeagues = [
    {'code': 'eng.2', 'name': 'Championship',              'flag': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'country': 'England'},
    {'code': 'eng.3', 'name': 'League One',                'flag': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'country': 'England'},
    {'code': 'eng.4', 'name': 'League Two',                'flag': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'country': 'England'},
    {'code': 'fin.1', 'name': 'Veikkausliiga',             'flag': '🇫🇮', 'country': 'Finland'},
    {'code': 'isl.1', 'name': 'Besta-deild karla',         'flag': '🇮🇸', 'country': 'Iceland'},
    {'code': 'cze.1', 'name': 'First League',              'flag': '🇨🇿', 'country': 'Czech Republic'},
    {'code': 'gre.1', 'name': 'Super League',              'flag': '🇬🇷', 'country': 'Greece'},
    {'code': 'pol.1', 'name': 'Ekstraklasa',               'flag': '🇵🇱', 'country': 'Poland'},
    {'code': 'cro.1', 'name': 'HNL',                       'flag': '🇭🇷', 'country': 'Croatia'},
    {'code': 'isr.1', 'name': 'Ligat ha\'Al',              'flag': '🇮🇱', 'country': 'Israel'},
    {'code': 'rus.1', 'name': 'Russian Premier League',    'flag': '🇷🇺', 'country': 'Russia'},
    {'code': 'ukr.1', 'name': 'Ukrainian Premier League',  'flag': '🇺🇦', 'country': 'Ukraine'},
    {'code': 'rou.1', 'name': 'Liga I',                    'flag': '🇷🇴', 'country': 'Romania'},
    {'code': 'bul.1', 'name': 'First League',              'flag': '🇧🇬', 'country': 'Bulgaria'},
    {'code': 'hun.1', 'name': 'NB I',                      'flag': '🇭🇺', 'country': 'Hungary'},
    {'code': 'svk.1', 'name': 'Fortuna Liga',              'flag': '🇸🇰', 'country': 'Slovakia'},
    {'code': 'cyp.1', 'name': 'First Division',            'flag': '🇨🇾', 'country': 'Cyprus'},
    {'code': 'kr.1',  'name': 'K League 1',                'flag': '🇰🇷', 'country': 'South Korea'},
    {'code': 'chn.1', 'name': 'Chinese Super League',      'flag': '🇨🇳', 'country': 'China'},
    {'code': 'ind.1', 'name': 'Indian Super League',       'flag': '🇮🇳', 'country': 'India'},
    {'code': 'tha.1', 'name': 'Thai League 1',             'flag': '🇹🇭', 'country': 'Thailand'},
    {'code': 'aus.1', 'name': 'A-League',                  'flag': '🇦🇺', 'country': 'Australia'},
    {'code': 'egy.1', 'name': 'Egyptian Premier League',   'flag': '🇪🇬', 'country': 'Egypt'},
    {'code': 'rsa.1', 'name': 'South African Premier Division', 'flag': '🇿🇦', 'country': 'South Africa'},
  ];

  // ─── FIFA WORLD CUP 2026 ──────────────────────────────────────────────────────
  static const Map<String, String> fifaWorldCup2026 = {
    'code': 'fifa.world',
    'name': 'FIFA World Cup 2026',
    'flag': '🏆',
    'country': 'International',
  };

  // ─── TIER 4: INTERNATIONAL (National Teams) ───────────────────────────────────
  static const List<Map<String, String>> internationalLeagues = [
    {'code': 'fifa.world',           'name': 'FIFA World Cup 2026',    'flag': '🏆', 'country': 'International'},
    {'code': 'uefa.euro',            'name': 'UEFA Euro',              'flag': '🇪🇺', 'country': 'Europe'},
    {'code': 'conmebol.america',     'name': 'Copa América',           'flag': '🌎', 'country': 'South America'},
    {'code': 'uefa.nations',         'name': 'Nations League',         'flag': '🇪🇺', 'country': 'Europe'},
    {'code': 'fifa.worldq.uefa',     'name': 'WCQ Europe',             'flag': '🌍', 'country': 'International'},
    {'code': 'fifa.worldq.conmebol', 'name': 'WCQ CONMEBOL',           'flag': '🌎', 'country': 'International'},
    {'code': 'fifa.worldq.afc',      'name': 'WCQ Asia',               'flag': '🌏', 'country': 'International'},
    {'code': 'fifa.worldq.caf',      'name': 'WCQ Africa',             'flag': '🌍', 'country': 'International'},
    {'code': 'fifa.worldq.concacaf', 'name': 'WCQ CONCACAF',           'flag': '🌎', 'country': 'International'},
    {'code': 'concacaf.gold',        'name': 'CONCACAF Gold Cup',      'flag': '🌎', 'country': 'CONCACAF'},
    {'code': 'afc.cup',              'name': 'AFC Asian Cup',          'flag': '🌏', 'country': 'Asia'},
    {'code': 'caf.nations',          'name': 'Africa Cup of Nations',  'flag': '🌍', 'country': 'Africa'},
    {'code': 'ofc.nations',          'name': 'OFC Nations Cup',        'flag': '🌏', 'country': 'Oceania'},
    {'code': 'fifa.friendly',        'name': 'International Friendly', 'flag': '🤝', 'country': 'International'},
  ];

  // ─── COMBINED GETTER ─────────────────────────────────────────────────────────
  static List<Map<String, String>> get allLeagues => [
    ...priorityLeagues,
    ...majorClubCompetitions,
    ...backgroundLeagues,
    ...internationalLeagues,
  ];

  static List<Map<String, String>> get popularLeagues => priorityLeagues;

  // ─── NATIONAL TEAM / INTERNATIONAL HELPERS ───────────────────────────────────

  static bool isNationalTeamLeague(String leagueCode) {
    if (internationalLeagues.any((l) => l['code'] == leagueCode)) return true;
    if (leagueCode.startsWith('fifa.')) return true;
    if (leagueCode.startsWith('uefa.euro')) return true;
    if (leagueCode.startsWith('conmebol.america')) return true;
    if (leagueCode.startsWith('uefa.nations')) return true;
    if (leagueCode.startsWith('afc.cup')) return true;
    if (leagueCode.startsWith('caf.nations')) return true;
    if (leagueCode.startsWith('concacaf.gold')) return true;
    if (leagueCode.startsWith('ofc.nations')) return true;

    for (final league in allLeagues) {
      if (league['code'] == leagueCode) {
        final name = league['name']!.toLowerCase();
        return name.contains('world cup') ||
            name.contains('nations league') ||
            name.contains('copa america') ||
            name.contains('euro') ||
            name.contains('afcon') ||
            name.contains('gold cup') ||
            name.contains('asian cup') ||
            name.contains('qualif') ||
            name.contains('friendly');
      }
    }
    return false;
  }

  static bool isWorldCup(String leagueCode) {
    if (leagueCode == 'fifa.world') return true;
    for (final league in allLeagues) {
      if (league['code'] == leagueCode) {
        final name = league['name']!.toLowerCase();
        return name.contains('world cup') && name.contains('fifa');
      }
    }
    return false;
  }

  static bool isWorldCupByName(String leagueName) {
    final name = leagueName.toLowerCase();
    return name.contains('world cup') ||
        (name.contains('fifa') && name.contains('world'));
  }

  // ─── INTERNATIONAL FALLBACK LEAGUES ─────────────────────────────────────────
  // These leagues are searched for both recent matches AND upcoming fixtures
  // when the primary league returns no data.
  static const List<String> internationalFallbackLeagues = [
    'fifa.world',
    'fifa.worldq.uefa',
    'fifa.worldq.conmebol',
    'fifa.worldq.afc',
    'fifa.worldq.caf',
    'fifa.worldq.concacaf',
    'uefa.nations',
    'conmebol.america',
    'concacaf.gold',
    'afc.cup',
    'caf.nations',
    'fifa.friendly',
  ];

  // ─── LEAGUE LOGO IDs (ESPN CDN) — keyed by league CODE for the standings selector ──
  static const Map<String, String> leagueLogoIds = {
    'fifa.world':           '4',
    'uefa.champions':       '2',
    'uefa.europa':          '2310',
    'uefa.conference':      '2311',
    'eng.1': '23', 'esp.1': '15', 'ita.1': '12', 'ger.1': '10', 'fra.1': '9',
    'por.1': '14', 'ned.1': '11', 'tur.1': '52', 'bel.1': '41', 'sco.1': '44',
    'aut.1': '60', 'sui.1': '62',
    'bra.1': '85', 'usa.1': '19', 'mex.1': '26', 'arg.1': '27',
    'jpn.1': '32', 'swe.1': '57', 'nor.1': '61', 'den.1': '40',
    'conmebol.libertadores': '58', 'conmebol.sudamericana': '59',
    'concacaf.champions': '18', 'afc.champions': '17', 'caf.champions': '15',
    'fifa.clubworld': '7',
    'uefa.euro': '21', 'conmebol.america': '26', 'uefa.nations': '15157',
    'fifa.worldq.uefa': '4', 'fifa.worldq.conmebol': '4', 'fifa.worldq.afc': '4',
    'fifa.worldq.caf': '4', 'fifa.worldq.concacaf': '4',
    'concacaf.gold': '18', 'afc.cup': '17', 'caf.nations': '15',
    'ofc.nations': '15', 'fifa.friendly': '55',
  };

  static String? leagueLogoUrl(String leagueCode) {
    final id = leagueLogoIds[leagueCode];
    if (id == null) return null;
    return 'https://a.espncdn.com/i/leaguelogos/soccer/500/$id.png';
  }

  // ─── SEASON OPTIONS for the standings/leaders season selector ───────────────
  // ESPN's `season` query param expects the START year of the season
  // (e.g. "2025" = the 2025-26 season). Generated dynamically so it always
  // shows the most recent 10 seasons instead of a hardcoded, aging list.
  static List<Map<String, String>> get standingsSeasons {
    final now = DateTime.now();
    // Seasons "start" around July; before that we're still mid-way through
    // last year's start-year season.
    final latestStartYear = now.month >= 7 ? now.year : now.year - 1;
    return List.generate(10, (i) {
      final startYear = latestStartYear - i;
      final startShort = (startYear % 100).toString().padLeft(2, '0');
      final endShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
      // Most recent entry shown as a plain year (reads best as the
      // default for single-year tournaments like the World Cup); older
      // entries use the familiar "23–24" split-season format.
      final label = i == 0 ? '$startYear' : '$startShort–$endShort';
      return {'value': '$startYear', 'label': label};
    });
  }

  // Add this to the existing constants.dart file

  // Add FIFA World Cup 2026 to the beginning of the leagues list for standings
  static const List<Map<String, String>> standingsLeagues = [
    {'code': 'fifa.world', 'name': 'FIFA World Cup 2026', 'flag': '🏆', 'country': 'International'},
    {'code': 'eng.1', 'name': 'Premier League', 'flag': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'country': 'England'},
    {'code': 'esp.1', 'name': 'La Liga', 'flag': '🇪🇸', 'country': 'Spain'},
    {'code': 'ita.1', 'name': 'Serie A', 'flag': '🇮🇹', 'country': 'Italy'},
    {'code': 'ger.1', 'name': 'Bundesliga', 'flag': '🇩🇪', 'country': 'Germany'},
    {'code': 'fra.1', 'name': 'Ligue 1', 'flag': '🇫🇷', 'country': 'France'},
    {'code': 'uefa.champions', 'name': 'Champions League', 'flag': '🏆', 'country': 'Europe'},
    {'code': 'uefa.europa', 'name': 'Europa League', 'flag': '🏆', 'country': 'Europe'},
    {'code': 'usa.1', 'name': 'MLS', 'flag': '🇺🇸', 'country': 'USA'},
  ];

  // ─── API-FOOTBALL (api-sports.io) — fast stat-leaders source ─────────────────
  //
  // Used ONLY for league stat leaders (top scorers / assists / yellow / red
  // cards) on the Standings screen. Everything else in the app (scores,
  // standings, lineups, news, rosters) still comes from ESPN's free endpoints.
  //
  // Free tier: 100 requests/day, 10 requests/minute. We call this at most
  // 4 times per league per cache window (goals, assists, yellow, red — or 1
  // time if using the combined approach), so this comfortably supports many
  // users sharing one key as long as results are cached (see CacheService).
  //
  // Get a free key at: https://dashboard.api-football.com/register
  // Paste it below — do NOT commit a real key to a public repo; for a
  // production app, load this from a secure config / environment instead.
  static const String apiFootballKey = 'e8415a93dada24aa95bf19f9ac21887a';
  static const String apiFootballBaseUrl = 'https://v3.football.api-sports.io';

  // ─── API-FOOTBALL MULTIPLE API KEYS ──────────────────────────────────────────
  // Free tier: 100 requests/day per key
  // Using 4 keys gives us 400 requests/day total
  static const List<String> apiFootballKeys = [
    'e8415a93dada24aa95bf19f9ac21887a',
    '98ef32914df3da8368f24c3f40dfb3d4',
    '9ab1cf2a953e5cb48d1e1e9ec18eb041',
    '40c90938040724048777a13eec78819a',
  ];

  // ─── API-FOOTBALL SEARCH ENDPOINTS ─────────────────────────────────────────────
  static const String apiFootballSearchPlayers = '$apiFootballBaseUrl/players';
  static const String apiFootballSearchTeams = '$apiFootballBaseUrl/teams';
  static const String apiFootballSearchLeagues = '$apiFootballBaseUrl/leagues';

  // Search limits
  static const int maxSearchResults = 20;

  // Maps our internal ESPN league codes -> API-Football numeric league IDs.
  // Only leagues we actually show stat leaders for need an entry; anything
  // missing here will cleanly fall back to "not available" in the UI.
  static const Map<String, int> apiFootballLeagueIds = {
    // ── International ──
    'fifa.world':        1,    // FIFA World Cup (season=2026 for this cycle)
    'uefa.euro':         4,
    'uefa.nations':      5,
    'conmebol.america':  9,
    'concacaf.gold':     22,
    'caf.nations':       6,
    'afc.cup':           19,   // AFC Asian Cup

    // ── UEFA club competitions ──
    'uefa.champions':    2,
    'uefa.europa':       3,
    'uefa.conference':   848,

    // ── Big 5 + popular European leagues ──
    'eng.1': 39,  'esp.1': 140, 'ita.1': 135, 'ger.1': 78, 'fra.1': 61,
    'por.1': 94,  'ned.1': 88,  'tur.1': 203, 'bel.1': 144, 'sco.1': 179,
    'aut.1': 218, 'sui.1': 207,

    // ── Americas ──
    'bra.1': 71, 'usa.1': 253, 'mex.1': 262, 'arg.1': 128,

    // ── Asia / Scandinavia ──
    'jpn.1': 98, 'swe.1': 113, 'nor.1': 103, 'den.1': 119,

    // ── South American club competitions ──
    'conmebol.libertadores': 13,
    'conmebol.sudamericana': 11,
  };

  /// Returns the API-Football season year to use for a given ESPN league
  /// code and a "season" string already used elsewhere in the app.
  ///
  /// Both ESPN and API-Football key split-calendar seasons (e.g. the
  /// 2025-26 Premier League season) by their START year — API-Football's
  /// own docs confirm "the 2018-2019 season in the API will be 2018".
  /// Our `standingsSeasons` values already store that START year (see
  /// above), so it can be passed straight through for every league type,
  /// club or national team, with no adjustment. (Previously this
  /// subtracted 1 for club leagues, which silently pulled stat leaders
  /// for the WRONG season on every domestic league.)
  static int apiFootballSeasonFor(String leagueCode, {String? season}) {
    final now = DateTime.now();
    if (season != null && season.isNotEmpty) {
      final parsed = int.tryParse(season);
      if (parsed != null) return parsed;
    }
    if (isNationalTeamLeague(leagueCode)) return now.year;
    // Domestic leagues: if we're in Jul-Dec, the season start year is
    // the current year; if Jan-Jun, the season started last year.
    return now.month >= 7 ? now.year : now.year - 1;
  }
}