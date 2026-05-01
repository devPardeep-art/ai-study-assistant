import 'package:flutter/material.dart';
import '../theme.dart';
import 'apiService.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _result = {};
  String _originalText = '';
  int _clarityRating = 3;
  int _accuracyRating = 3;
  int _usefulnessRating = 3;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    ApiService.isLoggedIn().then((v) {
      if (mounted) setState(() => _isLoggedIn = v);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      _result = args['result'] ?? {};
      _originalText = args['originalText'] ?? '';
    }
  }

  String get _rawOutput => _result['output'] ?? '';
  String get _modelName => _result['model'] ?? 'Unknown';
  double get _responseTime => (_result['response_time'] ?? 0).toDouble();
  Map<String, dynamic> get _metrics => _result['metrics'] ?? {};

  String _extractSection(String output, String section) {
    final patterns = {
      'SUMMARY': RegExp(r'(?:1\.\s*)?SUMMARY[:\s]*(.*?)(?=(?:2\.\s*)?FLASHCARD|(?:2\.\s*)?FLASH|$)', dotAll: true, caseSensitive: false),
      'FLASHCARDS': RegExp(r'(?:2\.\s*)?FLASHCARD[S]?[:\s]*(.*?)(?=(?:3\.\s*)?QUIZ|$)', dotAll: true, caseSensitive: false),
      'QUIZ': RegExp(r'(?:3\.\s*)?QUIZ[:\s]*(.*?)$', dotAll: true, caseSensitive: false),
    };
    final match = patterns[section]?.firstMatch(output);
    return match?.group(1)?.trim() ?? output;
  }

  List<Map<String, String>> _parseFlashcards(String text) {
    final cards = <Map<String, String>>[];
    final qPattern = RegExp(r'Q\d*[:.]\s*(.*?)(?=A\d*[:.]\s*)', dotAll: true);
    final aPattern = RegExp(r'A\d*[:.]\s*(.*?)(?=Q\d*[:.]\s*|$)', dotAll: true);
    final questions = qPattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').toList();
    final answers = aPattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').toList();
    for (int i = 0; i < questions.length && i < answers.length; i++) {
      if (questions[i].isNotEmpty) cards.add({'q': questions[i], 'a': answers[i]});
    }
    return cards.isEmpty ? [{'q': 'No flashcards found', 'a': text}] : cards;
  }

  @override
  Widget build(BuildContext context) {
    if (_result.containsKey('error')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_result['error'], style: const TextStyle(color: kRed))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_modelName.toUpperCase(),
                style: const TextStyle(fontSize: 15, color: kAccent, fontWeight: FontWeight.w800)),
            Text('${_responseTime.toStringAsFixed(2)}s response',
                style: const TextStyle(fontSize: 11, color: kText2)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/metrics',
                arguments: {'metrics': _metrics, 'originalText': _originalText}),
            icon: const Icon(Icons.bar_chart_rounded, size: 16, color: kAccent2),
            label: const Text('Metrics', style: TextStyle(color: kAccent2)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kAccent,
          indicatorWeight: 3,
          labelColor: kAccent,
          unselectedLabelColor: kText2,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: [
            const Tab(text: 'Summary'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Flashcards'),
                  if (!_isLoggedIn) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_rounded, size: 11, color: kText2),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Quiz'),
            const Tab(text: 'Rate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _isLoggedIn ? _buildFlashcardsTab() : _buildLockedTab('Flashcards', Icons.style_rounded),
          _buildQuizTab(),
          _buildRatingTab(),
        ],
      ),
    );
  }

  // ─── LOCKED TAB ──────────────────────────────────────────────────────────────

  Widget _buildLockedTab(String feature, IconData icon) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: child,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kAccent.withValues(alpha: 0.15),
                        kAccent2.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: kAccent, size: 52),
                ),
              ),
              const SizedBox(height: 24),
              Text('Login Required',
                  style: kTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'Sign in to unlock $feature and track your study progress',
                style: kSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Login / Register'),
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/login');
                    final loggedIn = await ApiService.isLoggedIn();
                    if (mounted) setState(() => _isLoggedIn = loggedIn);
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Free account — no subscription needed',
                style: TextStyle(color: kText2, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SUMMARY TAB ─────────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    final summary = _extractSection(_rawOutput, 'SUMMARY');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                    color: kAccent.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.summarize_rounded, color: kAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Summary',
                        style: TextStyle(color: kAccent, fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
                  const Divider(color: kBorder, height: 22),
                  Text(summary, style: kBody.copyWith(height: 1.7)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_metrics.isNotEmpty) _buildMetricPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.analytics_rounded, color: kText2, size: 14),
            SizedBox(width: 6),
            Text('Quick Metrics',
                style: TextStyle(color: kText2, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniMetric('Readability', '${_metrics['flesch_reading_ease'] ?? '-'}', kAccent),
              _MiniMetric('Keywords', '${_metrics['keyword_coverage_percent'] ?? '-'}%', kAccent2),
              _MiniMetric('ROUGE-1', '${_metrics['rouge_1'] ?? '-'}', kAmber),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FLASHCARDS TAB ──────────────────────────────────────────────────────────

  Widget _buildFlashcardsTab() {
    final cards = _parseFlashcards(_extractSection(_rawOutput, 'FLASHCARDS'));
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded, color: kAccent, size: 16),
              const SizedBox(width: 8),
              Text('Tap to reveal · ${cards.length} cards',
                  style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  for (final card in cards) {
                    if ((card['q'] ?? '').isNotEmpty && card['q'] != 'No flashcards found') {
                      await ApiService.saveFlashcard(
                        question: card['q']!,
                        answer: card['a'] ?? '',
                        modelName: _modelName,
                      );
                    }
                  }
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Flashcards saved to your collection!'),
                        backgroundColor: Color(0xFF4F46E5),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('Save All',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cards.length,
            itemBuilder: (context, index) => TweenAnimationBuilder<double>(
              key: ValueKey(index),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + index * 60),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - value)),
                  child: child,
                ),
              ),
              child: _FlashCard(
                question: cards[index]['q'] ?? '',
                answer: cards[index]['a'] ?? '',
                index: index,
                modelName: _modelName,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── QUIZ TAB ────────────────────────────────────────────────────────────────

  Widget _buildQuizTab() {
    final quizText = _extractSection(_rawOutput, 'QUIZ');
    return _ResultsInteractiveQuiz(quizText: quizText, modelName: _modelName);
  }

  // ─── RATING TAB ──────────────────────────────────────────────────────────────

  Widget _buildRatingTab() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.star_rounded, color: kAmber, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Rate this response',
                        style: kTitle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text('Your feedback helps improve model comparisons',
                        style: TextStyle(color: kText2, fontSize: 12)),
                  ),
                  const SizedBox(height: 20),
                  _RatingRow(
                      label: 'Clarity',
                      value: _clarityRating,
                      onChanged: (v) => setState(() => _clarityRating = v)),
                  _RatingRow(
                      label: 'Accuracy',
                      value: _accuracyRating,
                      onChanged: (v) => setState(() => _accuracyRating = v)),
                  _RatingRow(
                      label: 'Usefulness',
                      value: _usefulnessRating,
                      onChanged: (v) => setState(() => _usefulnessRating = v)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Submit Rating'),
                      onPressed: () async {
                        await ApiService.submitEvaluation(
                          model: _modelName,
                          clarity: _clarityRating,
                          accuracy: _accuracyRating,
                          usefulness: _usefulnessRating,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanks for your feedback!'),
                              backgroundColor: kAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MINI METRIC ──────────────────────────────────────────────────────────────

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kText2, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── FLASH CARD ───────────────────────────────────────────────────────────────

class _FlashCard extends StatefulWidget {
  final String question;
  final String answer;
  final int index;
  final String modelName;
  const _FlashCard({required this.question, required this.answer, required this.index, required this.modelName});
  @override
  State<_FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<_FlashCard> with SingleTickerProviderStateMixin {
  bool _showAnswer = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.forward();
    setState(() => _showAnswer = !_showAnswer);
    await _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _showAnswer ? kAccent.withValues(alpha: 0.07) : kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _showAnswer ? kAccent : kBorder,
              width: _showAnswer ? 1.5 : 1,
            ),
            boxShadow: _showAnswer
                ? [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _showAnswer
                          ? kAccent.withValues(alpha: 0.15)
                          : kSurface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Q${widget.index + 1}',
                      style: TextStyle(
                        color: _showAnswer ? kAccent : kText2,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ApiService.saveFlashcard(
                        question: widget.question,
                        answer: widget.answer,
                        modelName: widget.modelName,
                      );
                      if (context.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Flashcard saved!'),
                            backgroundColor: Color(0xFF4F46E5),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.bookmark_border_rounded,
                        color: _showAnswer ? kAccent : kText2,
                        size: 18,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showAnswer ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _showAnswer ? kAccent : kText2,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.question,
                style: const TextStyle(
                  color: kText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: child,
                  ),
                ),
                child: _showAnswer
                    ? Padding(
                        key: const ValueKey('answer'),
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(color: kAccent.withValues(alpha: 0.25), height: 1),
                            const SizedBox(height: 12),
                            Text(
                              widget.answer,
                              style: const TextStyle(
                                color: kAccent2,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Padding(
                        key: ValueKey('hint'),
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Tap to reveal answer',
                          style: TextStyle(color: kText2, fontSize: 11),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── RATING ROW ───────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final Function(int) onChanged;
  const _RatingRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value / 5',
                  style: const TextStyle(
                      color: kAccent, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: kAccent,
            inactiveColor: kSurface2,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

// ─── QUIZ DATA ────────────────────────────────────────────────────────────────

class _RQQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  const _RQQuestion({required this.question, required this.options, required this.correctIndex});
}

List<_RQQuestion> _parseRQQuestions(String text) {
  final questions = <_RQQuestion>[];
  final blocks = text.split(RegExp(r'(?=^\d+[\.\)]\s)', multiLine: true));
  final optionRe = RegExp(r'^([A-Da-d][\.\)]\s*)(.+)$');
  final answerRe = RegExp(r'(?:correct\s+)?answer[:\s]+\**([A-Da-d])\**', caseSensitive: false);

  for (final block in blocks) {
    final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) continue;
    final qText = lines.first.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim();
    if (qText.isEmpty) continue;
    final opts = <String>[];
    String? answerLetter;
    for (int i = 1; i < lines.length; i++) {
      final aMatch = answerRe.firstMatch(lines[i]);
      if (aMatch != null) { answerLetter = aMatch.group(1)!.toUpperCase(); continue; }
      final oMatch = optionRe.firstMatch(lines[i]);
      if (oMatch != null) opts.add(oMatch.group(2)!.trim());
    }
    if (opts.length >= 2) {
      final correctIdx = answerLetter != null
          ? (answerLetter.codeUnitAt(0) - 'A'.codeUnitAt(0)).clamp(0, opts.length - 1)
          : 0;
      questions.add(_RQQuestion(question: qText, options: opts, correctIndex: correctIdx));
    }
  }
  return questions;
}

// ─── INTERACTIVE QUIZ WIDGET ──────────────────────────────────────────────────

class _ResultsInteractiveQuiz extends StatefulWidget {
  final String quizText;
  final String modelName;
  const _ResultsInteractiveQuiz({required this.quizText, required this.modelName});
  @override
  State<_ResultsInteractiveQuiz> createState() => _ResultsInteractiveQuizState();
}

class _ResultsInteractiveQuizState extends State<_ResultsInteractiveQuiz> {
  late List<_RQQuestion> _questions;
  final Map<int, int> _selected = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _questions = _parseRQQuestions(widget.quizText);
  }

  int get _score => _questions.asMap().entries
      .where((e) => _selected[e.key] == e.value.correctIndex)
      .length;

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
          ),
          child: SelectableText(widget.quizText, style: kBody.copyWith(height: 1.7)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_submitted) _buildScoreCard(),
        ...List.generate(_questions.length, _buildQuestion),
        const SizedBox(height: 8),
        if (!_submitted)
          ElevatedButton(
            onPressed: _selected.length == _questions.length
                ? () async {
                    setState(() => _submitted = true);
                    await ApiService.saveQuizResult(
                      modelName: widget.modelName,
                      score: _score,
                      total: _questions.length,
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _selected.length == _questions.length
                  ? 'Submit Quiz'
                  : 'Answer all questions (${_selected.length}/${_questions.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => setState(() { _selected.clear(); _submitted = false; }),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retake Quiz'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent,
              side: const BorderSide(color: kAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard() {
    final pct = (_score / _questions.length * 100).round();
    final Color color;
    final String label;
    if (pct >= 80) { color = kAccent2; label = 'Excellent!'; }
    else if (pct >= 60) { color = const Color(0xFF3B82F6); label = 'Good job!'; }
    else if (pct >= 40) { color = kAmber; label = 'Keep practicing'; }
    else { color = kRed; label = 'Review the material'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Text('$_score / ${_questions.length}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 44, height: 1.1)),
        const SizedBox(height: 4),
        Text('$pct% correct', style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 13)),
      ]),
    );
  }

  Widget _buildQuestion(int qi) {
    final q = _questions[qi];
    final selected = _selected[qi];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Q${qi + 1}',
                      style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(q.question,
                      style: const TextStyle(
                          color: kText, fontWeight: FontWeight.w600, fontSize: 13, height: 1.5)),
                ),
              ],
            ),
          ),
          ...List.generate(q.options.length, (oi) => _buildOption(qi, oi, q, selected)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildOption(int qi, int oi, _RQQuestion q, int? selected) {
    final isSelected = selected == oi;
    final isCorrect = oi == q.correctIndex;
    Color borderColor = kBorder;
    Color bgColor = Colors.transparent;
    Color textColor = kText;
    Widget? trailing;

    if (_submitted) {
      if (isCorrect) {
        borderColor = kAccent2; bgColor = kAccent2.withValues(alpha: 0.08); textColor = const Color(0xFF065F46);
        trailing = const Icon(Icons.check_circle_rounded, color: kAccent2, size: 18);
      } else if (isSelected) {
        borderColor = kRed; bgColor = kRed.withValues(alpha: 0.08); textColor = kRed;
        trailing = const Icon(Icons.cancel_rounded, color: kRed, size: 18);
      }
    } else if (isSelected) {
      borderColor = kAccent; bgColor = kAccent.withValues(alpha: 0.08); textColor = kAccent;
    }

    final labels = ['A', 'B', 'C', 'D'];
    return GestureDetector(
      onTap: _submitted ? null : () => setState(() => _selected[qi] = oi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: isSelected || (_submitted && isCorrect)
                  ? borderColor : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(labels[oi],
                  style: TextStyle(
                    color: isSelected || (_submitted && isCorrect) ? Colors.white : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(q.options[oi],
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500))),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ]),
      ),
    );
  }
}
