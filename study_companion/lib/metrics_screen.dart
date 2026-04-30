import 'package:flutter/material.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  static const _kIndigo     = Color(0xFF4F46E5);
  static const _kIndigoDark = Color(0xFF1E1B4B);
  static const _kPurple     = Color(0xFF7C3AED);
  static const _kGreen      = Color(0xFF10B981);
  static const _kAmber      = Color(0xFFF59E0B);
  static const _kBg         = Color(0xFFF0F2FF);
  static const _kSurface    = Color(0xFFFFFFFF);
  static const _kBorder     = Color(0xFFE5E7EB);

  // ── metric definitions: key, label, higher-is-better, description, formula ──
  static const _metricDefs = [
    _MetricDef(
      key: 'flesch_reading_ease',
      label: 'Flesch Reading Ease',
      higherBetter: true,
      description:
          'Measures how easy a text is to read. Higher scores mean simpler, '
          'more readable prose.',
      formula: '206.835 − 1.015 × (words ÷ sentences) − 84.6 × (syllables ÷ words)',
      ranges: '90–100 Very Easy  ·  70–90 Easy  ·  50–70 Standard  ·  0–50 Difficult',
    ),
    _MetricDef(
      key: 'word_count',
      label: 'Word Count',
      higherBetter: true,
      description:
          'Total words in the AI response. More words generally mean a more '
          'comprehensive answer.',
      formula: 'Count of all whitespace-separated tokens',
      ranges: 'More = more thorough coverage of the topic',
    ),
    _MetricDef(
      key: 'sentence_count',
      label: 'Sentence Count',
      higherBetter: true,
      description:
          'Number of sentences in the response. Indicates structural detail.',
      formula: 'Count of segments ending in . ! ?',
      ranges: 'More sentences = finer breakdown of ideas',
    ),
    _MetricDef(
      key: 'avg_words_per_sentence',
      label: 'Avg Words / Sentence',
      higherBetter: false,
      description:
          'Average sentence length. Shorter sentences are generally clearer; '
          'very long sentences can be hard to follow.',
      formula: 'word_count ÷ sentence_count',
      ranges: 'Ideal: 15–20 words. Lower = more readable',
    ),
    _MetricDef(
      key: 'keyword_coverage_percent',
      label: 'Keyword Coverage %',
      higherBetter: true,
      description:
          'Percentage of your original keywords that appear in the response. '
          'Higher = the model addressed more of your key concepts.',
      formula: '(keywords found ÷ total keywords) × 100',
      ranges: '80–100% Excellent  ·  60–80% Good  ·  <60% Missing key topics',
    ),
    _MetricDef(
      key: 'rouge_1',
      label: 'ROUGE-1',
      higherBetter: true,
      description:
          'Unigram (single-word) overlap between the response and the original '
          'text. Measures basic vocabulary coverage.',
      formula: 'F1 = 2 × (precision × recall) ÷ (precision + recall) on single words',
      ranges: '0.4+ Strong  ·  0.2–0.4 Moderate  ·  <0.2 Low overlap',
    ),
    _MetricDef(
      key: 'rouge_2',
      label: 'ROUGE-2',
      higherBetter: true,
      description:
          'Bigram (two-word phrase) overlap. Higher scores indicate the model '
          'captured more specific phrasing from the source.',
      formula: 'F1 on consecutive word pairs',
      ranges: '0.2+ Strong  ·  0.1–0.2 Moderate  ·  <0.1 Low phrase overlap',
    ),
    _MetricDef(
      key: 'rouge_L',
      label: 'ROUGE-L',
      higherBetter: true,
      description:
          'Longest Common Subsequence overlap. Captures sentence-level '
          'structure and fluency, not just exact n-gram matches.',
      formula: 'F1 based on longest common subsequence length',
      ranges: '0.3+ Strong  ·  0.15–0.3 Moderate  ·  <0.15 Low structural match',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;

    // Support both single-model (legacy) and multi-model paths
    final Map<String, Map<String, dynamic>> allMetrics;
    if (args?['allMetrics'] != null) {
      allMetrics = Map<String, Map<String, dynamic>>.from(
        (args!['allMetrics'] as Map).map(
          (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
        ),
      );
    } else {
      final single = (args?['metrics'] ?? {}) as Map<String, dynamic>;
      allMetrics = {'Model': single};
    }

    final models = allMetrics.keys.toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          models.length == 1 ? 'NLP Metrics' : 'Metrics Comparison',
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: _kIndigo,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_kIndigo, _kPurple]),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (models.length > 1)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${models.length} models',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTable(models, allMetrics),
            const SizedBox(height: 28),
            _buildLegend(),
            const SizedBox(height: 28),
            _buildDescriptions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Comparison table ────────────────────────────────────────────────────────

  Widget _buildTable(
      List<String> models, Map<String, Map<String, dynamic>> allMetrics) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: _kIndigo.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableHeader(models),
                const Divider(height: 1, color: _kBorder),
                ...List.generate(_metricDefs.length, (i) {
                  final def = _metricDefs[i];
                  final values = models.map((m) {
                    final raw = allMetrics[m]?[def.key];
                    return raw != null ? (raw as num).toDouble() : null;
                  }).toList();

                  // Find best index
                  int? bestIdx;
                  if (models.length > 1) {
                    double? bestVal;
                    for (int j = 0; j < values.length; j++) {
                      final v = values[j];
                      if (v == null) continue;
                      if (bestVal == null) {
                        bestVal = v;
                        bestIdx = j;
                      } else {
                        final isBetter =
                            def.higherBetter ? v > bestVal : v < bestVal;
                        if (isBetter) { bestVal = v; bestIdx = j; }
                      }
                    }
                  }

                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, color: _kBorder),
                      _buildTableRow(def, models, values, bestIdx, i.isOdd),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(List<String> models) {
    return Container(
      color: _kIndigo.withValues(alpha: 0.06),
      child: Row(
        children: [
          const SizedBox(
            width: 160,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text('METRIC',
                  style: TextStyle(
                      color: _kIndigo,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
            ),
          ),
          ...models.map((m) => SizedBox(
                width: 110,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(
                    m.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _kIndigoDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTableRow(_MetricDef def, List<String> models,
      List<double?> values, int? bestIdx, bool shaded) {
    return Container(
      color: shaded ? _kIndigo.withValues(alpha: 0.02) : _kSurface,
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                def.label,
                style: const TextStyle(
                    color: _kIndigoDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ...List.generate(models.length, (j) {
            final v = values[j];
            final isBest = bestIdx == j;
            final display = v == null
                ? '—'
                : def.key == 'keyword_coverage_percent'
                    ? '${v.toStringAsFixed(1)}%'
                    : def.key == 'word_count' || def.key == 'sentence_count'
                        ? v.toInt().toString()
                        : v.toStringAsFixed(
                            v < 2 ? 3 : 1);

            return SizedBox(
              width: 110,
              child: Container(
                margin: const EdgeInsets.all(4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isBest
                      ? _kGreen.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isBest
                      ? Border.all(color: _kGreen.withValues(alpha: 0.4))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      display,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isBest ? _kGreen : const Color(0xFF374151),
                        fontSize: 13,
                        fontWeight:
                            isBest ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          color: _kGreen, size: 12),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Legend ──────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: _kGreen, size: 13),
              SizedBox(width: 5),
              Text('Best value in each row',
                  style: TextStyle(
                      color: _kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Lower is better for Avg Words/Sentence; higher is better for all other metrics.',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ── Metric descriptions ──────────────────────────────────────────────────────

  Widget _buildDescriptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'METRIC EXPLANATIONS',
          style: TextStyle(
              color: _kIndigoDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2),
        ),
        const SizedBox(height: 14),
        ..._metricDefs.map((def) => _MetricDescription(def: def)),
      ],
    );
  }
}

// ── Data class ───────────────────────────────────────────────────────────────

class _MetricDef {
  final String key;
  final String label;
  final bool higherBetter;
  final String description;
  final String formula;
  final String ranges;
  const _MetricDef({
    required this.key,
    required this.label,
    required this.higherBetter,
    required this.description,
    required this.formula,
    required this.ranges,
  });
}

// ── Description card ─────────────────────────────────────────────────────────

class _MetricDescription extends StatefulWidget {
  final _MetricDef def;
  const _MetricDescription({required this.def});
  @override
  State<_MetricDescription> createState() => _MetricDescriptionState();
}

class _MetricDescriptionState extends State<_MetricDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MetricsScreen._kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? MetricsScreen._kIndigo.withValues(alpha: 0.3)
                : MetricsScreen._kBorder,
          ),
          boxShadow: _expanded
              ? [
                  BoxShadow(
                    color: MetricsScreen._kIndigo.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MetricsScreen._kIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    def.higherBetter
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: def.higherBetter
                        ? MetricsScreen._kGreen
                        : MetricsScreen._kAmber,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    def.label,
                    style: const TextStyle(
                        color: MetricsScreen._kIndigoDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: MetricsScreen._kIndigo,
                  size: 18,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                        height: 1, color: MetricsScreen._kBorder),
                    const SizedBox(height: 12),
                    Text(def.description,
                        style: const TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 12,
                            height: 1.55)),
                    const SizedBox(height: 10),
                    _infoRow('Formula', def.formula,
                        MetricsScreen._kIndigo),
                    const SizedBox(height: 6),
                    _infoRow('Ranges', def.ranges, MetricsScreen._kAmber),
                    const SizedBox(height: 6),
                    _infoRow(
                      'Better when',
                      def.higherBetter ? 'Higher ↑' : 'Lower ↓',
                      def.higherBetter
                          ? MetricsScreen._kGreen
                          : MetricsScreen._kAmber,
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  height: 1.4)),
        ),
      ],
    );
  }
}
