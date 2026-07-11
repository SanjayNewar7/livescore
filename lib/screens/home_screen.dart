import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:livescore/screens/search_screen.dart';
import 'package:provider/provider.dart';

import 'package:livescore/models/game_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/screens/settings_screen.dart';
import 'package:livescore/screens/team_detail_screen.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/widgets/game_card.dart';

import '../models/team_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────

class _C {
  static const blue      = Color(0xFF1A62C8);
  static const blueMid   = Color(0xFF4A85D8);
  static const blueLight = Color(0xFFE8F0FC);
  static const blueDark  = Color(0xFF0D3F85);
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF5F7FB);
  static const border    = Color(0xFFE2E8F2);
  static const text      = Color(0xFF0F1623);
  static const muted     = Color(0xFF6B7A96);
  static const liveRed   = Color(0xFFE53535);
  static const liveRedBg = Color(0xFFFEF2F2);
  static const green     = Color(0xFF16A34A);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Improved international detection that checks multiple sources
bool _isInternational(Game g) {
  // Get all international league codes and names
  final intlCodes = AppConstants.internationalLeagues
      .map((l) => l['code']!.toLowerCase())
      .toSet();

  final intlNames = AppConstants.internationalLeagues
      .map((l) => l['name']!.toLowerCase())
      .toSet();

  final leagueLower = g.leagueName.toLowerCase();

  // Check 1: Direct match against international league codes
  for (final code in intlCodes) {
    if (leagueLower.contains(code)) {
      return true;
    }
  }

  // Check 2: Direct match against international league names
  for (final name in intlNames) {
    if (leagueLower.contains(name) || name.contains(leagueLower)) {
      return true;
    }
  }

  // Check 3: World Cup
  if (leagueLower.contains('world cup') ||
      leagueLower.contains('fifa world cup') ||
      leagueLower.contains('worldcup')) {
    return true;
  }

  // Check 4: Specific patterns
  final patterns = [
    'worldq', 'wcq', 'qualif', 'qualifying', 'qualification',
    'nations league', 'uefa nations',
    'copa america', 'copa américa',
    'euro', 'european',
    'afcon', 'africa cup', 'cup of nations',
    'gold cup', 'concacaf',
    'asian cup', 'afc cup',
    'friendly', 'international friendly',
    'eliminatorias', 'eliminatoires', 'qualifikation'
  ];

  for (final pattern in patterns) {
    if (leagueLower.contains(pattern)) {
      // Exclude Champions League, Europa League, etc.
      if (leagueLower.contains('champions') ||
          leagueLower.contains('europa') ||
          leagueLower.contains('conference') ||
          leagueLower.contains('libertadores') ||
          leagueLower.contains('sudamericana')) {
        return false;
      }
      return true;
    }
  }

  // Check 5: Check if the league is in the international leagues list by exact match
  for (final league in AppConstants.internationalLeagues) {
    if (league['name']!.toLowerCase() == leagueLower) {
      return true;
    }
  }

  return false;
}

// ─── Date Filter Model ────────────────────────────────────────────────────────

class _DateFilter {
  final String key;
  final String label;
  final String dateLabel;

  const _DateFilter(
      {required this.key, required this.label, required this.dateLabel});

  static List<_DateFilter> build() {
    final now  = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    final tom  = now.add(const Duration(days: 1));

    return [
      _DateFilter(key: 'YESTERDAY', label: 'Yesterday', dateLabel: _ordinal(yest)),
      _DateFilter(key: 'TODAY',     label: 'Today',     dateLabel: _ordinal(now)),
      _DateFilter(key: 'TOMORROW',  label: 'Tomorrow',  dateLabel: _ordinal(tom)),
      _DateFilter(key: 'CUSTOM',    label: 'Custom',    dateLabel: 'Pick date'),
    ];
  }

