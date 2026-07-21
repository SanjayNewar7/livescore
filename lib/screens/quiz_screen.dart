// lib/screens/quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:livescore/models/quiz_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/services/quiz_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const Color _blue = Color(0xFF1A62C8);
  static const Color _green = Color(0xFF16A34A);
  static const Color _ink = Color(0xFF0F1623);
  static const Color _red = Color(0xFFDC2626);

  QuizDailySet? _quiz;
  bool _loading = true;
  int _currentIndex = 0;
  int? _selectedOption;
  bool _showResult = false;
  bool _showingResultsScreen = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Make sure there is live ESPN data available to build today's
    // questions from before generating the set.
    final futures = <Future>[];
    if (provider.standings.isEmpty) futures.add(provider.fetchStandings());
    if (provider.allTeams.isEmpty) futures.add(provider.fetchAllTeams());
    if (provider.yesterdaysGames.isEmpty) futures.add(provider.fetchYesterdaysMatches());
    if (provider.news.isEmpty) futures.add(provider.fetchNews());
    if (futures.isNotEmpty) {
      await Future.wait(futures.map((f) => f.catchError((_) {})));
    }

    final quiz = await QuizService().getTodayQuiz(provider);
    final firstUnanswered = quiz.answers.indexWhere((a) => a == null);

    if (!mounted) return;
    setState(() {
      _quiz = quiz;
      _currentIndex = firstUnanswered == -1 ? 0 : firstUnanswered;
      _showingResultsScreen = quiz.isFullyAnswered;
      _selectedOption = _showingResultsScreen ? null : quiz.answers[_currentIndex];
      _showResult = _selectedOption != null;
      _loading = false;
    });
  }

  Future<void> _selectOption(int optionIndex) async {
    if (_selectedOption != null || _quiz == null) return;
    setState(() {
      _selectedOption = optionIndex;
      _showResult = true;
    });

    final updated = await QuizService().submitAnswer(
      quiz: _quiz!,
      questionIndex: _currentIndex,
      selectedOption: optionIndex,
    );
    if (mounted) setState(() => _quiz = updated);
  }

  void _next() {
    if (_quiz == null) return;
    if (_currentIndex >= _quiz!.questions.length - 1) {
      setState(() => _showingResultsScreen = true);
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = _quiz!.answers[_currentIndex];
      _showResult = _selectedOption != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Daily Football Quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _quiz == null || _quiz!.questions.isEmpty
          ? _buildUnavailable()
          : (_showingResultsScreen ? _buildResults() : _buildQuestion()),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Today\'s quiz isn\'t ready yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _loading = true);
                _loadQuiz();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final quiz = _quiz!;
    final question = quiz.questions[_currentIndex];
    final progress = (_currentIndex + 1) / quiz.questions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_currentIndex + 1} of ${quiz.questions.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.sports_soccer_rounded, size: 16, color: _green),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz.correctCount}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: _blue.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(_blue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_blue, Color(0xFF0D3F85)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  question.question,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(question.options.length, (i) => _buildOptionTile(question, i)),
            ],
          ),
        ),
        if (_showResult)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _currentIndex >= quiz.questions.length - 1 ? 'See Results' : 'Next Question',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionTile(QuizQuestion question, int index) {
    final isSelected = _selectedOption == index;
    final isCorrect = index == question.correctIndex;

    Color borderColor = Colors.grey.shade200;
    Color bgColor = Colors.white;
    Color textColor = _ink;
    Widget? trailingIcon;

    if (_showResult) {
      if (isCorrect) {
        borderColor = _green;
        bgColor = _green.withOpacity(0.08);
        textColor = _green;
        trailingIcon = const Icon(Icons.check_circle_rounded, color: _green, size: 20);
      } else if (isSelected) {
        borderColor = _red;
        bgColor = _red.withOpacity(0.06);
        textColor = _red;
        trailingIcon = const Icon(Icons.cancel_rounded, color: _red, size: 20);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectOption(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    question.options[index],
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
                if (trailingIcon != null) trailingIcon,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final quiz = _quiz!;
    final stats = QuizService().stats;
    final scorePercent = quiz.questions.isEmpty ? 0.0 : quiz.correctCount / quiz.questions.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_blue, _green], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 44),
              const SizedBox(height: 12),
              Text(
                '${quiz.correctCount} / ${quiz.questions.length} Correct',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${(scorePercent * 100).round()}% today',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard('Balls Collected', '${stats.totalBalls}', Icons.sports_soccer_rounded, _green)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Day Streak', '${stats.currentStreak}', Icons.local_fire_department_outlined, _blue)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Quizzes Done', '${stats.quizzesCompleted}', Icons.fact_check_outlined, _blue)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Total Correct', '${stats.totalCorrect}', Icons.check_circle_outline, _green)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Come back tomorrow for a brand new set of 10 questions.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back to Settings', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}