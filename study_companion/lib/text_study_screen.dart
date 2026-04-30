import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'apiservice.dart';

// ─── COLOUR TOKENS (match app palette) ───────────────────────────────────────

const _kIndigo    = Color(0xFF4F46E5);
const _kIndigoDark = Color(0xFF1E1B4B);
const _kPurple    = Color(0xFF7C3AED);
const _kGreen     = Color(0xFF10B981);
const _kAmber     = Color(0xFFF59E0B);
const _kRed       = Color(0xFFEF4444);
const _kBg        = Color(0xFFF0F2FF);
const _kSurface   = Color(0xFFFFFFFF);
const _kSurface2  = Color(0xFFF1F5F9);
const _kBorder    = Color(0xFFE2E8F0);
const _kText      = Color(0xFF1E293B);
const _kText2     = Color(0xFF64748B);

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class _ModelOption {
  final String id;
  final String label;
  final bool isPro;
  const _ModelOption({required this.id, required this.label, required this.isPro});
}

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

// ─── MODEL CATALOGUE ──────────────────────────────────────────────────────────

const _kModels = [
  _ModelOption(id: 'llama3',  label: 'Llama 3',  isPro: false),
  _ModelOption(id: 'mistral', label: 'Mistral',  isPro: false),
  _ModelOption(id: 'phi3',    label: 'Phi-3',    isPro: false),
  _ModelOption(id: 'openai',  label: 'GPT-4o',   isPro: true),
  _ModelOption(id: 'claude',  label: 'Claude',   isPro: true),
  _ModelOption(id: 'gemini',  label: 'Gemini',   isPro: true),
];

// ─── PARSING HELPERS ──────────────────────────────────────────────────────────

String _extractSection(String output, String section) {
  final patterns = <String, RegExp>{
    'SUMMARY': RegExp(
        r'(?:1\.\s*)?SUMMARY[:\s]*(.*?)(?=(?:2\.\s*)?FLASHCARD|(?:2\.\s*)?FLASH|$)',
        dotAll: true, caseSensitive: false),
    'FLASHCARDS': RegExp(
        r'(?:2\.\s*)?FLASHCARD[S]?[:\s]*(.*?)(?=(?:3\.\s*)?QUIZ|$)',
        dotAll: true, caseSensitive: false),
    'QUIZ': RegExp(
        r'(?:3\.\s*)?QUIZ[:\s]*(.*?)$',
        dotAll: true, caseSensitive: false),
  };
  final match = patterns[section]?.firstMatch(output);
  return match?.group(1)?.trim() ?? '';
}

List<Map<String, String>> _parseFlashcards(String text) {
  final qPattern = RegExp(r'Q\d*[:.]\s*(.*?)(?=A\d*[:.]\s*)', dotAll: true);
  final aPattern = RegExp(r'A\d*[:.]\s*(.*?)(?=Q\d*[:.]\s*|$)', dotAll: true);
  final questions = qPattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').toList();
  final answers   = aPattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').toList();
  final cards = <Map<String, String>>[];
  for (int i = 0; i < questions.length && i < answers.length; i++) {
    if (questions[i].isNotEmpty) cards.add({'q': questions[i], 'a': answers[i]});
  }
  return cards;
}

List<_QuizQuestion> _parseQuizQuestions(String text) {
  final questions = <_QuizQuestion>[];
  // Split on each question marker so we can parse blocks independently
  final parts = text.split(RegExp(r'\n(?=Q\d*[:.])'));

  for (final part in parts) {
    final trimmed = part.trim();
    if (!RegExp(r'^Q\d*[:.]\s*', caseSensitive: false).hasMatch(trimmed)) continue;

    // Question text (everything from Q: up to first option line)
    final qMatch = RegExp(r'^Q\d*[:.]\s*(.*?)(?=\n[A-D][).])', dotAll: true, caseSensitive: false)
        .firstMatch(trimmed);
    if (qMatch == null) continue;
    final question = qMatch.group(1)?.trim() ?? '';
    if (question.isEmpty) continue;

    // A/B/C/D options
    final options = <String>[];
    for (final letter in ['A', 'B', 'C', 'D']) {
      final m = RegExp('$letter[).:]\\s*(.*?)\$', multiLine: true).firstMatch(trimmed);
      if (m != null) options.add(m.group(1)?.trim() ?? '');
    }
    if (options.length < 2) continue;
    while (options.length < 4) {
      options.add('');
    }

    // Correct answer letter
    final answerMatch = RegExp(r'Answer[:.]\s*([A-D])', caseSensitive: false).firstMatch(trimmed);
    final letter = answerMatch?.group(1)?.toUpperCase() ?? 'A';
    final idx = 'ABCD'.indexOf(letter);

    questions.add(_QuizQuestion(
      question: question,
      options: options.take(4).toList(),
      correctIndex: idx < 0 ? 0 : idx,
    ));
  }
  return questions;
}

