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
    // Avoid opening the same boxes twice if init() and a lazy
    // _ensureInitialized() call race each other.
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

  /// Called at the top of every public method so the service works
  /// correctly even if init() was never called from main.dart.
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
  /// Returns today's quiz, generating and caching it the first time
  /// it's requested for the current date.
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

  /// Records the user's answer for [questionIndex] and updates
  /// lifetime stats (balls collected on correct answers).
  Future<QuizDailySet> submitAnswer({
    required QuizDailySet quiz,
    required int questionIndex,
    required int selectedOption,
  }) async {
    if (questionIndex < 0 || questionIndex >= quiz.questions.length) return quiz;
    if (quiz.answers[questionIndex] != null) return quiz; // already answered

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

    pool.shuffle(random);

    final selected = <QuizQuestion>[];
    final usedQuestionText = <String>{};
    for (final q in pool) {
      if (selected.length >= questionsPerDay) break;
      if (usedQuestionText.contains(q.question)) continue;
      usedQuestionText.add(q.question);
      selected.add(q);
    }

    // Top up with evergreen fallback questions if live ESPN data
    // wasn't enough to fill a full 10 today.
    if (selected.length < questionsPerDay) {
      final fallback = List<QuizQuestion>.from(_fallbackQuestions)..shuffle(random);
      for (final q in fallback) {
        if (selected.length >= questionsPerDay) break;
        if (usedQuestionText.contains(q.question)) continue;
        usedQuestionText.add(q.question);
        selected.add(q);
      }
    }

    // Shuffle option order per question so the correct answer isn't
    // always in the same position, while keeping correctIndex accurate.
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

    // Table leader.
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

    // Points for a random mid-table team.
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

    // Best goal difference.
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

  // Fixed, evergreen fallback pool - only used to top up a set when
  // there isn't enough live ESPN data available yet.
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