  static String _ordinal(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = d.day;
    String suffix;
    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1:  suffix = 'st'; break;
        case 2:  suffix = 'nd'; break;
        case 3:  suffix = 'rd'; break;
        default: suffix = 'th';
      }
    }
    return '$day$suffix ${months[d.month - 1]}';
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'TODAY';
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();

  final _filters = _DateFilter.build();

  bool _isInitialLoad = true;
  bool _hasTimeout = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    // Default to ALL LEAGUES tab
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataProgressive();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_selectedFilter == 'TODAY') {
        context.read<AppProvider>().silentRefreshToday();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _loadDataProgressive() {
    final p = context.read<AppProvider>();

    switch (_selectedFilter) {
      case 'TODAY':
        p.fetchTodaysMatches(forceRefresh: true, progressive: true);
        break;
      case 'TOMORROW':
        p.fetchTomorrowsMatches(forceRefresh: true, progressive: true);
        break;
      case 'YESTERDAY':
        p.fetchYesterdaysMatches(forceRefresh: true, progressive: true);
        break;
      case 'CUSTOM':
        break;
      default:
        p.fetchTodaysMatches(forceRefresh: true, progressive: true);
        break;
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        p.fetchAllTeams();
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        p.fetchNews();
      }
    });
  }

  void _loadData() {
    final p = context.read<AppProvider>();
    switch (_selectedFilter) {
      case 'TODAY':
        p.fetchTodaysMatches(progressive: true);
        break;
      case 'TOMORROW':
        p.fetchTomorrowsMatches(progressive: true);
        break;
      case 'YESTERDAY':
        p.fetchYesterdaysMatches(progressive: true);
        break;
      case 'CUSTOM':
        break;
      default:
        p.fetchTodaysMatches(progressive: true);
        break;
    }
  }

  List<Game> _allGamesForFilter(AppProvider p) {
    switch (_selectedFilter) {
      case 'TODAY':     return p.todaysGames;
      case 'TOMORROW':  return p.tomorrowsGames;
      case 'YESTERDAY': return p.yesterdaysGames;
      case 'CUSTOM':    return p.customGames;
      default:          return p.todaysGames;
    }
  }

  List<Game> _leagueGames(AppProvider p) {
    final all = _allGamesForFilter(p);
    return all.where((g) => !_isInternational(g)).toList();
  }

  List<Game> _internationalGames(AppProvider p) {
    final all = _allGamesForFilter(p);
    return all.where(_isInternational).toList();
  }

  Future<void> _showDatePicker(AppProvider p) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _C.blue, onPrimary: _C.white),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      final dateStr =
          '${picked.year}${picked.month.toString().padLeft(2, '0')}${picked.day.toString().padLeft(2, '0')}';
      setState(() => _selectedFilter = 'CUSTOM');
      await p.fetchGamesByDate(dateStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: _C.offWhite,
      body: Column(
        children: [
          _TopBar(
            selectedFilter: _selectedFilter,
            filters: _filters,
            tabController: _tabController,
            onFilterChanged: (filter) {
              HapticFeedback.lightImpact();
              setState(() => _selectedFilter = filter);
              if (filter == 'CUSTOM') {
                _showDatePicker(p);
              } else {
                _loadData();
              }
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 0: ALL LEAGUES
                _MatchList(
                  games: _leagueGames(p),
                  provider: p,
                  selectedFilter: _selectedFilter,
                  onRetry: () => _loadDataProgressive(),
                  onFilterToday: () {
                    setState(() => _selectedFilter = 'TODAY');
                    _loadDataProgressive();
                  },
                  onManageFavorites: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  scrollController: _scrollController,
                  emptyTitle: 'No league matches',
                  emptySubtitle: 'Check International for cups & friendlies',
                  showFavouritesStrip: true,
                  isInternationalTab: false,
                ),
                // TAB 1: INTERNATIONAL
                _MatchList(
                  games: _internationalGames(p),
                  provider: p,
                  selectedFilter: _selectedFilter,
                  onRetry: () => _loadDataProgressive(),
                  onFilterToday: () {
                    setState(() => _selectedFilter = 'TODAY');
                    _loadDataProgressive();
                  },
                  onManageFavorites: () {},
                  scrollController: _scrollController,
                  emptyTitle: 'No international matches',
                  emptySubtitle: 'No cups, qualifiers, or friendlies on this date',
                  showFavouritesStrip: false,
                  isInternationalTab: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatefulWidget {
  final String selectedFilter;
  final List<_DateFilter> filters;
  final TabController tabController;
  final ValueChanged<String> onFilterChanged;

  const _TopBar({
    required this.selectedFilter,
    required this.filters,
    required this.tabController,
    required this.onFilterChanged,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _dotVisible = true;
  late Timer _blinkTimer;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(
        const Duration(milliseconds: 600),
            (_) {
          if (mounted) setState(() => _dotVisible = !_dotVisible);
        });
  }

  @override
  void dispose() {
    _blinkTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hasLiveGames = provider.allGames.any((g) => g.status == 'STATUS_LIVE');

    return Container(
      color: _C.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Live',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                  color: _C.text,
                                ),
                              ),
                              TextSpan(
                                text: 'Score',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                  color: _C.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedDate(),
                          style: const TextStyle(
                              fontSize: 12,
                              color: _C.muted,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.search_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (hasLiveGames)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _C.liveRed,
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            opacity: _dotVisible ? 1.0 : 0.2,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text('LIVE',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = widget.filters[i];
                  final active = f.key == widget.selectedFilter;
                  return GestureDetector(
                    onTap: () => widget.onFilterChanged(f.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? _C.blue : _C.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: active ? _C.blue : _C.border, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            f.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.6,
                              color: active ? _C.white : _C.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.dateLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                              color: active
                                  ? Colors.white.withOpacity(0.8)
                                  : _C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _C.border, width: 2))),
              child: TabBar(
                controller: widget.tabController,
                indicatorColor: _C.blue,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: _C.blue,
                unselectedLabelColor: _C.muted,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.6),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.6),
                tabs: const [
                  Tab(text: 'ALL LEAGUES'),
                  Tab(text: 'INTERNATIONAL'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ─── Match List ───────────────────────────────────────────────────────────────

class _MatchList extends StatelessWidget {
  final List<Game> games;
  final AppProvider provider;
  final String selectedFilter;
  final VoidCallback onRetry;
  final VoidCallback onFilterToday;
  final VoidCallback onManageFavorites;
  final String emptyTitle;
  final String emptySubtitle;
  final ScrollController scrollController;
  final bool showFavouritesStrip;
  final bool isInternationalTab;

  const _MatchList({
    required this.games,
    required this.provider,
    required this.selectedFilter,
    required this.onRetry,
    required this.onFilterToday,
    required this.onManageFavorites,
    this.emptyTitle = '',
    this.emptySubtitle = '',
    required this.scrollController,
    this.showFavouritesStrip = true,
    this.isInternationalTab = false,
  });

  // Helper method to get fresh international games from provider
  List<Game> _getInternationalGames(AppProvider provider) {
    final allGames = _getAllGamesForFilter(provider);
    return allGames.where(_isInternational).toList();
  }

  List<Game> _getAllGamesForFilter(AppProvider provider) {
    switch (selectedFilter) {
      case 'TODAY':     return provider.todaysGames;
      case 'TOMORROW':  return provider.tomorrowsGames;
      case 'YESTERDAY': return provider.yesterdaysGames;
      case 'CUSTOM':    return provider.customGames;
      default:          return provider.todaysGames;
    }
  }

  @override
  Widget build(BuildContext context) {
    // For international tab, use fresh games directly from provider
    // Don't rely on the passed games list which might be stale
    final displayGames = isInternationalTab
        ? _getInternationalGames(provider)
        : games;

    final isInitialLoading = (provider.isLoading || provider.isLoadingPartial) &&
        displayGames.isEmpty &&
        provider.partialGames.isEmpty;

    if (isInitialLoading) {
      return _SkeletonLoader();
    }

    if (provider.error != null && displayGames.isEmpty) {
      return _ErrorState(error: provider.error!, onRetry: onRetry);
    }

    if (displayGames.isEmpty) {
      return _EmptyState(
        filter: selectedFilter,
        customTitle: emptyTitle,
        customSubtitle: emptySubtitle,
        onFilterToday: onFilterToday,
      );
    }

    final grouped = _groupByLeague(displayGames);
    final orderedKeys = _sortedLeagueKeys(grouped.keys.toList(), grouped);

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        switch (selectedFilter) {
          case 'TODAY':
            await provider.fetchTodaysMatches(forceRefresh: true, progressive: true);
            break;
          case 'TOMORROW':
            await provider.fetchTomorrowsMatches(forceRefresh: true);
            break;
          case 'YESTERDAY':
            await provider.fetchYesterdaysMatches(forceRefresh: true);
            break;
          case 'CUSTOM':
            break;
        }
      },
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          if (showFavouritesStrip)
            SliverToBoxAdapter(
              child: _FavouritesStrip(
                provider: provider,
                onManage: onManageFavorites,
              ),
            ),
          // Show loading indicator while background leagues are loading
          if (provider.isLoadingPartial && provider.partialGames.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _C.blueLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _C.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Loading more matches...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (provider.isLoading && displayGames.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: _C.blueLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 13, height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _C.blue),
                      ),
                      const SizedBox(width: 8),
                      const Text('Loading more leagues…',
                          style: TextStyle(
                              fontSize: 11,
                              color: _C.blue,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          for (final leagueName in orderedKeys) ...[
            SliverToBoxAdapter(
              child: _LeagueHeader(
                leagueName: leagueName,
                leagueFlag: grouped[leagueName]!.first.leagueFlag,
                gamesCount: grouped[leagueName]!.length,
                hasLive: grouped[leagueName]!.any((g) => g.status == 'STATUS_LIVE'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GameCard(game: grouped[leagueName]![i]),
                  ),
                  childCount: grouped[leagueName]!.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Map<String, List<Game>> _groupByLeague(List<Game> games) {
    final Map<String, List<Game>> groups = {};
    for (final g in games) {
      final name = g.leagueName.isNotEmpty ? g.leagueName : 'Other';
      groups.putIfAbsent(name, () => []).add(g);
    }
    for (final key in groups.keys) {
      groups[key]!.sort((a, b) {
        int s(Game g) {
          if (g.status == 'STATUS_LIVE') return 0;
          if (g.status == 'STATUS_SCHEDULED') return 1;
          return 2;
        }
        final so = s(a).compareTo(s(b));
        if (so != 0) return so;
        return (DateTime.tryParse(a.date) ?? DateTime.now())
            .compareTo(DateTime.tryParse(b.date) ?? DateTime.now());
      });
    }
    return groups;
  }

  List<String> _sortedLeagueKeys(
      List<String> keys,
      Map<String, List<Game>> grouped,
      ) {
    final order = AppConstants.allLeagues.map((l) => l['name']!).toList();

    int prestigeOf(String name) {
      final idx = order.indexOf(name);
      return idx == -1 ? 9999 : idx;
    }

    bool hasLive(String name) =>
        grouped[name]?.any((g) => g.status == 'STATUS_LIVE') ?? false;

    return keys
      ..sort((a, b) {
        final aLive = hasLive(a) ? 0 : 1;
        final bLive = hasLive(b) ? 0 : 1;
        if (aLive != bLive) return aLive.compareTo(bLive);
        return prestigeOf(a).compareTo(prestigeOf(b));
      });
  }
}

// ─── League Header ────────────────────────────────────────────────────────────

class _LeagueHeader extends StatelessWidget {
  final String leagueName;
  final String leagueFlag;
  final int gamesCount;
  final bool hasLive;

  const _LeagueHeader({
    required this.leagueName,
    required this.leagueFlag,
    required this.gamesCount,
    this.hasLive = false,
  });

  String? _leagueLogoUrl(String leagueName) {
    const Map<String, String> leagueLogoIds = {
      'Champions League': '2',
      'Europa League': '2310',
      'Conference League': '2311',
      'Premier League': '23',
      'La Liga': '15',
      'Serie A': '12',
      'Bundesliga': '10',
      'Ligue 1': '9',
    };
    final id = leagueLogoIds[leagueName];
    if (id == null) return null;
    return 'https://a.espncdn.com/i/leaguelogos/soccer/500/$id.png';
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = _leagueLogoUrl(leagueName);
    final isWorldCup = leagueName.toLowerCase().contains('world cup') ||
        leagueName.toLowerCase().contains('fifa world cup');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          if (isWorldCup)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.white,
                border: Border.all(color: _C.blue, width: 1),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: AppConstants.fifaWorldCup2026LogoUrlSmall,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: _C.blueLight,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _C.blue,
                    child: const Icon(
                      Icons.sports_soccer,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else if (logoUrl != null)
            SizedBox(
              width: 22, height: 22,
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Text(leagueFlag, style: const TextStyle(fontSize: 16)),
              ),
            )
          else
            Text(leagueFlag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isWorldCup ? 'FIFA World Cup 2026' : leagueName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.text,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (hasLive) ...[
            _LiveDot(),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _C.blueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$gamesCount ${gamesCount == 1 ? 'match' : 'matches'}',
              style: const TextStyle(
                fontSize: 10,
                color: _C.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> {
  bool _on = true;
  late Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(
        const Duration(milliseconds: 700),
            (_) { if (mounted) setState(() => _on = !_on); });
  }

  @override
  void dispose() { _t.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _on ? 1.0 : 0.15,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 7, height: 7,
        decoration: const BoxDecoration(color: _C.liveRed, shape: BoxShape.circle),
      ),
    );
  }
}

// ─── Favourites Strip ─────────────────────────────────────────────────────────

class _FavouritesStrip extends StatelessWidget {
  final AppProvider provider;
  final VoidCallback onManage;

  const _FavouritesStrip({required this.provider, required this.onManage});

  /// Helper method to detect the correct league code for a team
  String _detectLeagueCodeForTeam(TeamInfo team) {
    final teamName = team.displayName.toLowerCase();
    final teamAbbr = team.abbreviation.toLowerCase();
    final teamFullName = team.name.toLowerCase();

    // Combine all name variations for matching
    final combinedName = '$teamName $teamAbbr $teamFullName'.toLowerCase();

    // ─── La Liga (esp.1) ──────────────────────────────────────────────────────
    final laLigaTeams = [
      'real madrid', 'barcelona', 'atletico madrid', 'athletic bilbao',
      'real sociedad', 'real betis', 'valencia', 'sevilla', 'villareal',
      'getafe', 'espanyol', 'girona', 'osasuna', 'rayo vallecano',
      'celta vigo', 'alaves', 'mallorca', 'las palmas', 'cadiz',
      'granada', 'elche', 'almeria', 'valladolid', 'levante'
    ];
    for (final name in laLigaTeams) {
      if (combinedName.contains(name) || name.contains(combinedName.split(' ').first)) {
        return 'esp.1';
      }
    }
    if (teamAbbr == 'fcb' || teamAbbr == 'rma' || teamAbbr == 'atm' ||
        teamAbbr == 'ath' || teamAbbr == 'rso' || teamAbbr == 'bet' ||
        teamAbbr == 'val' || teamAbbr == 'sev' || teamAbbr == 'vil') {
      return 'esp.1';
    }

    // ─── Premier League (eng.1) ──────────────────────────────────────────────
    final premierLeagueTeams = [
      'manchester united', 'manchester city', 'liverpool', 'arsenal',
      'chelsea', 'tottenham', 'newcastle', 'aston villa', 'west ham',
      'everton', 'leicester', 'wolves', 'brighton', 'brentford',
      'fulham', 'crystal palace', 'nottingham', 'birmingham',
      'southampton', 'bournemouth', 'burnley', 'sheffield united',
      'luton', 'ipswich', 'leeds', 'norwich', 'watford'
    ];
    for (final name in premierLeagueTeams) {
      if (combinedName.contains(name) || name.contains(combinedName.split(' ').first)) {
        return 'eng.1';
      }
    }
    if (teamAbbr == 'mun' || teamAbbr == 'mci' || teamAbbr == 'liv' ||
        teamAbbr == 'ars' || teamAbbr == 'che' || teamAbbr == 'tot' ||
        teamAbbr == 'new' || teamAbbr == 'avl' || teamAbbr == 'whu') {
      return 'eng.1';
    }

    // ─── Serie A (ita.1) ──────────────────────────────────────────────────────
    final serieATeams = [
      'juventus', 'inter milan', 'ac milan', 'napoli', 'roma',
      'lazio', 'atalanta', 'fiorentina', 'torino', 'bologna',
      'sampdoria', 'parma', 'udinese', 'sassuolo', 'empoli',
      'lecce', 'verona', 'genoa', 'cagliari', 'salernitana'
    ];
    for (final name in serieATeams) {
      if (combinedName.contains(name) || name.contains(combinedName.split(' ').first)) {
        return 'ita.1';
      }
    }
    if (teamAbbr == 'juv' || teamAbbr == 'int' || teamAbbr == 'mil' ||
        teamAbbr == 'nap' || teamAbbr == 'rom' || teamAbbr == 'laz') {
      return 'ita.1';
    }

    // ─── Bundesliga (ger.1) ──────────────────────────────────────────────────
    final bundesligaTeams = [
      'bayern munich', 'borussia dortmund', 'rb leipzig', 'bayer leverkusen',
      'borussia monchengladbach', 'eintracht frankfurt', 'vfb stuttgart',
      'werder bremen', 'schalke', 'wolfsburg', 'hoffenheim',
      'mainz', 'augsburg', 'koln', 'freiburg', 'union berlin'
    ];
    for (final name in bundesligaTeams) {
      if (combinedName.contains(name) || name.contains(combinedName.split(' ').first)) {
        return 'ger.1';
      }
    }
    if (teamAbbr == 'bay' || teamAbbr == 'bvb' || teamAbbr == 'rbl' ||
        teamAbbr == 'b04' || teamAbbr == 'bm' || teamAbbr == 'sge') {
      return 'ger.1';
    }

    // ─── Ligue 1 (fra.1) ──────────────────────────────────────────────────────
    final ligue1Teams = [
      'paris saint germain', 'psg', 'marseille', 'monaco', 'lyon',
      'nice', 'rennes', 'lille', 'montpellier', 'strasbourg',
      'nantes', 'reims', 'toulouse', 'bordeaux', 'saint-etienne'
    ];
    for (final name in ligue1Teams) {
      if (combinedName.contains(name) || name.contains(combinedName.split(' ').first)) {
        return 'fra.1';
      }
    }
    if (teamAbbr == 'psg' || teamAbbr == 'om' || teamAbbr == 'asm' ||
        teamAbbr == 'ol' || teamAbbr == 'ogc' || teamAbbr == 'srfc') {
      return 'fra.1';
    }

    // ─── Eredivisie (ned.1) ──────────────────────────────────────────────────
    if (combinedName.contains('ajax') || combinedName.contains('psv') ||
        combinedName.contains('feyenoord') || combinedName.contains('az alkmaar') ||
        combinedName.contains('twente') || combinedName.contains('utrecht')) {
      return 'ned.1';
    }
    if (teamAbbr == 'aja' || teamAbbr == 'psv' || teamAbbr == 'fey') {
      return 'ned.1';
    }

    // ─── Primeira Liga (por.1) ──────────────────────────────────────────────
    if (combinedName.contains('benfica') || combinedName.contains('porto') ||
        combinedName.contains('sporting') || combinedName.contains('braga') ||
        combinedName.contains('guimaraes')) {
      return 'por.1';
    }
    if (teamAbbr == 'ben' || teamAbbr == 'por' || teamAbbr == 'spo') {
      return 'por.1';
    }

    // ─── MLS (usa.1) ──────────────────────────────────────────────────────────
    final mlsTeams = [
      'inter miami', 'los angeles', 'new york', 'seattle', 'atlanta',
      'toronto', 'vancouver', 'chicago', 'columbus', 'dallas',
      'houston', 'kansas', 'minnesota', 'montreal', 'nashville',
      'new england', 'philadelphia', 'portland', 'real salt lake',
      'san jose', 'st louis', 'dc united', 'austin', 'cincinnati',
      'colorado', 'orlando', 'charlotte'
    ];
    for (final name in mlsTeams) {
      if (combinedName.contains(name) || name.contains(combinedName.split(' ').first)) {
        return 'usa.1';
      }
    }

    // ─── Brasileirão (bra.1) ──────────────────────────────────────────────────
    if (combinedName.contains('flamengo') || combinedName.contains('palmeiras') ||
        combinedName.contains('santos') || combinedName.contains('corinthians') ||
        combinedName.contains('sao paulo') || combinedName.contains('gremio') ||
        combinedName.contains('internacional') || combinedName.contains('cruzeiro') ||
        combinedName.contains('fluminense') || combinedName.contains('athletico paranaense')) {
      return 'bra.1';
    }

    // ─── Liga MX (mex.1) ──────────────────────────────────────────────────────
    if (combinedName.contains('america') || combinedName.contains('chivas') ||
        combinedName.contains('guadalajara') || combinedName.contains('cruz azul') ||
        combinedName.contains('pumas') || combinedName.contains('tigres') ||
        combinedName.contains('monterrey') || combinedName.contains('toluca')) {
      return 'mex.1';
    }

    // ─── Argentine Primera (arg.1) ────────────────────────────────────────────
    if (combinedName.contains('boca juniors') || combinedName.contains('river plate') ||
        combinedName.contains('racing') || combinedName.contains('independiente') ||
        combinedName.contains('san lorenzo')) {
      return 'arg.1';
    }

    // ─── Championship (eng.2) ──────────────────────────────────────────────────
    if (combinedName.contains('west brom') || combinedName.contains('norwich') ||
        combinedName.contains('watford') || combinedName.contains('stoke') ||
        combinedName.contains('hull') || combinedName.contains('sunderland') ||
        combinedName.contains('middlesbrough') || combinedName.contains('swansea')) {
      return 'eng.2';
    }

    // ─── Turkish Super Lig (tur.1) ────────────────────────────────────────────
    if (combinedName.contains('galatasaray') || combinedName.contains('fenerbahce') ||
        combinedName.contains('besiktas') || combinedName.contains('trabzonspor')) {
      return 'tur.1';
    }

    // ─── Belgian Pro League (bel.1) ──────────────────────────────────────────
    if (combinedName.contains('anderlecht') || combinedName.contains('club brugge') ||
        combinedName.contains('standard liege') || combinedName.contains('genk')) {
      return 'bel.1';
    }

    // ─── Scottish Premiership (sco.1) ────────────────────────────────────────
    if (combinedName.contains('celtic') || combinedName.contains('rangers') ||
        combinedName.contains('aberdeen') || combinedName.contains('hearts')) {
      return 'sco.1';
    }

    // ─── Swiss Super League (sui.1) ──────────────────────────────────────────
    if (combinedName.contains('basel') || combinedName.contains('young boys') ||
        combinedName.contains('zurich') || combinedName.contains('servette')) {
      return 'sui.1';
    }

    // ─── Austrian Bundesliga (aut.1) ─────────────────────────────────────────
    if (combinedName.contains('salzburg') || combinedName.contains('rapid vienna') ||
        combinedName.contains('austria vienna') || combinedName.contains('sturm graz')) {
      return 'aut.1';
    }

    // ─── J1 League (jpn.1) ────────────────────────────────────────────────────
    if (combinedName.contains('kawasaki') || combinedName.contains('yokohama') ||
        combinedName.contains('vissel kobe') || combinedName.contains('gamba') ||
        combinedName.contains('uraWA')) {
      return 'jpn.1';
    }

    // ─── Allsvenskan (swe.1) ──────────────────────────────────────────────────
    if (combinedName.contains('malmo') || combinedName.contains('AIK') ||
        combinedName.contains('djurgarden') || combinedName.contains('hammarby')) {
      return 'swe.1';
    }

    // ─── Eliteserien (nor.1) ──────────────────────────────────────────────────
    if (combinedName.contains('bodo glimt') || combinedName.contains('molde') ||
        combinedName.contains('rosenborg') || combinedName.contains('valerenga')) {
      return 'nor.1';
    }

    // ─── Superliga (den.1) ────────────────────────────────────────────────────
    if (combinedName.contains('copenhagen') || combinedName.contains('brondby') ||
        combinedName.contains('midtjylland') || combinedName.contains('aalborg')) {
      return 'den.1';
    }

    // ─── Try to find league by checking against all league names ──────────────
    for (final league in AppConstants.allLeagues) {
      final leagueName = league['name']!.toLowerCase();
      final leagueCode = league['code']!;

      // Check if team name contains league name or vice versa
      if (teamName.contains(leagueName.split(' ').first) ||
          leagueName.contains(teamName.split(' ').first) ||
          leagueName.contains(teamAbbr)) {
        // Make sure it's not a false positive
        if (leagueCode != 'uefa.champions' && leagueCode != 'uefa.europa' &&
            leagueCode != 'uefa.conference' && leagueCode != 'fifa.world') {
          return leagueCode;
        }
      }
    }

    // ─── Default fallback ─────────────────────────────────────────────────────
    print('[Favourites] Could not detect league for team: ${team.displayName}, using eng.1');
    return 'eng.1';
  }

  @override
  Widget build(BuildContext context) {
    final favTeamIds = provider.favoriteTeamIds.take(3).toList();
    final favLeagueIds = provider.favoriteLeagueIds.take(3).toList();

    if (favTeamIds.isEmpty && favLeagueIds.isEmpty) {
      return _EmptyFavourites(onManage: onManage);
    }

    final teamCircles = favTeamIds.map((id) {
      TeamInfo? found;
      try {
        found = provider.allTeams.firstWhere((t) => t.id == id);
      } catch (_) {
        print('[Favourites] Team not found in allTeams: $id');
      }

      if (found != null) {
        final leagueCode = _detectLeagueCodeForTeam(found);
        print('[Favourites] Team: ${found.displayName}, Detected League: $leagueCode');
        return _FavCircleTeam(
          teamId: id,
          imageUrl: found.logo,
          label: found.abbreviation.isNotEmpty ? found.abbreviation : found.name,
          color: _parseColor(found.color),
          onTap: () => _navigateToTeamDetail(context, found, leagueCode),
        );
      }

      // If team not found in allTeams, try to fetch it or create a placeholder
      final espnLogoUrl = id.isNotEmpty
          ? 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png'
          : '';
      return _FavCircleTeam(
        teamId: id,
        imageUrl: espnLogoUrl,
        label: id,
        color: _C.blue,
        onTap: () => _navigateToTeamDetail(context, null, null, teamId: id),
      );
    }).toList();

    final leagueCircles = favLeagueIds.map((id) {
      Map<String, String>? league;
      try {
        league = AppConstants.allLeagues.firstWhere((l) => l['code'] == id);
      } catch (_) {
        try {
          league = AppConstants.allLeagues
              .firstWhere((l) => l['name']!.toLowerCase() == id.toLowerCase());
        } catch (_) {}
      }

      if (league != null) {
        final code = league['code']!;
        final logoUrl = 'https://a.espncdn.com/i/leaguelogos/soccer/500/${_leagueLogoId(code)}.png';
        return _FavCircleLeague(
          logoUrl: logoUrl,
          emoji: league['flag'] ?? '⚽',
          label: (league['name'] ?? id).split(' ').first,
          leagueCode: code,
        );
      }
      return _FavCircleLeague(
          logoUrl: '', emoji: '⚽', label: id, leagueCode: id);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'YOUR FAVOURITES',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _C.muted),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onManage,
                child: const Text('Manage',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...teamCircles.map((c) =>
                    Padding(
                        padding: const EdgeInsets.only(right: 14), child: c)),
                if (teamCircles.isNotEmpty && leagueCircles.isNotEmpty)
                  Container(
                    width: 1, height: 60,
                    color: _C.border,
                    margin: const EdgeInsets.only(right: 14),
                  ),
                ...leagueCircles.map((c) =>
                    Padding(
                        padding: const EdgeInsets.only(right: 14), child: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTeamDetail(BuildContext context, TeamInfo? team, String? leagueCode, {String? teamId}) {
    if (team != null) {
      final code = leagueCode ?? _detectLeagueCodeForTeam(team);
      print('[Favourites] Navigating to team: ${team.displayName}, League: $code');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamDetailScreen(
            team: team,
            leagueCode: code,
          ),
        ),
      );
    } else if (teamId != null) {
      // Try to find the team in the provider's allTeams list
      try {
        final foundTeam = provider.allTeams.firstWhere((t) => t.id == teamId);
        final code = _detectLeagueCodeForTeam(foundTeam);
        print('[Favourites] Found team by ID: ${foundTeam.displayName}, League: $code');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(
              team: foundTeam,
              leagueCode: code,
            ),
          ),
        );
      } catch (_) {
        // If team not found, create a minimal TeamInfo
        print('[Favourites] Team not found in allTeams, creating minimal with ID: $teamId');
        final minimalTeam = TeamInfo(
          id: teamId,
          name: teamId,
          displayName: teamId,
          abbreviation: teamId.length > 3 ? teamId.substring(0, 3).toUpperCase() : teamId,
          logo: 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png',
          color: '#1A62C8',
          alternateColor: '#FFFFFF',
          record: '0-0-0',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(
              team: minimalTeam,
              leagueCode: 'eng.1',
            ),
          ),
        );
      }
    }
  }

  static Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return _C.blue;
  }

  static String _leagueLogoId(String code) {
    const map = {
      'eng.1': '23',
      'esp.1': '15',
      'ita.1': '12',
      'ger.1': '10',
      'fra.1': '9',
      'uefa.champions': '2',
      'uefa.europa': '2310',
      'uefa.conference': '2311',
    };
    return map[code] ?? '23';
  }
}

// ─── Fav Circle Team (Clickable) ─────────────────────────────────────────────

class _FavCircleTeam extends StatelessWidget {
  final String teamId;
  final String imageUrl;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FavCircleTeam({
    required this.teamId,
    required this.imageUrl,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.isNotEmpty
        ? imageUrl
        : (teamId.isNotEmpty
        ? 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png'
        : '');

    final bgColor = _C.blueLight;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: _C.blue.withOpacity(0.3), width: 1.5),
            ),
            padding: const EdgeInsets.all(8),
            child: url.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, url) => const SizedBox(),
              errorWidget: (context, url, error) => Icon(
                Icons.sports_soccer_rounded,
                size: 26,
                color: _C.blue,
              ),
            )
                : const Icon(Icons.sports_soccer_rounded, size: 26, color: _C.blue),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _C.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavCircleLeague extends StatelessWidget {
  final String logoUrl;
  final String emoji;
  final String label;
  final String leagueCode;

  const _FavCircleLeague({
    required this.logoUrl,
    required this.emoji,
    required this.label,
    required this.leagueCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.blueLight,
            border: Border.all(color: _C.border, width: 1.5),
          ),
          padding: const EdgeInsets.all(8),
          child: logoUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: logoUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(),
            errorWidget: (context, url, error) =>
                Text(emoji, style: const TextStyle(fontSize: 22)),
          )
              : Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _C.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _EmptyFavourites extends StatelessWidget {
  final VoidCallback onManage;
  const _EmptyFavourites({required this.onManage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _C.blue, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Favourites',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Follow teams & leagues to see them here',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: onManage,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8),
              ),
              child: const Text('SET UP'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _C.offWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _C.border),
        ),
        child: Icon(icon, size: 18, color: _C.muted),
      ),
    );
  }
}

class _SkeletonLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 8,
      itemBuilder: (_, i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i % 2 == 0)
            Container(
              height: 16, width: 130,
              margin: const EdgeInsets.only(bottom: 8, top: 14),
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _C.border,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: _C.liveRedBg,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.error_outline_rounded,
                  size: 32, color: _C.liveRed),
            ),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _C.text)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _C.muted)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.blue,
                foregroundColor: _C.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1),
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final String customTitle;
  final String customSubtitle;
  final VoidCallback onFilterToday;

  const _EmptyState({
    required this.filter,
    required this.customTitle,
    required this.customSubtitle,
    required this.onFilterToday,
  });

  String get _title {
    if (customTitle.isNotEmpty) return customTitle;
    switch (filter) {
      case 'TODAY':     return 'No matches today';
      case 'TOMORROW':  return 'No matches tomorrow';
      case 'YESTERDAY': return 'No matches yesterday';
      default:          return 'No matches found';
    }
  }

  String get _subtitle {
    if (customSubtitle.isNotEmpty) return customSubtitle;
    switch (filter) {
      case 'TODAY':     return 'Check back later for live matches';
      case 'TOMORROW':  return 'Check back tomorrow for matches';
      case 'YESTERDAY': return 'No matches were played yesterday';
      default:          return 'Try a different date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: _C.blueLight,
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.sports_soccer_rounded,
                  size: 36, color: _C.blue),
            ),
            const SizedBox(height: 16),
            Text(_title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _C.text)),
            const SizedBox(height: 8),
            Text(_subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _C.muted, height: 1.5)),
            if (filter != 'TODAY') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onFilterToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: _C.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1),
                ),
                child: const Text("VIEW TODAY'S MATCHES"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}