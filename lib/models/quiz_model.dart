// lib/models/quiz_model.dart
//
// Data models backing the "Play Quiz" feature. A fresh 10 question
// set is generated once per day from live ESPN data already flowing
// through AppProvider (standings, results, team info, news) and then
// persisted locally so the same set is shown all day.

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String category;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'category': category,
  };

  factory QuizQuestion.fromJson(Map json) => QuizQuestion(
    id: json['id']?.toString() ?? '',
    question: json['question']?.toString() ?? '',
    options: (json['options'] as List? ?? []).map((e) => e.toString()).toList(),
    correctIndex: json['correctIndex'] is int ? json['correctIndex'] as int : int.tryParse('${json['correctIndex']}') ?? 0,
    category: json['category']?.toString() ?? 'general',
  );
}

class QuizDailySet {
  final String date; // yyyy-MM-dd
  final List<QuizQuestion> questions;
  final List<int?> answers;
  final bool completed;

  const QuizDailySet({
    required this.date,
    required this.questions,
    required this.answers,
    this.completed = false,
  });

  int get totalQuestions => questions.length;

  int get answeredCount => answers.where((a) => a != null).length;

  int get correctCount {
    int count = 0;
    for (int i = 0; i < questions.length && i < answers.length; i++) {
      if (answers[i] != null && answers[i] == questions[i].correctIndex) count++;
    }
    return count;
  }

  bool get isFullyAnswered => answeredCount >= totalQuestions && totalQuestions > 0;

  QuizDailySet copyWith({
    List<int?>? answers,
    bool? completed,
  }) {
    return QuizDailySet(
      date: date,
      questions: questions,
      answers: answers ?? this.answers,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'questions': questions.map((q) => q.toJson()).toList(),
    'answers': answers,
    'completed': completed,
  };

  factory QuizDailySet.fromJson(Map json) => QuizDailySet(
    date: json['date']?.toString() ?? '',
    questions: (json['questions'] as List? ?? [])
        .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    answers: (json['answers'] as List? ?? [])
        .map((e) => e == null ? null : (e is int ? e : int.tryParse('$e')))
        .toList(),
    completed: json['completed'] == true,
  );
}

class QuizStats {
  final int totalBalls;
  final int totalCorrect;
  final int totalAnswered;
  final int quizzesCompleted;
  final int currentStreak;
  final int bestStreak;
  final String? lastCompletedDate;

  const QuizStats({
    this.totalBalls = 0,
    this.totalCorrect = 0,
    this.totalAnswered = 0,
    this.quizzesCompleted = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
  });

  static const empty = QuizStats();

  QuizStats copyWith({
    int? totalBalls,
    int? totalCorrect,
    int? totalAnswered,
    int? quizzesCompleted,
    int? currentStreak,
    int? bestStreak,
    String? lastCompletedDate,
  }) {
    return QuizStats(
      totalBalls: totalBalls ?? this.totalBalls,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalAnswered: totalAnswered ?? this.totalAnswered,
      quizzesCompleted: quizzesCompleted ?? this.quizzesCompleted,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalBalls': totalBalls,
    'totalCorrect': totalCorrect,
    'totalAnswered': totalAnswered,
    'quizzesCompleted': quizzesCompleted,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'lastCompletedDate': lastCompletedDate,
  };

  factory QuizStats.fromJson(Map? json) {
    if (json == null) return QuizStats.empty;
    return QuizStats(
      totalBalls: json['totalBalls'] ?? 0,
      totalCorrect: json['totalCorrect'] ?? 0,
      totalAnswered: json['totalAnswered'] ?? 0,
      quizzesCompleted: json['quizzesCompleted'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      lastCompletedDate: json['lastCompletedDate']?.toString(),
    );
  }
}