String _quizSuggestion(int percent) {
  if (percent >= 80) return 'Excellent! You have a strong grasp of this topic.';
  if (percent >= 60) return 'Good progress! Review the topics you missed.';
  if (percent >= 40) return 'Keep studying. Focus on the areas you struggled with.';
  return 'This topic needs more practice. Try re-reading and retaking the quiz.';
}

Color _quizColor(int percent) {
  if (percent >= 75) return _kGreen;
  if (percent >= 50) return _kAmber;
  return _kRed;
}

// ─── TEXT STUDY SCREEN ────────────────────────────────────────────────────────

class TextStudyScreen extends StatefulWidget {
  const TextStudyScreen({super.key});
  @override
  State<TextStudyScreen> createState() => _TextStudyScreenState();
}

class _TextStudyScreenState extends State<TextStudyScreen>
    with SingleTickerProviderStateMixin {
  // Phase: 'input' | 'loading' | 'results'
  String _phase = 'input';

  final _textCtrl = TextEditingController();
  String _selectedModel = 'llama3';
  bool _isSubscribed = false;
  bool _isLoggedIn   = false;

  // Results data
  String _rawOutput  = '';
  String _errorMsg   = '';
  List<Map<String, String>>  _flashcards    = [];
  List<_QuizQuestion>        _quizQuestions = [];
  bool                       _isExporting   = false;

  // Tab controller (only used in results phase)
  TabController? _tabController;

  // Interactive quiz state
  int  _quizIndex      = 0;
  int? _selectedOption;
  bool _checked        = false;
  int  _score          = 0;
  bool _quizDone       = false;

  @override
  void initState() {
    super.initState();
    _loadAuth();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadAuth() async {
    final results = await Future.wait([
      ApiService.isLoggedIn(),
      ApiService.isSubscribed(),
    ]);
    if (mounted) {
      setState(() {
        _isLoggedIn   = results[0];
        _isSubscribed = results[1];
      });
    }
  }

  // ─── ANALYSE ──────────────────────────────────────────────────────────────

  Future<void> _analyse() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final model = _kModels.firstWhere((m) => m.id == _selectedModel);
    setState(() => _phase = 'loading');

    final result = await ApiService.processText(
      text: text,
      model: model.isPro ? _selectedModel : 'local',
      localModelName: _selectedModel,
    );

    if (!mounted) return;

    if (result.containsKey('error')) {
      setState(() {
        _errorMsg = result['error'] as String;
        _phase    = 'input';
      });
      _showSnack(_errorMsg);
      return;
    }

    final output = result['output'] as String? ?? '';
    final cards  = _parseFlashcards(_extractSection(output, 'FLASHCARDS'));
    final quiz   = _parseQuizQuestions(_extractSection(output, 'QUIZ'));

    // Save session
    await ApiService.addSession({
      'id':         DateTime.now().millisecondsSinceEpoch.toString(),
      'type':       'study',
      'timestamp':  DateTime.now().toIso8601String(),
      'input_text': text.length > 100 ? '${text.substring(0, 100)}...' : text,
      'models':     [_selectedModel],
      'result':     result,
    });

    _tabController?.dispose();
    _tabController = TabController(length: 3, vsync: this);

    setState(() {
      _rawOutput    = output;
      _flashcards   = cards;
      _quizQuestions = quiz;
      _phase        = 'results';
      // Reset quiz state for this new session
      _quizIndex      = 0;
      _selectedOption = null;
      _checked        = false;
      _score          = 0;
      _quizDone       = false;
    });
  }

  // ─── PDF EXPORT ───────────────────────────────────────────────────────────

  Future<void> _exportFlashcardsToPdf() async {
    if (_flashcards.isEmpty) {
      _showSnack('No flashcards to export');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final modelLabel = _kModels.firstWhere((m) => m.id == _selectedModel).label;
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(
              color: PdfColor(0.31, 0.27, 0.90),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Text(
              'Flashcards — $modelLabel',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          ..._flashcards.asMap().entries.map((e) {
            final i    = e.key;
            final card = e.value;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Card ${i + 1}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Q: ${card['q'] ?? ''}',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor(0.31, 0.27, 0.90),
                    ),
                  ),
                  pw.Divider(color: PdfColors.grey300, height: 12),
                  pw.Text(
                    'A: ${card['a'] ?? ''}',
                    style: const pw.TextStyle(
                      fontSize: 13,
                      color: PdfColor(0.06, 0.72, 0.51),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ));
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'flashcards_${_selectedModel}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _onSavePdfTapped() async {
    if (_isLoggedIn) {
      await _exportFlashcardsToPdf();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Save Flashcards?',
            style: TextStyle(fontWeight: FontWeight.w800, color: _kIndigoDark),
          ),
          content: const Text(
            'Export these flashcards from your current session as a PDF? '
            'Log in to save progress to your account.',
            style: TextStyle(color: _kText2, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _kText2)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Export PDF'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) await _exportFlashcardsToPdf();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _kIndigoDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kIndigoDark),
          onPressed: () {
            if (_phase == 'results') {
              setState(() => _phase = 'input');
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _phase == 'input'   ? 'Study from Text'
              : _phase == 'loading' ? 'Analysing...'
              : 'Study Results',
          style: const TextStyle(
            color: _kIndigoDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _phase == 'input'
            ? _buildInputPhase()
            : _phase == 'loading'
                ? _buildLoadingPhase()
                : _buildResultsPhase(),
      ),
    );
  }

  // ─── INPUT PHASE ──────────────────────────────────────────────────────────

  Widget _buildInputPhase() {
    return SingleChildScrollView(
      key: const ValueKey('input'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kIndigo, _kPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _kIndigo.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.white, size: 32),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type or Paste Your Text',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Get a summary, flashcards, and quiz',
                          style: TextStyle(
                              color: Color(0xFFE0E7FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Text input
          Container(
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _textCtrl,
              maxLines: 8,
              minLines: 5,
              style: const TextStyle(
                  fontSize: 14, color: _kText, height: 1.6),
              decoration: InputDecoration(
                hintText:
                    'Paste your notes, textbook excerpt, or any study material here...',
                hintStyle:
                    const TextStyle(color: _kText2, fontSize: 14),
                contentPadding: const EdgeInsets.all(18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _kSurface,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Model picker
          _buildModelPicker(),

          const SizedBox(height: 28),

          // Analyse button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (_, val, __) {
              final enabled = val.text.trim().isNotEmpty;
              return SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: enabled ? _analyse : null,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('Analyse with AI',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enabled ? _kIndigoDark : _kSurface2,
                    foregroundColor: enabled ? Colors.white : _kText2,
                    elevation: enabled ? 0 : 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              'This may take up to 60 seconds for longer texts',
              style: TextStyle(color: _kText2, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModelPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose AI Model',
            style: TextStyle(
                color: _kIndigoDark,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Free models run locally · Pro requires subscription',
            style: TextStyle(color: _kText2, fontSize: 12)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kModels.map((m) {
              final isSelected = _selectedModel == m.id;
              final locked = m.isPro && !_isSubscribed;
              return GestureDetector(
                onTap: locked ? null : () => setState(() => _selectedModel = m.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kIndigo
                        : locked
                            ? _kSurface2
                            : _kSurface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected
                          ? _kIndigo
                          : locked
                              ? _kBorder
                              : _kBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _kIndigo.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locked) ...[
                        const Icon(Icons.lock_rounded,
                            size: 12, color: _kText2),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        m.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : locked
                                  ? _kText2
                                  : _kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (m.isPro && !locked) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _kAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: _kAmber)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── LOADING PHASE ────────────────────────────────────────────────────────

  Widget _buildLoadingPhase() {
    final label = _kModels.firstWhere((m) => m.id == _selectedModel).label;
    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kIndigo, _kPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kIndigo.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Analysing your text',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kIndigoDark)),
            const SizedBox(height: 8),
            Text('Running $label — this may take a moment',
                style: const TextStyle(color: _kText2, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── RESULTS PHASE ────────────────────────────────────────────────────────

  Widget _buildResultsPhase() {
    final tc = _tabController!;
    return Column(
      key: const ValueKey('results'),
      children: [
        Container(
          color: _kSurface,
          child: TabBar(
            controller: tc,
            indicatorColor: _kIndigo,
            indicatorWeight: 3,
            labelColor: _kIndigo,
            unselectedLabelColor: _kText2,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Flashcards'),
              Tab(text: 'Quiz'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tc,
            children: [
              _buildSummaryTab(),
              _buildFlashcardsTab(),
              _buildQuizTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── SUMMARY TAB ──────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    final summary = _extractSection(_rawOutput, 'SUMMARY');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kIndigo.withValues(alpha: 0.06),
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
                    color: _kIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.summarize_rounded, color: _kIndigo, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Summary',
                    style: TextStyle(
                        color: _kIndigo,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ]),
              const Divider(color: _kBorder, height: 22),
              Text(
                summary.isEmpty ? 'No summary available.' : summary,
                style: const TextStyle(
                    fontSize: 15, color: _kText, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FLASHCARDS TAB ───────────────────────────────────────────────────────

  Widget _buildFlashcardsTab() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.style_rounded, color: _kPurple, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Flashcards',
                      style: TextStyle(
                          color: _kPurple,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                Text('${_flashcards.length} cards',
                    style: const TextStyle(color: _kText2, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            if (_flashcards.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.style_outlined,
                          size: 48, color: _kText2.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text('No flashcards in this session',
                          style: TextStyle(color: _kText2)),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_flashcards.length, (i) {
                final card = _flashcards[i];
                return _StudyFlipCard(
                  question: card['q'] ?? '',
                  answer: card['a'] ?? '',
                  index: i,
                );
              }),

            const SizedBox(height: 20),

            // Save as PDF button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isExporting ? null : _onSavePdfTapped,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kIndigo))
                    : const Icon(Icons.picture_as_pdf_rounded,
                        color: _kIndigo),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Save Flashcards as PDF',
                  style: const TextStyle(
                      color: _kIndigo, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: _kIndigo, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Exports current session flashcards only',
                style: TextStyle(color: _kText2, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── QUIZ TAB ─────────────────────────────────────────────────────────────

  Widget _buildQuizTab() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: _quizQuestions.isEmpty
          ? _buildQuizEmpty()
          : _quizDone
              ? (_isLoggedIn ? _buildQuizEndScreen() : _buildQuizLoginWall())
              : _buildQuizQuestion(),
    );
  }

  Widget _buildQuizEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined,
                size: 48, color: _kText2.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Could not generate quiz questions',
                style: TextStyle(color: _kText2, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text('Try a longer or more detailed text',
                style: TextStyle(color: _kText2, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizQuestion() {
    final q     = _quizQuestions[_quizIndex];
    final total = _quizQuestions.length;
    final progress = (_quizIndex + 1) / total;

    final optionLabels = ['A', 'B', 'C', 'D'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: _kSurface2,
                    valueColor: const AlwaysStoppedAnimation(_kIndigo),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_quizIndex + 1} / $total',
                style: const TextStyle(
                    color: _kText2,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Question card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kIndigo.withValues(alpha: 0.08), _kPurple.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kIndigo.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Question ${_quizIndex + 1}',
                      style: const TextStyle(
                          color: _kIndigo,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ),
                const SizedBox(height: 12),
                Text(
                  q.question,
                  style: const TextStyle(
                      color: _kText,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Options
          ...List.generate(4, (i) {
            final label   = optionLabels[i];
            final text    = i < q.options.length ? q.options[i] : '';
            if (text.isEmpty) return const SizedBox.shrink();

            final isSelected = _selectedOption == i;
            final isCorrect  = i == q.correctIndex;

            Color bgColor     = _kSurface;
            Color borderColor = _kBorder;
            Color labelColor  = _kText2;
            Color textColor   = _kText;

            if (_checked) {
              if (isCorrect) {
                bgColor     = _kGreen.withValues(alpha: 0.1);
                borderColor = _kGreen;
                labelColor  = _kGreen;
                textColor   = _kGreen;
              } else if (isSelected) {
                bgColor     = _kRed.withValues(alpha: 0.08);
                borderColor = _kRed;
                labelColor  = _kRed;
                textColor   = _kRed;
              }
            } else if (isSelected) {
              bgColor     = _kIndigo.withValues(alpha: 0.08);
              borderColor = _kIndigo;
              labelColor  = _kIndigo;
              textColor   = _kText;
            }

            return GestureDetector(
              onTap: _checked
                  ? null
                  : () => setState(() => _selectedOption = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: labelColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(label,
                            style: TextStyle(
                                color: labelColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.4)),
                    ),
                    if (_checked && isCorrect)
                      const Icon(Icons.check_circle_rounded,
                          color: _kGreen, size: 20),
                    if (_checked && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded,
                          color: _kRed, size: 20),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Check Answer / Next button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _checked
                  ? () {
                      // Go to next question or finish
                      if (_quizIndex + 1 < _quizQuestions.length) {
                        setState(() {
                          _quizIndex++;
                          _selectedOption = null;
                          _checked        = false;
                        });
                      } else {
                        final percent = _quizQuestions.isNotEmpty
                            ? (_score / _quizQuestions.length * 100).round()
                            : 0;
                        if (_isLoggedIn) {
                          ApiService.saveQuizResult(
                            modelName: _selectedModel,
                            score: _score,
                            total: _quizQuestions.length,
                          );
                        }
                        setState(() => _quizDone = true);
                         percent; // suppress unused warning
                      }
                    }
                  : _selectedOption != null
                      ? () {
                          final correct =
                              _selectedOption == _quizQuestions[_quizIndex].correctIndex;
                          setState(() {
                            _checked = true;
                            if (correct) _score++;
                          });
                        }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _checked ? _kGreen : _kIndigoDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kSurface2,
                disabledForegroundColor: _kText2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _checked
                    ? (_quizIndex + 1 < _quizQuestions.length
                        ? 'Next Question'
                        : 'See Results')
                    : 'Check Answer',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuizEndScreen() {
    final total   = _quizQuestions.length;
    final percent = total > 0 ? (_score / total * 100).round() : 0;
    final color   = _quizColor(percent);
    final suggestion = _quizSuggestion(percent);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Score circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$percent%',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: color)),
                const Text('Score',
                    style: TextStyle(color: _kText2, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('Quiz Complete!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kIndigoDark)),
          const SizedBox(height: 6),
          Text('$_score out of $total correct',
              style: const TextStyle(color: _kText2, fontSize: 15)),

          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? _score / total : 0,
              minHeight: 10,
              backgroundColor: _kSurface2,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),

          const SizedBox(height: 20),

          // Suggestion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(suggestion,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.4)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text('Result saved to your profile',
              style: TextStyle(color: _kText2, fontSize: 12)),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _quizIndex      = 0;
                      _selectedOption = null;
                      _checked        = false;
                      _score          = 0;
                      _quizDone       = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: _kIndigo),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Retake Quiz',
                      style: TextStyle(
                          color: _kIndigo, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _phase = 'input'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kIndigoDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('New Analysis',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuizLoginWall() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child:
              Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child)),
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
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kIndigo.withValues(alpha: 0.15),
                        _kPurple.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.lock_rounded, color: _kIndigo, size: 52),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Login to view your report',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kIndigoDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Sign in to see your quiz score, track your progress, and get personalised study suggestions.',
                style: TextStyle(color: _kText2, fontSize: 14, height: 1.5),
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
                style: TextStyle(color: _kText2, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dart requires a non-void expression — use this helper to silence the lint
// ignore: avoid_returning_null_for_void
Never get () => throw UnimplementedError();

// ─── STUDY FLIP CARD ──────────────────────────────────────────────────────────

class _StudyFlipCard extends StatefulWidget {
  final String question;
  final String answer;
  final int    index;
  const _StudyFlipCard({
    required this.question,
    required this.answer,
    required this.index,
  });
  @override
  State<_StudyFlipCard> createState() => _StudyFlipCardState();
}

class _StudyFlipCardState extends State<_StudyFlipCard>
    with SingleTickerProviderStateMixin {
  bool _showAnswer = false;
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        duration: const Duration(milliseconds: 120), vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
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
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _showAnswer
                ? _kPurple.withValues(alpha: 0.07)
                : _kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _showAnswer ? _kPurple : _kBorder,
              width: _showAnswer ? 1.5 : 1,
            ),
            boxShadow: _showAnswer
                ? [
                    BoxShadow(
                      color: _kPurple.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _showAnswer
                          ? _kPurple.withValues(alpha: 0.15)
                          : _kSurface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Q${widget.index + 1}',
                      style: TextStyle(
                        color: _showAnswer ? _kPurple : _kText2,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _showAnswer ? 'Tap to hide' : 'Tap to reveal',
                    style: const TextStyle(color: _kText2, fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _showAnswer ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _showAnswer ? _kPurple : _kText2,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.question,
                style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.4),
              ),
              if (_showAnswer) ...[
                const Divider(color: _kBorder, height: 18),
                Text(
                  widget.answer,
                  style: const TextStyle(
                      color: _kGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
