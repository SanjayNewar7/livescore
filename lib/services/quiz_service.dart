// lib/services/quiz_service.dart
//
// Generates one 10-question set per day, sourced from data ESPN's
// APIs already feed into AppProvider (standings, finished results,
// team info, news headlines). The set is generated once and then
// persisted locally so it does not change if the user leaves and
// comes back later the same day. A small, fixed pool of evergreen
// football-rules questions is used only to top up the set on days
// there isn't enough live ESPN data loaded yet (e.g. first launch,
// no connection) - never as a replacement for it.
//
// One correct answer = one ball collected. Balls persist across days.

import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:livescore/models/quiz_model.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/utils/helpers.dart';

class QuizService {
  static const String _dailyBoxName = 'quiz_daily_box';
  static const String _statsBoxName = 'quiz_stats_box';
  static const int questionsPerDay = 10;

  late Box _dailyBox;
  late Box _statsBox;
  bool _initialized = false;
  Future<void>? _initFuture;

  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    await _initFuture;
  }

  Future<void> _doInit() async {
    _dailyBox = await Hive.openBox(_dailyBoxName);
    _statsBox = await Hive.openBox(_statsBoxName);

    if (!_statsBox.containsKey('stats')) {
      await _statsBox.put('stats', QuizStats.empty.toJson());
    }

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await init();
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  QuizStats get stats {
    if (!_initialized) {
      return QuizStats.empty;
    }
    return QuizStats.fromJson(_statsBox.get('stats') as Map?);
  }

  Future<void> _saveStats(QuizStats stats) async {
    await _ensureInitialized();
    await _statsBox.put('stats', stats.toJson());
  }

  Future<QuizDailySet> getTodayQuiz(AppProvider provider) async {
    await _ensureInitialized();

    final cached = _dailyBox.get(_todayKey);
    if (cached != null) {
      return QuizDailySet.fromJson(Map<String, dynamic>.from(cached as Map));
    }

    final questions = _generateQuestions(provider);
    final freshSet = QuizDailySet(
      date: _todayKey,
      questions: questions,
      answers: List<int?>.filled(questions.length, null),
      completed: false,
    );
    await _dailyBox.put(_todayKey, freshSet.toJson());
    return freshSet;
  }

  Future<QuizDailySet> submitAnswer({
    required QuizDailySet quiz,
    required int questionIndex,
    required int selectedOption,
  }) async {
    if (questionIndex < 0 || questionIndex >= quiz.questions.length) return quiz;
    if (quiz.answers[questionIndex] != null) return quiz;

    final newAnswers = List<int?>.from(quiz.answers);
    newAnswers[questionIndex] = selectedOption;

    final isCorrect = selectedOption == quiz.questions[questionIndex].correctIndex;
    final currentStats = stats;
    var updatedStats = currentStats.copyWith(
      totalAnswered: currentStats.totalAnswered + 1,
      totalCorrect: isCorrect ? currentStats.totalCorrect + 1 : currentStats.totalCorrect,
      totalBalls: isCorrect ? currentStats.totalBalls + 1 : currentStats.totalBalls,
    );

    final justCompleted = newAnswers.every((a) => a != null);
    var updatedSet = quiz.copyWith(answers: newAnswers, completed: justCompleted);

    if (justCompleted && !quiz.completed) {
      updatedStats = _applyCompletionStreak(updatedStats);
    }

    await _dailyBox.put(_todayKey, updatedSet.toJson());
    await _saveStats(updatedStats);
    return updatedSet;
  }

  QuizStats _applyCompletionStreak(QuizStats current) {
    final today = DateTime.now();
    final yesterday = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));
    final wasYesterday = current.lastCompletedDate == yesterday;
    final newStreak = wasYesterday ? current.currentStreak + 1 : 1;
    return current.copyWith(
      quizzesCompleted: current.quizzesCompleted + 1,
      currentStreak: newStreak,
      bestStreak: max(current.bestStreak, newStreak),
      lastCompletedDate: _todayKey,
    );
  }

  // ─── QUESTION GENERATION ────────────────────────────────────────────────

  List<QuizQuestion> _generateQuestions(AppProvider provider) {
    final seed = int.parse(_todayKey.replaceAll('-', ''));
    final random = Random(seed);

    final pool = <QuizQuestion>[];
    pool.addAll(_standingsQuestions(provider));
    pool.addAll(_resultQuestions(provider));
    pool.addAll(_teamTriviaQuestions(provider));
    pool.addAll(_newsQuestions(provider));
    pool.addAll(_lawsOfTheGameQuestions);
    pool.addAll(_worldCupQuestions);
    pool.addAll(_premierLeagueQuestions);
    pool.addAll(_laLigaQuestions);
    pool.addAll(_serieAQuestions);
    pool.addAll(_bundesligaQuestions);
    pool.addAll(_ligue1Questions);
    pool.addAll(_championsLeagueQuestions);
    pool.addAll(_europaLeagueQuestions);
    pool.addAll(_fullFormQuestions);
    pool.addAll(_marketValueQuestions);
    pool.addAll(_stadiumQuestions);
    pool.addAll(_transferQuestions);
    pool.addAll(_awardQuestions);
    pool.addAll(_recordQuestions);
    pool.addAll(_refereeQuestions);
    pool.addAll(_clubTriviaQuestions);
    pool.addAll(_playerTriviaQuestions);

    pool.shuffle(random);

    final selected = <QuizQuestion>[];
    final usedQuestionText = <String>{};
    for (final q in pool) {
      if (selected.length >= questionsPerDay) break;
      if (usedQuestionText.contains(q.question)) continue;
      usedQuestionText.add(q.question);
      selected.add(q);
    }

    if (selected.length < questionsPerDay) {
      final fallback = List<QuizQuestion>.from(_fallbackQuestions)..shuffle(random);
      for (final q in fallback) {
        if (selected.length >= questionsPerDay) break;
        if (usedQuestionText.contains(q.question)) continue;
        usedQuestionText.add(q.question);
        selected.add(q);
      }
    }

    final finalQuestions = <QuizQuestion>[];
    for (final q in selected) {
      finalQuestions.add(_shuffleOptions(q, random));
    }
    return finalQuestions;
  }

  QuizQuestion _shuffleOptions(QuizQuestion q, Random random) {
    final correctAnswer = q.options[q.correctIndex];
    final shuffled = List<String>.from(q.options)..shuffle(random);
    return QuizQuestion(
      id: q.id,
      question: q.question,
      options: shuffled,
      correctIndex: shuffled.indexOf(correctAnswer),
      category: q.category,
    );
  }

  List<QuizQuestion> _standingsQuestions(AppProvider provider) {
    final standings = List<Standing>.from(provider.standings)
      ..sort((a, b) => a.rank.compareTo(b.rank));
    if (standings.length < 4) return [];

    final leagueName = Helpers.getLeagueName(provider.currentLeagueCode);
    final questions = <QuizQuestion>[];

    final leader = standings.first;
    final distractors = standings.skip(1).take(6).toList()..shuffle(Random(1));
    final leaderOptions = [
      leader.team.displayName,
      ...distractors.take(3).map((s) => s.team.displayName),
    ];
    if (leaderOptions.toSet().length == 4) {
      questions.add(QuizQuestion(
        id: 'standings_leader_${provider.currentLeagueCode}',
        question: 'Which club currently tops the $leagueName table?',
        options: leaderOptions,
        correctIndex: 0,
        category: 'standings',
      ));
    }

    if (standings.length >= 6) {
      final subject = standings[standings.length ~/ 2];
      final otherPoints = standings
          .where((s) => s.team.id != subject.team.id && s.points != null)
          .map((s) => s.points!)
          .toSet()
          .toList()
        ..shuffle(Random(2));
      if (subject.points != null && otherPoints.length >= 3) {
        final options = <String>{subject.points.toString()};
        for (final p in otherPoints) {
          if (options.length >= 4) break;
          options.add(p.toString());
        }
        if (options.length == 4) {
          final optionsList = options.toList();
          questions.add(QuizQuestion(
            id: 'standings_points_${subject.team.id}',
            question: 'How many points does ${subject.team.displayName} currently have in the $leagueName?',
            options: optionsList,
            correctIndex: optionsList.indexOf(subject.points.toString()),
            category: 'standings',
          ));
        }
      }
    }

    final withGd = standings.where((s) => s.goalDifference != null).toList();
    if (withGd.length >= 4) {
      final best = withGd.reduce((a, b) => (a.goalDifference! > b.goalDifference!) ? a : b);
      final others = withGd.where((s) => s.team.id != best.team.id).toList()..shuffle(Random(3));
      final options = [best.team.displayName, ...others.take(3).map((s) => s.team.displayName)];
      if (options.toSet().length == 4) {
        questions.add(QuizQuestion(
          id: 'standings_gd_${provider.currentLeagueCode}',
          question: 'Which club has the best goal difference in the $leagueName right now?',
          options: options,
          correctIndex: 0,
          category: 'standings',
        ));
      }
    }

    return questions;
  }

  List<QuizQuestion> _resultQuestions(AppProvider provider) {
    final finished = <Game>[
      ...provider.yesterdaysGames,
      ...provider.finishedGames,
    ].where((g) => g.status == 'STATUS_FINAL').toList();

    if (finished.isEmpty) return [];

    final questions = <QuizQuestion>[];
    final seen = <String>{};

    for (final game in finished) {
      if (questions.length >= 6) break;
      final key = '${game.homeTeam.id}_${game.awayTeam.id}_${game.date}';
      if (seen.contains(key)) continue;
      seen.add(key);

      final homeScore = int.tryParse(game.homeScore) ?? 0;
      final awayScore = int.tryParse(game.awayScore) ?? 0;
      final String winner;
      if (homeScore > awayScore) {
        winner = game.homeTeam.displayName;
      } else if (awayScore > homeScore) {
        winner = game.awayTeam.displayName;
      } else {
        winner = 'Draw';
      }

      final options = <String>{
        winner,
        game.homeTeam.displayName,
        game.awayTeam.displayName,
        'Draw',
      }.toList();
      if (options.length < 3) continue;
      while (options.length < 4) {
        options.add('Match postponed');
      }

      questions.add(QuizQuestion(
        id: 'result_${game.id}',
        question: 'Who won the match between ${game.homeTeam.displayName} and ${game.awayTeam.displayName}?',
        options: options.take(4).toList(),
        correctIndex: options.indexOf(winner),
        category: 'results',
      ));
    }

    return questions;
  }

  List<QuizQuestion> _teamTriviaQuestions(AppProvider provider) {
    final teams = List<TeamInfo>.from(provider.allTeams);
    if (teams.length < 4) return [];

    final questions = <QuizQuestion>[];

    final withVenue = teams.where((t) => t.venueName != null && t.venueName!.isNotEmpty).toList();
    if (withVenue.length >= 4) {
      withVenue.shuffle(Random(4));
      final subject = withVenue.first;
      final others = withVenue.skip(1).take(3).toList();
      final options = [subject.venueName!, ...others.map((t) => t.venueName!)];
      if (options.toSet().length == 4) {
        questions.add(QuizQuestion(
          id: 'venue_${subject.id}',
          question: 'What is the home stadium of ${subject.displayName}?',
          options: options,
          correctIndex: 0,
          category: 'trivia',
        ));
      }
    }

    final withCoach = teams.where((t) => t.coach != null && t.coach!.isNotEmpty).toList();
    if (withCoach.length >= 4) {
      withCoach.shuffle(Random(5));
      final subject = withCoach.first;
      final others = withCoach.skip(1).take(3).toList();
      final options = [subject.coach!, ...others.map((t) => t.coach!)];
      if (options.toSet().length == 4) {
        questions.add(QuizQuestion(
          id: 'coach_${subject.id}',
          question: 'Who is the current head coach of ${subject.displayName}?',
          options: options,
          correctIndex: 0,
          category: 'trivia',
        ));
      }
    }

    return questions;
  }

  List<QuizQuestion> _newsQuestions(AppProvider provider) {
    final headlines = provider.news
        .map((a) => a.headline.trim())
        .where((h) => h.isNotEmpty && h.length <= 90)
        .toSet()
        .toList();
    if (headlines.length < 4) return [];

    headlines.shuffle(Random(6));
    final questions = <QuizQuestion>[];
    final rounds = min(2, headlines.length ~/ 4);
    for (int i = 0; i < rounds; i++) {
      final slice = headlines.skip(i * 4).take(4).toList();
      if (slice.length < 4) break;
      final real = slice.first;
      questions.add(QuizQuestion(
        id: 'news_$i',
        question: 'Which of these headlines was actually published in today\'s football news?',
        options: slice,
        correctIndex: 0,
        category: 'news',
      ));
    }
    return questions;
  }

  // ─── PREMIER LEAGUE QUESTIONS ──────────────────────────────────────────

  static final List<QuizQuestion> _premierLeagueQuestions = [
    const QuizQuestion(
      id: 'pl_most_titles',
      question: 'Which club has won the most Premier League titles?',
      options: ['Manchester United', 'Liverpool', 'Arsenal', 'Chelsea'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_invincibles',
      question: 'Which club went undefeated in the 2003-04 Premier League season?',
      options: ['Arsenal', 'Manchester United', 'Chelsea', 'Liverpool'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_top_scorer_all_time',
      question: 'Who is the all-time top scorer in Premier League history?',
      options: ['Alan Shearer', 'Wayne Rooney', 'Harry Kane', 'Sergio Agüero'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_most_assists',
      question: 'Who has the most assists in Premier League history?',
      options: ['Ryan Giggs', 'Frank Lampard', 'Cesc Fàbregas', 'David Beckham'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_first_winner',
      question: 'Which club won the first Premier League title in 1992-93?',
      options: ['Manchester United', 'Liverpool', 'Arsenal', 'Blackburn Rovers'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_100_points',
      question: 'Which club was the first to reach 100 points in a Premier League season?',
      options: ['Manchester City', 'Liverpool', 'Chelsea', 'Manchester United'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_goal_in_all_38',
      question: 'Who scored in every single Premier League game of a season?',
      options: ['Robin van Persie', 'Thierry Henry', 'Didier Drogba', 'Luis Suárez'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_most_wins',
      question: 'Which club holds the record for the most wins in a Premier League season?',
      options: ['Manchester City', 'Liverpool', 'Chelsea', 'Manchester United'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_longest_unbeaten',
      question: 'Which club holds the record for the longest unbeaten run in Premier League history?',
      options: ['Arsenal', 'Liverpool', 'Manchester United', 'Chelsea'],
      correctIndex: 0,
      category: 'premier_league',
    ),
    const QuizQuestion(
      id: 'pl_foreign_mvp',
      question: 'Who was the first foreign player to win the Premier League Golden Boot?',
      options: ['Eric Cantona', 'Jurgen Klinsmann', 'Gianluca Vialli', 'Ruud Gullit'],
      correctIndex: 1,
      category: 'premier_league',
    ),
  ];

  // ─── LA LIGA QUESTIONS ──────────────────────────────────────────────────

  static final List<QuizQuestion> _laLigaQuestions = [
    const QuizQuestion(
      id: 'laliga_most_titles',
      question: 'Which club has won the most La Liga titles?',
      options: ['Real Madrid', 'Barcelona', 'Atletico Madrid', 'Athletic Bilbao'],
      correctIndex: 0,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_top_scorer_all_time',
      question: 'Who is the all-time top scorer in La Liga history?',
      options: ['Lionel Messi', 'Cristiano Ronaldo', 'Telmo Zarra', 'Karim Benzema'],
      correctIndex: 0,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_most_goals_season',
      question: 'Who holds the record for most goals in a single La Liga season?',
      options: ['Lionel Messi', 'Cristiano Ronaldo', 'Robert Lewandowski', 'Karim Benzema'],
      correctIndex: 1,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_oldest_derby',
      question: 'Which rivalry is the oldest in La Liga history?',
      options: ['Real Madrid vs Barcelona', 'Real Madrid vs Atletico', 'Real Sociedad vs Athletic', 'Sevilla vs Betis'],
      correctIndex: 2,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_100_points',
      question: 'Which club was the first to reach 100 points in La Liga?',
      options: ['Real Madrid', 'Barcelona', 'Atletico Madrid', 'Valencia'],
      correctIndex: 0,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_five_times',
      question: 'Who is the only player to have won 5 La Liga Golden Boots?',
      options: ['Lionel Messi', 'Cristiano Ronaldo', 'Raul Gonzalez', 'Iker Casillas'],
      correctIndex: 0,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_double',
      question: 'How many clubs have completed the La Liga & Copa del Rey double?',
      options: ['8', '10', '12', '14'],
      correctIndex: 0,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_most_clean_sheets',
      question: 'Who holds the record for most clean sheets in a single La Liga season?',
      options: ['Iker Casillas', 'Victor Valdes', 'Keylor Navas', 'Jan Oblak'],
      correctIndex: 3,
      category: 'la_liga',
    ),
    const QuizQuestion(
      id: 'laliga_foreign_hat_trick',
      question: 'Who was the first player to score a hat-trick on their La Liga debut?',
      options: ['Hugo Sanchez', 'Ronaldo Nazario', 'Alfredo Di Stefano', 'Karim Benzema'],
      correctIndex: 0,
      category: 'la_liga',
    ),
  ];

  // ─── SERIE A QUESTIONS ──────────────────────────────────────────────────

  static final List<QuizQuestion> _serieAQuestions = [
    const QuizQuestion(
      id: 'seriea_most_titles',
      question: 'Which club has won the most Serie A titles?',
      options: ['Juventus', 'AC Milan', 'Inter Milan', 'Roma'],
      correctIndex: 0,
      category: 'serie_a',
    ),
    const QuizQuestion(
      id: 'seriea_top_scorer_all_time',
      question: 'Who is the all-time top scorer in Serie A?',
      options: ['Silvio Piola', 'Francesco Totti', 'Giuseppe Meazza', 'Roberto Baggio'],
      correctIndex: 0,
      category: 'serie_a',
    ),
    const QuizQuestion(
      id: 'seriea_invincible',
      question: 'Which club went undefeated to win Serie A?',
      options: ['AC Milan', 'Juventus', 'Inter Milan', 'Roma'],
      correctIndex: 0,
      category: 'serie_a',
    ),
    const QuizQuestion(
      id: 'seriea_most_consecutive',
      question: 'Which club won the most consecutive Serie A titles?',
      options: ['Juventus', 'Inter Milan', 'AC Milan', 'Torino'],
      correctIndex: 0,
      category: 'serie_a',
    ),
    const QuizQuestion(
      id: 'seriea_goal_per_season',
      question: 'Who scored the most goals in a single Serie A season?',
      options: ['Gunnar Nordahl', 'Luca Toni', 'Gonzalo Higuain', 'Cristiano Ronaldo'],
      correctIndex: 0,
      category: 'serie_a',
    ),
    const QuizQuestion(
      id: 'seriea_most_appearances',
      question: 'Who holds the record for most Serie A appearances?',
      options: ['Gianluigi Buffon', 'Paolo Maldini', 'Francesco Totti', 'Javier Zanetti'],
      correctIndex: 0,
      category: 'serie_a',
    ),
    const QuizQuestion(
      id: 'seriea_derby_name',
      question: 'What is the Derby della Madonnina?',
      options: ['AC Milan vs Inter', 'Juventus vs Torino', 'Roma vs Lazio', 'Genoa vs Sampdoria'],
      correctIndex: 0,
      category: 'serie_a',
    ),
  ];

  // ─── BUNDESLIGA QUESTIONS ──────────────────────────────────────────────

  static final List<QuizQuestion> _bundesligaQuestions = [
    const QuizQuestion(
      id: 'bundesliga_most_titles',
      question: 'Which club has won the most Bundesliga titles?',
      options: ['Bayern Munich', 'Borussia Dortmund', 'Borussia Mönchengladbach', 'Werder Bremen'],
      correctIndex: 0,
      category: 'bundesliga',
    ),
    const QuizQuestion(
      id: 'bundesliga_top_scorer_all_time',
      question: 'Who is the all-time top scorer in Bundesliga history?',
      options: ['Gerd Müller', 'Robert Lewandowski', 'Klaus Fischer', 'Lothar Matthäus'],
      correctIndex: 0,
      category: 'bundesliga',
    ),
    const QuizQuestion(
      id: 'bundesliga_most_goals_season',
      question: 'Who holds the record for most goals in a single Bundesliga season?',
      options: ['Robert Lewandowski', 'Gerd Müller', 'Luca Toni', 'Erling Haaland'],
      correctIndex: 1,
      category: 'bundesliga',
    ),
    const QuizQuestion(
      id: 'bundesliga_youngest_goalscorer',
      question: 'Who is the youngest goalscorer in Bundesliga history?',
      options: ['Youssoufa Moukoko', 'Jamal Musiala', 'Florian Wirtz', 'Kai Havertz'],
      correctIndex: 0,
      category: 'bundesliga',
    ),
    const QuizQuestion(
      id: 'bundesliga_consecutive',
      question: 'How many consecutive Bundesliga titles did Bayern Munich win (2013-2023)?',
      options: ['10', '11', '9', '12'],
      correctIndex: 1,
      category: 'bundesliga',
    ),
    const QuizQuestion(
      id: 'bundesliga_founding',
      question: 'In which year was the Bundesliga founded?',
      options: ['1963', '1953', '1973', '1968'],
      correctIndex: 0,
      category: 'bundesliga',
    ),
    const QuizQuestion(
      id: 'bundesliga_first_winner',
      question: 'Which club won the first Bundesliga title?',
      options: ['Bayern Munich', 'FC Köln', 'Borussia Dortmund', 'Hamburger SV'],
      correctIndex: 1,
      category: 'bundesliga',
    ),
  ];

  // ─── LIGUE 1 QUESTIONS ──────────────────────────────────────────────────

  static final List<QuizQuestion> _ligue1Questions = [
    const QuizQuestion(
      id: 'ligue1_most_titles',
      question: 'Which club has won the most Ligue 1 titles?',
      options: ['Paris Saint-Germain', 'Saint-Étienne', 'Marseille', 'Lyon'],
      correctIndex: 1,
      category: 'ligue_1',
    ),
    const QuizQuestion(
      id: 'ligue1_top_scorer_all_time',
      question: 'Who is the all-time top scorer in Ligue 1?',
      options: ['Delio Onnis', 'Bernard Lacombe', 'Jean-Pierre Papin', 'Kylian Mbappé'],
      correctIndex: 0,
      category: 'ligue_1',
    ),
    const QuizQuestion(
      id: 'ligue1_seven_titles',
      question: 'Which club won 7 consecutive Ligue 1 titles between 2002-2008?',
      options: ['Lyon', 'PSG', 'Marseille', 'Bordeaux'],
      correctIndex: 0,
      category: 'ligue_1',
    ),
    const QuizQuestion(
      id: 'ligue1_all_time_goals',
      question: 'Who holds the record for most goals in a single Ligue 1 season?',
      options: ['Kylian Mbappé', 'Josip Skoblar', 'Delio Onnis', 'Jean-Pierre Papin'],
      correctIndex: 1,
      category: 'ligue_1',
    ),
  ];

  // ─── CHAMPIONS LEAGUE QUESTIONS ─────────────────────────────────────────

  static final List<QuizQuestion> _championsLeagueQuestions = [
    const QuizQuestion(
      id: 'ucl_most_titles',
      question: 'Which club has won the most Champions League titles?',
      options: ['Real Madrid', 'AC Milan', 'Bayern Munich', 'Liverpool'],
      correctIndex: 0,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_most_goals_all_time',
      question: 'Who is the all-time top scorer in Champions League history?',
      options: ['Cristiano Ronaldo', 'Lionel Messi', 'Robert Lewandowski', 'Karim Benzema'],
      correctIndex: 0,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_most_goals_season',
      question: 'Who holds the record for most goals in a single Champions League season?',
      options: ['Cristiano Ronaldo', 'Lionel Messi', 'Robert Lewandowski', 'Karim Benzema'],
      correctIndex: 0,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_most_assists_all_time',
      question: 'Who has the most assists in Champions League history?',
      options: ['Cristiano Ronaldo', 'Lionel Messi', 'Ryan Giggs', 'David Beckham'],
      correctIndex: 2,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_most_appearances',
      question: 'Who has the most appearances in Champions League history?',
      options: ['Iker Casillas', 'Cristiano Ronaldo', 'Xavi Hernandez', 'Lionel Messi'],
      correctIndex: 0,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_youngest_goalscorer',
      question: 'Who is the youngest goalscorer in Champions League history?',
      options: ['Youssoufa Moukoko', 'Pau Cubarsí', 'Ansu Fati', 'Gavi'],
      correctIndex: 0,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_three_peat',
      question: 'Which club was the first to win 3 consecutive Champions League titles?',
      options: ['Real Madrid', 'Bayern Munich', 'Ajax', 'AC Milan'],
      correctIndex: 2,
      category: 'champions_league',
    ),
    const QuizQuestion(
      id: 'ucl_final_venue',
      question: 'Which stadium has hosted the most Champions League finals?',
      options: ['Wembley Stadium', 'San Siro', 'Santiago Bernabéu', 'Allianz Arena'],
      correctIndex: 0,
      category: 'champions_league',
    ),
  ];

  // ─── EUROPA LEAGUE QUESTIONS ────────────────────────────────────────────

  static final List<QuizQuestion> _europaLeagueQuestions = [
    const QuizQuestion(
      id: 'uel_most_titles',
      question: 'Which club has won the most Europa League titles?',
      options: ['Sevilla', 'Liverpool', 'Juventus', 'Atletico Madrid'],
      correctIndex: 0,
      category: 'europa_league',
    ),
    const QuizQuestion(
      id: 'uel_top_scorer_all_time',
      question: 'Who is the all-time top scorer in Europa League history?',
      options: ['Henrik Larsson', 'Radamel Falcao', 'Aritz Aduriz', 'Claudio Pizarro'],
      correctIndex: 0,
      category: 'europa_league',
    ),
    const QuizQuestion(
      id: 'uel_most_consecutive',
      question: 'Which club won three consecutive Europa League titles?',
      options: ['Sevilla', 'Atletico Madrid', 'Liverpool', 'Chelsea'],
      correctIndex: 0,
      category: 'europa_league',
    ),
    const QuizQuestion(
      id: 'uel_most_appearances',
      question: 'Which player has made the most appearances in Europa League history?',
      options: ['Joaquín', 'Darijo Srna', 'Giuseppe Bergomi', 'Wesley Sneijder'],
      correctIndex: 0,
      category: 'europa_league',
    ),
  ];

  // ─── FULL FORM QUESTIONS ────────────────────────────────────────────────

  static final List<QuizQuestion> _fullFormQuestions = [
    const QuizQuestion(
      id: 'ff_var',
      question: 'What does VAR stand for in football?',
      options: ['Video Assistant Referee', 'Visual Action Review', 'Virtual Assistant Referee', 'Video Automated Review'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_ufa',
      question: 'What does UEFA stand for?',
      options: ['Union of European Football Associations', 'United European Football Alliance', 'Union of European Federations for Athletics', 'United European Futsal Association'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_fifa',
      question: 'What does FIFA stand for?',
      options: ['Fédération Internationale de Football Association', 'Football International Federation Association', 'Fédération of International Football Associations', 'Football International Association of Federations'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_conmebol',
      question: 'What does CONMEBOL stand for?',
      options: ['Confederación Sudamericana de Fútbol', 'Confederation of South American Football', 'South American Football Confederation', 'Confederación de Fútbol Sudamericano'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_afc',
      question: 'What does AFC stand for in football?',
      options: ['Asian Football Confederation', 'African Football Confederation', 'American Football Conference', 'Australian Football Council'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_caf',
      question: 'What does CAF stand for in football?',
      options: ['Confederation of African Football', 'Central African Football', 'Council of African Football', 'Confederation of Asian Football'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_ofc',
      question: 'What does OFC stand for in football?',
      options: ['Oceania Football Confederation', 'Oceanic Football Council', 'Organisation of Football Confederations', 'Official Football Committee'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_mvp',
      question: 'What does MVP stand for?',
      options: ['Most Valuable Player', 'Most Versatile Player', 'Most Valued Player', 'Most Valuable Performer'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_pfa',
      question: 'What does PFA stand for?',
      options: ['Professional Footballers Association', 'Premier Football Association', 'Professional Football Alliance', 'Player Football Association'],
      correctIndex: 0,
      category: 'full_forms',
    ),
    const QuizQuestion(
      id: 'ff_mls',
      question: 'What does MLS stand for?',
      options: ['Major League Soccer', 'Minor League Soccer', 'Major League Sports', 'Men\'s League Soccer'],
      correctIndex: 0,
      category: 'full_forms',
    ),
  ];

  // ─── MARKET VALUE QUESTIONS ─────────────────────────────────────────────

  static final List<QuizQuestion> _marketValueQuestions = [
    const QuizQuestion(
      id: 'mv_highest_value',
      question: 'Which player has the highest current market value?',
      options: ['Erling Haaland', 'Kylian Mbappé', 'Jude Bellingham', 'Vinícius Júnior'],
      correctIndex: 0,
      category: 'market_value',
    ),
    const QuizQuestion(
      id: 'mv_most_expensive_transfer',
      question: 'Which transfer is the most expensive in football history?',
      options: ['Neymar to PSG', 'Kylian Mbappé to PSG', 'Philippe Coutinho to Barcelona', 'Ousmane Dembélé to Barcelona'],
      correctIndex: 0,
      category: 'market_value',
    ),
    const QuizQuestion(
      id: 'mv_most_expensive_teenager',
      question: 'Which teenager was transferred for the highest fee?',
      options: ['Jude Bellingham', 'Eduardo Camavinga', 'Lamine Yamal', 'Gavi'],
      correctIndex: 0,
      category: 'market_value',
    ),
    const QuizQuestion(
      id: 'mv_highest_club_value',
      question: 'Which club has the highest squad market value?',
      options: ['Manchester City', 'Real Madrid', 'PSG', 'Arsenal'],
      correctIndex: 0,
      category: 'market_value',
    ),
  ];

  // ─── STADIUM QUESTIONS ──────────────────────────────────────────────────

  static final List<QuizQuestion> _stadiumQuestions = [
    const QuizQuestion(
      id: 'stadium_largest',
      question: 'Which is the largest football stadium in the world?',
      options: ['Rungrado 1st of May Stadium', 'Camp Nou', 'Wembley Stadium', 'Santiago Bernabéu'],
      correctIndex: 0,
      category: 'stadiums',
    ),
    const QuizQuestion(
      id: 'stadium_camp_nou',
      question: 'What is the capacity of Camp Nou?',
      options: ['99,354', '80,000', '75,000', '65,000'],
      correctIndex: 0,
      category: 'stadiums',
    ),
    const QuizQuestion(
      id: 'stadium_oldest',
      question: 'Which is the oldest football stadium still in use?',
      options: ['Bramall Lane', 'Deepdale', 'Turf Moor', 'Goodison Park'],
      correctIndex: 0,
      category: 'stadiums',
    ),
    const QuizQuestion(
      id: 'stadium_wembley',
      question: 'Where is Wembley Stadium located?',
      options: ['London', 'Manchester', 'Birmingham', 'Liverpool'],
      correctIndex: 0,
      category: 'stadiums',
    ),
    const QuizQuestion(
      id: 'stadium_santiago',
      question: 'Which club plays at the Santiago Bernabéu?',
      options: ['Real Madrid', 'Atletico Madrid', 'Barcelona', 'Valencia'],
      correctIndex: 0,
      category: 'stadiums',
    ),
  ];

  // ─── TRANSFER QUESTIONS ─────────────────────────────────────────────────

  static final List<QuizQuestion> _transferQuestions = [
    const QuizQuestion(
      id: 'transfer_window_summer',
      question: 'When does the summer transfer window close in most European leagues?',
      options: ['September 1', 'August 31', 'September 15', 'August 1'],
      correctIndex: 0,
      category: 'transfers',
    ),
    const QuizQuestion(
      id: 'transfer_window_winter',
      question: 'When does the winter transfer window open?',
      options: ['January 1', 'December 1', 'February 1', 'January 15'],
      correctIndex: 0,
      category: 'transfers',
    ),
    const QuizQuestion(
      id: 'transfer_bosman_ruling',
      question: 'What year was the Bosman ruling established?',
      options: ['1995', '1990', '2000', '1985'],
      correctIndex: 0,
      category: 'transfers',
    ),
  ];

  // ─── AWARD QUESTIONS ────────────────────────────────────────────────────

  static final List<QuizQuestion> _awardQuestions = [
    const QuizQuestion(
      id: 'award_ballon_dor_most',
      question: 'Who has won the most Ballon d\'Or awards?',
      options: ['Lionel Messi', 'Cristiano Ronaldo', 'Michel Platini', 'Johan Cruyff'],
      correctIndex: 0,
      category: 'awards',
    ),
    const QuizQuestion(
      id: 'award_golden_boot',
      question: 'What is the Golden Boot award for?',
      options: ['Top goalscorer', 'Best player', 'Best goalkeeper', 'Best assist provider'],
      correctIndex: 0,
      category: 'awards',
    ),
    const QuizQuestion(
      id: 'award_yashin_trophy',
      question: 'What is the Yashin Trophy awarded for?',
      options: ['Best goalkeeper', 'Best young player', 'Best defender', 'Best midfielder'],
      correctIndex: 0,
      category: 'awards',
    ),
    const QuizQuestion(
      id: 'award_kopa_trophy',
      question: 'What is the Kopa Trophy awarded for?',
      options: ['Best young player under 21', 'Best newcomer', 'Best academy product', 'Most promising player'],
      correctIndex: 0,
      category: 'awards',
    ),
  ];

  // ─── RECORD QUESTIONS ───────────────────────────────────────────────────

  static final List<QuizQuestion> _recordQuestions = [
    const QuizQuestion(
      id: 'record_fastest_hat_trick',
      question: 'Who scored the fastest hat-trick in football history?',
      options: ['Tommy Ross', 'Lewandowski', 'Cristiano Ronaldo', 'Sergio Agüero'],
      correctIndex: 0,
      category: 'records',
    ),
    const QuizQuestion(
      id: 'record_most_goals_calendar',
      question: 'Who scored the most goals in a calendar year?',
      options: ['Lionel Messi', 'Cristiano Ronaldo', 'Gerd Müller', 'Pelé'],
      correctIndex: 0,
      category: 'records',
    ),
    const QuizQuestion(
      id: 'record_longest_goal',
      question: 'Who scored the longest goal in professional football?',
      options: ['Gavin Whyte', 'David Beckham', 'Ronald Koeman', 'Zlatan Ibrahimović'],
      correctIndex: 0,
      category: 'records',
    ),
  ];

  // ─── REFEREE QUESTIONS ──────────────────────────────────────────────────

  static final List<QuizQuestion> _refereeQuestions = [
    const QuizQuestion(
      id: 'referee_red_card',
      question: 'What is the signal for a red card?',
      options: ['Direct red card shown', 'Two yellow cards first', 'Straight red only for violent conduct', 'All of the above'],
      correctIndex: 3,
      category: 'referee',
    ),
    const QuizQuestion(
      id: 'referee_advantage_rule',
      question: 'When can a referee play the advantage rule?',
      options: ['When the attacking team has a clear goalscoring opportunity', 'When the ball is in play', 'When it\'s a direct free kick', 'When the defending team is in possession'],
      correctIndex: 0,
      category: 'referee',
    ),
  ];

  // ─── CLUB TRIVIA QUESTIONS ──────────────────────────────────────────────

  static final List<QuizQuestion> _clubTriviaQuestions = [
    const QuizQuestion(
      id: 'club_oldest_professional',
      question: 'Which is the oldest professional football club?',
      options: ['Sheffield FC', 'Notts County', 'Stoke City', 'Queen\'s Park'],
      correctIndex: 0,
      category: 'club_trivia',
    ),
    const QuizQuestion(
      id: 'club_most_league_titles_england',
      question: 'Which club has the most league titles in England?',
      options: ['Manchester United', 'Liverpool', 'Arsenal', 'Everton'],
      correctIndex: 0,
      category: 'club_trivia',
    ),
    const QuizQuestion(
      id: 'club_most_league_titles_sweden',
      question: 'Which club has the most league titles in Sweden?',
      options: ['Malmö FF', 'IFK Göteborg', 'AIK', 'Djurgården'],
      correctIndex: 0,
      category: 'club_trivia',
    ),
    const QuizQuestion(
      id: 'club_most_league_titles_norway',
      question: 'Which club has the most league titles in Norway?',
      options: ['Rosenborg BK', 'Molde FK', 'Vålerenga', 'Brann'],
      correctIndex: 0,
      category: 'club_trivia',
    ),
    const QuizQuestion(
      id: 'club_most_league_titles_denmark',
      question: 'Which club has the most league titles in Denmark?',
      options: ['FC Copenhagen', 'Brøndby IF', 'Odense Boldklub', 'Aalborg BK'],
      correctIndex: 0,
      category: 'club_trivia',
    ),
    const QuizQuestion(
      id: 'club_most_league_titles_japan',
      question: 'Which club has the most J.League titles?',
      options: ['Kashima Antlers', 'Yokohama F. Marinos', 'Urawa Red Diamonds', 'Gamba Osaka'],
      correctIndex: 0,
      category: 'club_trivia',
    ),
  ];

  // ─── PLAYER TRIVIA QUESTIONS ────────────────────────────────────────────

  static final List<QuizQuestion> _playerTriviaQuestions = [
    const QuizQuestion(
      id: 'player_most_international_caps',
      question: 'Who has the most international caps?',
      options: ['Cristiano Ronaldo', 'Lionel Messi', 'Ali Daei', 'Sergio Ramos'],
      correctIndex: 0,
      category: 'player_trivia',
    ),
    const QuizQuestion(
      id: 'player_most_goals_international',
      question: 'Who has the most international goals?',
      options: ['Cristiano Ronaldo', 'Lionel Messi', 'Ali Daei', 'Ferenc Puskás'],
      correctIndex: 0,
      category: 'player_trivia',
    ),
    const QuizQuestion(
      id: 'player_most_club_goals',
      question: 'Who has scored the most goals for a single club?',
      options: ['Lionel Messi', 'Pelé', 'Cristiano Ronaldo', 'Gerd Müller'],
      correctIndex: 0,
      category: 'player_trivia',
    ),
    const QuizQuestion(
      id: 'player_highest_ballon_dor_youngest',
      question: 'Who is the youngest Ballon d\'Or winner?',
      options: ['Ronaldo Nazário', 'Lionel Messi', 'Kylian Mbappé', 'Pelé'],
      correctIndex: 1,
      category: 'player_trivia',
    ),
  ];

  // ─── LAWS OF THE GAME QUESTIONS ────────────────────────────────────────

  static final List<QuizQuestion> _lawsOfTheGameQuestions = [
    const QuizQuestion(
      id: 'rules_min_players',
      question: 'What is the minimum number of players a team may have on the pitch for a match to continue?',
      options: ['6', '7', '8', '9'],
      correctIndex: 1,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_wall_distance',
      question: 'How far from the ball must opposing players retreat at a free kick?',
      options: ['6 yards', '8 yards', '10 yards', '12 yards'],
      correctIndex: 2,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_drop_ball',
      question: 'What is it called when the referee restarts play by releasing the ball between two players?',
      options: ['Drop ball', 'Free ball', 'Loose ball', 'Kick-in'],
      correctIndex: 0,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_gk_own_half',
      question: 'Can a goalkeeper legally score by kicking the ball directly into the opponents\' goal from inside their own half?',
      options: ['Yes, it counts as a valid goal', 'No, it is always disallowed', 'Only in extra time', 'Only from a goal kick'],
      correctIndex: 0,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_subs_normal_time',
      question: 'Under the substitution rule now used by most major competitions, how many subs may a team make in normal time?',
      options: ['3', '4', '5', '6'],
      correctIndex: 2,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_second_yellow',
      question: 'What happens when a player receives a second yellow card in the same match?',
      options: [
        'Nothing, cards reset each half',
        'It becomes a red card and they are sent off',
        'The team is reduced for 10 minutes only',
        'It only counts as one caution',
      ],
      correctIndex: 1,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_added_time',
      question: 'What is the extra time played at the end of each half to make up for stoppages officially called?',
      options: ['Overtime', 'Added time (stoppage time)', 'Golden time', 'Bonus time'],
      correctIndex: 1,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_throw_in',
      question: 'A throw-in is awarded to the opponents of the team that last touched the ball before it did what?',
      options: [
        'Crossed the goal line between the posts',
        'Crossed either touchline completely',
        'Hit the referee',
        'Went out for a corner',
      ],
      correctIndex: 1,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_indirect_fk',
      question: 'For an indirect free kick to result in a goal, what must happen after the kick is taken?',
      options: [
        'The ball must touch another player before entering the goal',
        'It can never result in a goal',
        'The goalkeeper must touch it first',
        'It must be retaken',
      ],
      correctIndex: 0,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_offside_position',
      question: 'A player cannot be penalized for offside if they receive the ball directly from which of these restarts?',
      options: ['A throw-in', 'A through pass', 'A free kick', 'A rebound off the post'],
      correctIndex: 0,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_handball_position',
      question: 'Where should a player\'s hand be to avoid a handball foul?',
      options: ['In front of body', 'By their side', 'Above head', 'Any position is legal'],
      correctIndex: 1,
      category: 'rules',
    ),
    const QuizQuestion(
      id: 'rules_backpass',
      question: 'When can the goalkeeper not handle a back-pass?',
      options: ['When it\'s with the foot', 'When it\'s with the head', 'When it\'s from the touchline', 'When it\'s from the halfway line'],
      correctIndex: 0,
      category: 'rules',
    ),
  ];

  // ─── WORLD CUP QUESTIONS ────────────────────────────────────────────────

  static final List<QuizQuestion> _worldCupQuestions = [
    const QuizQuestion(
      id: 'wc_most_titles',
      question: 'Which country has won the most FIFA World Cup titles?',
      options: ['Germany', 'Brazil', 'Italy', 'Argentina'],
      correctIndex: 1,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_frequency',
      question: 'How often is the FIFA World Cup held?',
      options: ['Every 2 years', 'Every 3 years', 'Every 4 years', 'Every 5 years'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_first_host',
      question: 'Which country hosted and won the first FIFA World Cup in 1930?',
      options: ['Brazil', 'Italy', 'Uruguay', 'France'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_2018_winner',
      question: 'Which country won the 2018 FIFA World Cup in Russia?',
      options: ['Croatia', 'Belgium', 'France', 'England'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_2022_winner',
      question: 'Which country won the 2022 FIFA World Cup in Qatar?',
      options: ['France', 'Brazil', 'Argentina', 'Morocco'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_2022_host',
      question: 'The 2022 FIFA World Cup was the first ever held in which region?',
      options: ['South America', 'The Middle East', 'Africa', 'Southeast Asia'],
      correctIndex: 1,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_2026_hosts',
      question: 'The 2026 FIFA World Cup is being co-hosted by the USA, Mexico, and which other country?',
      options: ['Canada', 'Costa Rica', 'Panama', 'Jamaica'],
      correctIndex: 0,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_2026_teams',
      question: 'How many national teams will compete in the expanded 2026 FIFA World Cup?',
      options: ['32', '40', '48', '56'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_golden_boot',
      question: 'What is the award for the top goal scorer of a FIFA World Cup tournament called?',
      options: ['Golden Ball', 'Golden Glove', 'Golden Boot', 'Golden Whistle'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_golden_ball',
      question: 'What is the award for the best overall player of a FIFA World Cup tournament called?',
      options: ['Golden Boot', 'Golden Ball', 'Player of the Cup', 'MVP Trophy'],
      correctIndex: 1,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_golden_glove',
      question: 'What is the award for the best goalkeeper of a FIFA World Cup tournament called?',
      options: ['Golden Glove', 'Golden Gate', 'Iron Wall', 'Clean Sheet Award'],
      correctIndex: 0,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_trophy_replaced',
      question: 'The current FIFA World Cup Trophy replaced which earlier trophy, retired after Brazil won it outright in 1970?',
      options: ['The Rimet Cup', 'The Jules Rimet Trophy', 'The Golden Globe', 'The FIFA Cup'],
      correctIndex: 1,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_most_goals_career',
      question: 'Who has scored the most goals in World Cup history?',
      options: ['Miroslav Klose', 'Ronaldo', 'Gerd Müller', 'Pele'],
      correctIndex: 0,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_most_appearances',
      question: 'Who has played in the most World Cups?',
      options: ['Lionel Messi', 'Cristiano Ronaldo', 'Antonio Carbajal', 'Lothar Matthäus'],
      correctIndex: 2,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_oldest_goalscorer',
      question: 'Who is the oldest goalscorer in World Cup history?',
      options: ['Roger Milla', 'Lothar Matthäus', 'Pele', 'Diego Maradona'],
      correctIndex: 0,
      category: 'world_cup',
    ),
    const QuizQuestion(
      id: 'wc_youngest_goalscorer',
      question: 'Who is the youngest goalscorer in World Cup history?',
      options: ['Pele', 'Lionel Messi', 'Kylian Mbappé', 'Michael Owen'],
      correctIndex: 0,
      category: 'world_cup',
    ),
  ];

  // ─── FALLBACK QUESTIONS ──────────────────────────────────────────────────

  static final List<QuizQuestion> _fallbackQuestions = [
    const QuizQuestion(
      id: 'fb_players_on_pitch',
      question: 'How many players does each team have on the pitch at kickoff?',
      options: ['9', '10', '11', '12'],
      correctIndex: 2,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_match_length',
      question: 'How long is a standard football match, excluding stoppage time?',
      options: ['60 minutes', '80 minutes', '90 minutes', '120 minutes'],
      correctIndex: 2,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_offside',
      question: 'A player is offside if they are nearer to the opponent goal line than the ball and how many defenders?',
      options: ['Zero', 'One', 'Two', 'Three'],
      correctIndex: 1,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_yellow_cards',
      question: 'How many yellow cards in one match lead to an automatic red card?',
      options: ['One', 'Two', 'Three', 'Four'],
      correctIndex: 1,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_corner',
      question: 'A corner kick is awarded when the ball fully crosses the goal line after touching which side last?',
      options: ['Attacking team', 'Defending team', 'The referee', 'Either side'],
      correctIndex: 1,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_extra_time',
      question: 'In knockout football, how long is each half of extra time?',
      options: ['10 minutes', '15 minutes', '20 minutes', '30 minutes'],
      correctIndex: 1,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_subs',
      question: 'In most modern top-flight competitions, how many substitutes can a team use in normal time?',
      options: ['Three', 'Four', 'Five', 'Six'],
      correctIndex: 2,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_penalty_spot',
      question: 'How far is the penalty spot from the goal line?',
      options: ['6 yards', '9 yards', '12 yards', '18 yards'],
      correctIndex: 2,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_captain_band',
      question: 'What is worn by the on-field leader of a football team?',
      options: ['A cap', 'A captain\'s armband', 'A whistle', 'A gold badge'],
      correctIndex: 1,
      category: 'general',
    ),
    const QuizQuestion(
      id: 'fb_var',
      question: 'What does the football technology abbreviation VAR stand for?',
      options: [
        'Video Assistant Referee',
        'Virtual Attack Range',
        'Verified Automatic Replay',
        'Visual Analysis Report',
      ],
      correctIndex: 0,
      category: 'general',
    ),
  ];
}