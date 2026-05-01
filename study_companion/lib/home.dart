import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'apiservice.dart';

// ─── FLASHCARD DATA ───────────────────────────────────────────────────────────

class _SavedFlashcard {
  final String question;
  final String answer;
  final String modelName;
  const _SavedFlashcard({
    required this.question,
    required this.answer,
    required this.modelName,
  });
}

// ─── HOME SCREEN ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading     = false;
  bool _isHovered     = false;
  int  _hoveredIndex  = -1;

  List<_SavedFlashcard>      _flashcards      = [];
  bool                       _flashcardsLoaded = false;
  List<Map<String, dynamic>> _quizResults     = [];
  bool                       _isExporting     = false;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
    _loadQuizResults();
  }

  Future<void> _loadQuizResults() async {
    final results = await ApiService.getQuizResults();
    if (mounted) setState(() => _quizResults = results);
  }

  Future<void> _loadFlashcards() async {
    final pinned = await ApiService.getSavedFlashcards();
    final cards  = <_SavedFlashcard>[];

    for (final p in pinned) {
      if (cards.length >= 20) break;
      final q = p['question'] as String? ?? '';
      if (q.isNotEmpty) {
        cards.add(_SavedFlashcard(
          question: q,
          answer: p['answer'] as String? ?? '',
          modelName: p['model'] as String? ?? 'AI',
        ));
      }
    }

    if (mounted) {
      setState(() {
        _flashcards       = cards;
        _flashcardsLoaded = true;
      });
    }
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _isLoading = true);
    final response = await ApiService.uploadAndProcess(
      file: file,
      model: 'local',
      localModelName: 'llama3',
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    final extractedText =
        response['extracted_text'] as String? ??
        response['output'] as String? ?? '';

    if (extractedText.isNotEmpty) {
      setState(() => _isLoading = true);
      final compareResult = await ApiService.compareModels(
        text: extractedText,
        models: ['llama3', 'mistral', 'phi3', 'Gemma'],
      );
      setState(() => _isLoading = false);

      await ApiService.addSession({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'compare',
        'timestamp': DateTime.now().toIso8601String(),
        'input_text': '[File: ${picked.name}]',
        'models': ['llama3', 'mistral', 'phi3', 'Gemma'],
        'result': compareResult,
      });

      if (!mounted) return;
      Navigator.pushNamed(context, '/compare', arguments: {
        'preloaded': true,
        'result': compareResult,
        'originalText': extractedText,
      });
    } else {
      await ApiService.addSession({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'chat',
        'timestamp': DateTime.now().toIso8601String(),
        'input_text': '[File: ${picked.name}]',
        'models': ['llama3'],
        'result': response,
      });
      if (!mounted) return;
      Navigator.pushNamed(context, '/results', arguments: {
        'result': response,
        'originalText': picked.name,
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: _LoadingWidget())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildInputMethods(),
                    const SizedBox(height: 24),
                    _buildFlashcardSection(),
                    const SizedBox(height: 24),
                    _buildRecentQuizzes(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Study Companion',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              fontSize: 18,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: Color(0xFFFDE047), size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Multi-AI Learning Assistant',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE0E7FF),
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isHovered
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isHovered
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 12)
                      ]
                    : [],
              ),
              child: Icon(
                Icons.account_circle_outlined,
                color: _isHovered ? const Color(0xFF4F46E5) : Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── INPUT METHODS ────────────────────────────────────────────────────────────

  Widget _buildInputMethods() {
    final List<Map<String, dynamic>> methods = [
      {
        'icon': Icons.edit_rounded,
        'label': 'Type Text',
        'desc': 'Paste or type notes',
        'baseColor': const Color(0xFF4F46E5),
        'onTap': () => Navigator.pushNamed(context, '/text'),
      },
      {
        'icon': Icons.upload_file_rounded,
        'label': 'Upload File',
        'desc': 'PDF, DOCX, TXT',
        'baseColor': const Color(0xFF0EA5E9),
        'onTap': _pickFile,
      },
      {
        'icon': Icons.camera_alt_rounded,
        'label': 'Take Photo',
        'desc': 'Scan notes or textbook',
        'baseColor': const Color(0xFF22C55E),
        'onTap': () => Navigator.pushNamed(context, '/camera'),
      },
      {
        'icon': Icons.mic_rounded,
        'label': 'Voice Input',
        'desc': 'Speak your question',
        'baseColor': const Color(0xFFF97316),
        'onTap': () => Navigator.pushNamed(context, '/voice'),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: methods.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) {
            final base = methods[index]['baseColor'] as Color;
            final isHovered = _hoveredIndex == index;
            return MouseRegion(
              onEnter: (_) => setState(() => _hoveredIndex = index),
              onExit: (_) => setState(() => _hoveredIndex = -1),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: methods[index]['onTap'] as VoidCallback,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: isHovered
                      ? (Matrix4.identity()..translate(0.0, -7.0, 0.0))
                      : Matrix4.identity(),
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: base.withValues(alpha: 1.0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: base.withValues(
                            alpha: isHovered ? 0.5 : 0.3),
                        blurRadius: isHovered ? 18 : 8,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          methods[index]['icon'] as IconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        methods[index]['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        methods[index]['desc'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── PDF EXPORT ───────────────────────────────────────────────────────────────

  Future<void> _exportFlashcardsToPdf() async {
    if (_flashcards.isEmpty) {
      _showSnack('No flashcards to export');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final indigo  = PdfColor.fromHex('#4F46E5');
      final grey    = PdfColor.fromHex('#6B7280');
      final lightBg = PdfColor.fromHex('#EEF2FF');
      final border  = PdfColor.fromHex('#E5E7EB');
      final divider = PdfColor.fromHex('#F3F4F6');
      final green   = PdfColor.fromHex('#10B981');

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Study Companion',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: indigo,
                    ),
                  ),
                  pw.Text(
                    'Flashcard Export',
                    style: pw.TextStyle(fontSize: 11, color: grey),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Exported ${DateTime.now().toString().substring(0, 10)}  •  '
                '${_flashcards.length} card${_flashcards.length == 1 ? '' : 's'}',
                style: pw.TextStyle(fontSize: 9, color: grey),
              ),
              pw.Container(height: 1, color: border, margin: const pw.EdgeInsets.symmetric(vertical: 10)),
            ],
          ),
          build: (_) => _flashcards.asMap().entries.map((entry) {
            final idx  = entry.key;
            final card = entry.value;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: border),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Card header band
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: lightBg,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft:  pw.Radius.circular(7),
                        topRight: pw.Radius.circular(7),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Card ${idx + 1}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: indigo,
                          ),
                        ),
                        pw.Text(
                          card.modelName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 9, color: grey),
                        ),
                      ],
                    ),
                  ),
                  // Question
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Q',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: indigo,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(card.question, style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  pw.Container(height: 1, color: divider),
                  // Answer
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'A',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: green,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(card.answer, style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'flashcards_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── FLASHCARD SECTION ───────────────────────────────────────────────────────

  Widget _buildFlashcardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Saved Flashcards',
              style: TextStyle(
                  color: Color(0xFF1E1B4B),
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_flashcards.isNotEmpty) ...[
              GestureDetector(
                onTap: _isExporting ? null : _exportFlashcardsToPdf,
                child: _isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded,
                              size: 14, color: Color(0xFF4F46E5)),
                          SizedBox(width: 4),
                          Text('Export PDF',
                              style: TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _loadFlashcards,
                child: const Icon(Icons.refresh_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(width: 6),
              Text(
                '${_flashcards.length} card${_flashcards.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (!_flashcardsLoaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  color: Color(0xFF4F46E5), strokeWidth: 2.5),
            ),
          )
        else if (_flashcards.isEmpty)
          _buildEmptyFlashcards()
        else
          _FlashcardCarousel(cards: _flashcards),
      ],
    );
  }

  Widget _buildEmptyFlashcards() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/compare'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.style_rounded,
                  size: 28, color: Colors.white),
            ),
            const SizedBox(height: 14),
            const Text('No flashcards yet',
                style: TextStyle(
                    color: Color(0xFF1E1B4B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 6),
            const Text(
              'Tap to analyse text and generate flashcards',
              style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Start Analysing',
                  style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RECENT QUIZZES ───────────────────────────────────────────────────────────

  static String _quizSuggestion(int percent) {
    if (percent >= 90) return 'Outstanding! You\'ve mastered this material.';
    if (percent >= 75) return 'Great job! Review any questions you missed.';
    if (percent >= 60) return 'Good progress. Focus on strengthening weak areas.';
    if (percent >= 40) return 'Keep practising — review the material carefully.';
    return 'Needs attention. Consider revisiting the content.';
  }

  static Color _quizColor(int percent) {
    if (percent >= 75) return const Color(0xFF10B981);
    if (percent >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  static String _formatQuizTime(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inDays   < 1)   return '${diff.inHours}h ago';
      if (diff.inDays   < 7)   return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildRecentQuizzes() {
    final recent = _quizResults.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Quizzes',
              style: TextStyle(
                color: Color(0xFF1E1B4B),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (_quizResults.isNotEmpty)
              Text(
                '${_quizResults.length} total',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_quizResults.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.quiz_outlined, size: 32, color: Color(0xFFD1D5DB)),
                SizedBox(height: 8),
                Text('No quizzes taken yet',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text('Complete a quiz to see your results here',
                    style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11)),
              ],
            ),
          ),
        ...recent.map((r) {
          final score   = r['score']     as int?    ?? 0;
          final total   = r['total']     as int?    ?? 0;
          final percent = r['percent']   as int?    ?? 0;
          final ts      = r['timestamp'] as String? ?? '';
          final model   = (r['model']    as String? ?? 'AI').toUpperCase();
          final color   = _quizColor(percent);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        model,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatQuizTime(ts),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score / $total',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'correct   ($percent%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? score / total : 0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _quizSuggestion(percent),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

}

// ─── FLASHCARD CAROUSEL ───────────────────────────────────────────────────────

class _FlashcardCarousel extends StatefulWidget {
  final List<_SavedFlashcard> cards;
  const _FlashcardCarousel({required this.cards});
  @override
  State<_FlashcardCarousel> createState() => _FlashcardCarouselState();
}

class _FlashcardCarouselState extends State<_FlashcardCarousel> {
  late PageController _pageCtrl;
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
    if (widget.cards.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.cards.length;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: _FlipCard(card: widget.cards[i]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.cards.length.clamp(0, 10),
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _current == i
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── FLIP CARD ────────────────────────────────────────────────────────────────

class _FlipCard extends StatefulWidget {
  final _SavedFlashcard card;
  const _FlipCard({required this.card});
  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutBack);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showFront) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    setState(() => _showFront = !_showFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle     = _anim.value * pi;
          final isFront   = angle < pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront
                ? _buildFront()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.card.modelName.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              const Icon(Icons.touch_app_rounded,
                  color: Colors.white54, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            widget.card.question,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Text('Tap to reveal answer',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4F46E5), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded,
                  color: Color(0xFF4F46E5), size: 14),
              SizedBox(width: 6),
              Text('Answer',
                  style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Spacer(),
              Icon(Icons.touch_app_rounded,
                  color: Color(0xFFD1D5DB), size: 16),
            ],
          ),
          const Spacer(),
          Text(
            widget.card.answer,
            style: const TextStyle(
                color: Color(0xFF1E1B4B), fontSize: 13, height: 1.45),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── MODEL CARD ───────────────────────────────────────────────────────────────

class _ModelCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color baseColor;
  final bool isFree;
  final bool isLocked;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
    required this.isFree,
    required this.isLocked,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
              0, _hovered && !widget.isLocked ? -6.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: base.withValues(alpha: 1.0), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: base.withValues(alpha: _hovered ? 0.6 : 0.35),
                blurRadius: _hovered ? 18 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Icon(widget.icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          Text(widget.subtitle,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 9),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isLocked)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        size: 10, color: Colors.white70),
                  ),
                ),
              if (widget.isSelected && !widget.isLocked)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── LOADING WIDGET ───────────────────────────────────────────────────────────

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Processing with AI',
          style: TextStyle(
              color: Color(0xFF4F46E5),
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'This may take up to 30 seconds for local models',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }
}
