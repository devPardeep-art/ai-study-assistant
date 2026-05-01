import 'package:flutter/material.dart';
import 'apiservice.dart';

// ─── DATA ─────────────────────────────────────────────────────────────────────

class _Turn {
  final String userMessage;
  final Map<String, dynamic> result;
  final bool isFollowUp;
  final DateTime timestamp;

  _Turn({
    required this.userMessage,
    required this.result,
    this.isFollowUp = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'user_message': userMessage,
        'result': result,
        'is_follow_up': isFollowUp,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _Turn.fromJson(Map<String, dynamic> j) => _Turn(
        userMessage: j['user_message'] as String? ?? '',
        result: j['result']   as Map<String, dynamic>? ?? {},
        isFollowUp: j['is_follow_up'] as bool? ?? false,
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── SCREEN ───────────────────────────────────────────────────────────────────

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  static const _kIndigo     = Color(0xFF4F46E5);
  static const _kPurple     = Color(0xFF7C3AED);
  static const _kIndigoDark = Color(0xFF1E1B4B);

  // Controllers
  final _textController      = TextEditingController();
  final _followUpController  = TextEditingController();
  final _scrollController    = ScrollController();
  final _followUpFocusNode   = FocusNode();

  // Model selection
  final _selectedModels = <String>{'llama3', 'mistral'};
  bool _isSubscribed        = false;
  int  _hoveredLocalIndex   = -1;
  int  _hoveredCloudIndex   = -1;
  bool _modelsExpanded      = false;

  // Conversation state
  final List<_Turn> _turns  = [];
  String _originalText      = '';
  String _sessionId         = '';

  // Loading
  bool _isLoading         = false; // initial run
  bool _isFollowUpLoading = false; // follow-up runs

  // Guard for arg loading
  bool _didLoadArgs = false;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArgs());
  }

  @override
  void dispose() {
    _textController.dispose();
    _followUpController.dispose();
    _scrollController.dispose();
    _followUpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkSubscription() async {
    final s = await ApiService.isSubscribed();
    if (mounted) setState(() => _isSubscribed = s);
  }

  // ─── ARG LOADING ──────────────────────────────────────────────────────────

  void _loadArgs() {
    if (_didLoadArgs) return;
    _didLoadArgs = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    // ── Preloaded from HomeScreen ──
    if (args['preloaded'] == true) {
      final text   = args['originalText'] as String? ?? '';
      final result = args['result']       as Map<String, dynamic>?;
      if (result == null) return;

      _sessionId   = DateTime.now().millisecondsSinceEpoch.toString();
      _originalText = text;
      _textController.text = text;

      final turn = _Turn(
          userMessage: text, result: result, timestamp: DateTime.now());

      setState(() {
        _turns.add(turn);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      return;
    }

    // ── Resume saved session ──
    if (args['resume_session'] == true) {
      final session = args['session'] as Map<String, dynamic>?;
      if (session == null) return;

      _sessionId    = session['id']            as String? ?? _sessionId;
      _originalText = session['original_text'] as String? ?? '';

      final models =
          (session['models'] as List?)?.map((e) => e.toString()).toSet() ??
              const <String>{};
      if (models.isNotEmpty) {
        _selectedModels
          ..clear()
          ..addAll(models);
      }

      final rawTurns = session['turns'] as List? ?? [];
      final loaded =
          rawTurns.map((t) => _Turn.fromJson(t as Map<String, dynamic>)).toList();

      setState(() {
        _turns.addAll(loaded);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  // ─── INITIAL RUN ──────────────────────────────────────────────────────────

  Future<void> _runCompare() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _snack('Please enter text to compare');
      return;
    }

    if (_sessionId.isEmpty) {
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    }
    _originalText = text;

    setState(() => _isLoading = true);

    final result = await ApiService.compareModels(
      text: text,
      models: _selectedModels.toList(),
    );

    final turn =
        _Turn(userMessage: text, result: result, timestamp: DateTime.now());

    setState(() {
      _isLoading = false;
      _turns.add(turn);
    });

    _scrollToBottom();
    await _saveSession();
  }

  // ─── FOLLOW-UP ────────────────────────────────────────────────────────────

  Future<void> _sendFollowUp() async {
    final question = _followUpController.text.trim();
    if (question.isEmpty || _isFollowUpLoading) return;

    _followUpController.clear();
    setState(() => _isFollowUpLoading = true);
    _scrollToBottom();

    // Build a chat history so each model has full context
    final messages = <Map<String, String>>[];

    if (_originalText.isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': 'Study material:\n$_originalText',
      });
      messages.add({
        'role': 'assistant',
        'content': 'I have read the study material and am ready to help.',
      });
    }

    // Include up to 3 previous follow-up Q&A pairs
    final prevFollowUps = _turns.where((t) => t.isFollowUp).toList();
    final recent = prevFollowUps.length > 3
        ? prevFollowUps.sublist(prevFollowUps.length - 3)
        : prevFollowUps;
    for (final t in recent) {
      messages.add({'role': 'user', 'content': t.userMessage});
      final prevResults = t.result['results'] as Map<String, dynamic>? ?? {};
      if (prevResults.isNotEmpty) {
        final firstOut =
            (prevResults.values.first as Map<String, dynamic>)['output']
                    as String? ??
                '';
        if (firstOut.isNotEmpty) {
          messages.add({
            'role': 'assistant',
            'content': firstOut.length > 500
                ? '${firstOut.substring(0, 500)}…'
                : firstOut,
          });
        }
      }
    }

    messages.add({'role': 'user', 'content': question});

    // Query every selected model in parallel via the chat endpoint
    final futures = _selectedModels.map((model) async {
      final sw = Stopwatch()..start();
      final res = await ApiService.sendChatMessage(
        messages: messages,
        model: 'local',
        localModelName: model,
      );
      sw.stop();
      final output = res['response'] as String? ??
          res['output'] as String? ??
          (res.containsKey('error') ? 'Error: ${res['error']}' : 'No response.');
      return MapEntry(model, <String, dynamic>{
        'output': output,
        'response_time': (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(2),
        'metrics': <String, dynamic>{},
      });
    });

    final entries = await Future.wait(futures);
    final result = {'results': Map.fromEntries(entries)};

    final turn = _Turn(
      userMessage: question,
      result: result,
      isFollowUp: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _isFollowUpLoading = false;
      _turns.add(turn);
    });

    _scrollToBottom();
    await _saveSession();
  }

  // ─── SESSION SAVING ───────────────────────────────────────────────────────

  Future<void> _saveSession() async {
    if (_turns.isEmpty) return;
    await ApiService.saveChatSession({
      'id': _sessionId,
      'type': 'compare',
      'session_type': 'conversation',
      'title': _originalText.length > 60
          ? '${_originalText.substring(0, 60)}…'
          : _originalText,
      'timestamp': _turns.first.timestamp.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'models': _selectedModels.toList(),
      'original_text': _originalText,
      'turns': _turns.map((t) => t.toJson()).toList(),
    });
  }

  // ─── MODEL TOGGLE ─────────────────────────────────────────────────────────

  void _toggleModel(String id) {
    setState(() {
      if (_selectedModels.contains(id)) {
        if (_selectedModels.length > 1) _selectedModels.remove(id);
      } else {
        _selectedModels.add(id);
      }
    });
  }

  // ─── SCROLL ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inConversation = _turns.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            // ── Initial state: text input + model selector ───────────────
            if (_isLoading)
              const Expanded(child: Center(child: _LoadingWidget()))
            else if (!inConversation)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextInput(),
                      const SizedBox(height: 20),
                      _buildLocalModels(),
                      const SizedBox(height: 16),
                      _buildCloudModels(),
                      const SizedBox(height: 8),
                      _buildSelectedSummary(),
                      const SizedBox(height: 16),
                      _buildCompareButton(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              )

            // ── Conversation state ────────────────────────────────────────
            else ...[
              _buildModelsBar(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _turns.length + (_isFollowUpLoading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _turns.length) return _buildLoadingTurnCard();
                    return _buildTurnBlock(_turns[i], i);
                  },
                ),
              ),
              _buildFollowUpBar(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final inConversation = _turns.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.2),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              splashColor: Colors.white.withValues(alpha: 0.3),
              highlightColor: Colors.white.withValues(alpha: 0.15),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
          ),
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
                        inConversation ? 'Multi-AI Session' : 'Compare Models',
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
                    Icon(
                      inConversation
                          ? Icons.forum_rounded
                          : Icons.compare_arrows_rounded,
                      color: const Color(0xFFFDE047),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  inConversation
                      ? '${_turns.length} turn${_turns.length == 1 ? '' : 's'} · ${_selectedModels.length} models'
                      : 'Select multiple models · compare side-by-side',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE0E7FF),
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // New session button (only shown in conversation mode)
          if (inConversation)
            GestureDetector(
              onTap: _confirmNewSession,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1),
                ),
                child: const Text(
                  'New',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.account_circle_outlined,
                  color: Colors.white, size: 24),
            ),
        ],
      ),
    );
  }

  // ─── MODELS BAR (conversation mode) ──────────────────────────────────────

  Widget _buildModelsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Wrap(
                spacing: 6,
                children: _selectedModels
                    .map((m) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            m.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kIndigo),
                          ),
                        ))
                    .toList(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _modelsExpanded = !_modelsExpanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _modelsExpanded ? 'Done' : 'Change',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _kIndigo,
                          fontWeight: FontWeight.w700),
                    ),
                    Icon(
                      _modelsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: _kIndigo,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_modelsExpanded) ...[
            const SizedBox(height: 12),
            _buildLocalModels(),
            const SizedBox(height: 10),
            _buildCloudModels(),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  // ─── TURN BLOCK ───────────────────────────────────────────────────────────

  Widget _buildTurnBlock(_Turn turn, int turnIndex) {
    final results    = turn.result['results']    as Map<String, dynamic>? ?? {};
    final comparison = turn.result['comparison'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── User message bubble ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: _kIndigo,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    turn.isFollowUp
                        ? turn.userMessage
                        : (turn.userMessage.length > 200
                            ? '${turn.userMessage.substring(0, 200)}…'
                            : turn.userMessage),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Model count banner (first turn only) ──────────────────────
        if (!turn.isFollowUp)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kIndigoDark, Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFFDE047), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${results.length} AI models responded simultaneously',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kIndigo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${results.length} Models',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),

        // ── Per-model cards ───────────────────────────────────────────
        ...results.entries.map((entry) {
          return _buildModelCard(
            modelName: entry.key,
            data: entry.value as Map<String, dynamic>,
            comparison: comparison,
            turnIndex: turnIndex,
            isFollowUpTurn: turn.isFollowUp,
          );
        }),

        const SizedBox(height: 8),
        // ── Compare Metrics button ─────────────────────────────────────
        if (results.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                final allMetrics = Map.fromEntries(
                  results.entries.map((e) => MapEntry(
                    e.key,
                    (e.value as Map<String, dynamic>)['metrics']
                            as Map<String, dynamic>? ??
                        {},
                  )),
                );
                Navigator.pushNamed(context, '/metrics',
                    arguments: {'allMetrics': allMetrics});
              },
              icon: const Icon(Icons.bar_chart_rounded, size: 15),
              label: const Text('Compare Metrics',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: _kIndigo,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),
        const SizedBox(height: 4),
        const Divider(color: Color(0xFFE5E7EB)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildModelCard({
    required String modelName,
    required Map<String, dynamic> data,
    required Map<String, dynamic> comparison,
    required int turnIndex,
    required bool isFollowUpTurn,
  }) {
    final metrics   = data['metrics'] as Map<String, dynamic>? ?? {};
    final output    = data['output']  as String? ?? '';
    final isError   = data.containsKey('error');
    final isWinner  = comparison['most_readable_model'] == modelName;
    final isFastest = comparison['fastest_model'] == modelName;
    final isBest    = comparison['best_keyword_coverage_model'] == modelName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? _kIndigo : const Color(0xFFE5E7EB),
          width: isWinner ? 1.5 : 1,
        ),
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
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    modelName.toUpperCase(),
                    style: const TextStyle(
                        color: _kIndigo,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(width: 6),
                if (isWinner)
                  const _Badge(label: 'Most Readable', color: _kIndigo),
                if (isFastest)
                  const _Badge(label: 'Fastest', color: Color(0xFF10A37F)),
                if (isBest)
                  const _Badge(
                      label: 'Best Coverage', color: Color(0xFFD97706)),
                const Spacer(),
              ],
            ),
          ),

          // Error
          if (isError)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(data['error'] as String,
                  style: const TextStyle(
                      color: Color(0xFFEF4444), fontSize: 12)),
            )
          else ...[
            // Metrics row (always shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  _Metric('Readability',
                      '${metrics['flesch_reading_ease'] ?? '-'}',
                      _kIndigo),
                  _vDivider(),
                  _Metric('Keywords',
                      '${metrics['keyword_coverage_percent'] ?? '-'}%',
                      const Color(0xFF10A37F)),
                  _vDivider(),
                  _Metric('ROUGE-1',
                      '${metrics['rouge_1'] ?? '-'}',
                      const Color(0xFFD97706)),
                  _vDivider(),
                  _Metric('Speed',
                      '${data['response_time'] ?? '-'}s',
                      const Color(0xFFEF4444)),
                ],
              ),
            ),

            if (output.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.summarize_rounded,
                      label: 'Summary',
                      color: _kIndigo,
                      onTap: () =>
                          _showOutputSheet(context, modelName, output, 0),
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.style_rounded,
                      label: 'Flashcards',
                      color: const Color(0xFF10A37F),
                      onTap: () =>
                          _showOutputSheet(context, modelName, output, 1),
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.quiz_rounded,
                      label: 'Quiz',
                      color: const Color(0xFFD97706),
                      onTap: () =>
                          _showOutputSheet(context, modelName, output, 2),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── LOADING TURN CARD ────────────────────────────────────────────────────

  Widget _buildLoadingTurnCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: _kIndigo, strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Models are thinking…',
            style: TextStyle(
                color: _kIndigo, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── FOLLOW-UP BAR (sticky bottom) ───────────────────────────────────────

  Widget _buildFollowUpBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: _kIndigo.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _followUpController,
                focusNode: _followUpFocusNode,
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1F2937)),
                decoration: const InputDecoration(
                  hintText: 'Ask a follow-up question…',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendFollowUp,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isFollowUpLoading
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [_kIndigo, _kPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (!_isFollowUpLoading)
                    BoxShadow(
                      color: _kIndigo.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Icon(
                _isFollowUpLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── NEW SESSION CONFIRM ──────────────────────────────────────────────────

  Future<void> _confirmNewSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start a new session?'),
        content: const Text(
            'This will clear the current conversation. Your previous session is already saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('New Session',
                  style: TextStyle(color: _kIndigo, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _turns.clear();
        _originalText = '';
        _sessionId    = '';
        _textController.clear();
        _followUpController.clear();
        _modelsExpanded = false;
      });
    }
  }

  // ─── INITIAL INPUT WIDGETS ────────────────────────────────────────────────

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Input Text'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC7D2FE), width: 2),
            boxShadow: [
              BoxShadow(
                color: _kIndigo.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _textController,
            maxLines: 5,
            style:
                const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Paste your study text here to compare across models…',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kIndigo, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalModels() {
    final modelData = {
      'llama3': ('Simple Llama 3', 'Meta', Icons.terminal_rounded, const Color(0xFF4F46E5)),
      'mistral': ('Mistral', 'Mistral AI', Icons.blur_on_rounded, const Color(0xFF0EA5E9)),
      'phi3': ('Phi-3', 'Microsoft', Icons.window_rounded, const Color(0xFF3B82F6)),
      'gemma': ('Gemma', 'Google', Icons.animation_rounded, const Color(0xFF22C55E)),
    };
    final local = ['llama3', 'mistral', 'phi3', 'gemma'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Free · Local Models'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: local.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: c.maxWidth < 600 ? 2 : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (context, i) {
                final m = local[i];
                final d = modelData[m]!;
                return MouseRegion(
                  onEnter: (_) =>
                      setState(() => _hoveredLocalIndex = i),
                  onExit: (_) =>
                      setState(() => _hoveredLocalIndex = -1),
                  child: _ModelCard(
                    name: d.$1, subtitle: d.$2, icon: d.$3,
                    baseColor: d.$4,
                    isLocked: false,
                    isSelected: _selectedModels.contains(m),
                    isHovered: _hoveredLocalIndex == i,
                    onTap: () => _toggleModel(m),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCloudModels() {
    final cloud = [
      ('openai', 'GPT-4o', 'OpenAI', Icons.cyclone_rounded, const Color(0xFF10A37F)),
      ('claude', 'Claude', 'Anthropic', Icons.architecture_rounded, const Color(0xFFD97706)),
      ('gemini', 'Gemini', 'Google', Icons.auto_awesome_rounded, const Color(0xFF4285F4)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Cloud Models'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cloud.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: c.maxWidth < 600 ? 1.4 : 2.0,
            ),
            itemBuilder: (context, i) {
              final m = cloud[i];
              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredCloudIndex = i),
                onExit: (_) => setState(() => _hoveredCloudIndex = -1),
                child: _ModelCard(
                  name: m.$2, subtitle: m.$3, icon: m.$4,
                  baseColor: m.$5,
                  isLocked: !_isSubscribed,
                  isSelected: _selectedModels.contains(m.$1),
                  isHovered: _hoveredCloudIndex == i,
                  onTap: _isSubscribed
                      ? () => _toggleModel(m.$1)
                      : () => Navigator.pushNamed(context, '/subscribe'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedSummary() {
    if (_selectedModels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      children: _selectedModels.map((m) {
        return Chip(
          label: Text(m.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _kIndigo)),
          backgroundColor: const Color(0xFFEEF2FF),
          side: const BorderSide(color: _kIndigo, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          deleteIcon: _selectedModels.length > 1
              ? const Icon(Icons.close, size: 12, color: _kIndigo)
              : null,
          onDeleted: _selectedModels.length > 1 ? () => _toggleModel(m) : null,
        );
      }).toList(),
    );
  }

  Widget _buildCompareButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _runCompare,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kIndigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.compare_arrows_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              'Compare ${_selectedModels.length} Model${_selectedModels.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: _kIndigo),
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 32,
        color: const Color(0xFFE5E7EB),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kIndigo,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showOutputSheet(
      BuildContext context, String modelName, String output, int initialTab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _OutputPage(
          modelName: modelName,
          output: output,
          initialTab: initialTab,
        ),
      ),
    );
  }
}

// ─── MODEL CARD ───────────────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  final String name, subtitle;
  final IconData icon;
  final Color baseColor;
  final bool isLocked, isSelected, isHovered;
  final VoidCallback onTap;

  const _ModelCard({
    required this.name, required this.subtitle, required this.icon,
    required this.baseColor, required this.isLocked,
    required this.isSelected, required this.isHovered, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = isHovered || isSelected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
            0, (isHovered && !isLocked) ? -4.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: isLocked ? 0.5 : 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? baseColor : baseColor.withValues(alpha: 0.8),
            width: active ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: active ? 0.5 : 0.25),
              blurRadius: active ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        Text(subtitle,
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
            if (isLocked)
              Positioned(
                right: 8, top: 8,
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
            if (isSelected && !isLocked)
              Positioned(
                right: 6, top: 6,
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
    );
  }
}

// ─── BADGE ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
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
              width: 30, height: 30,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Running All AI Models',
            style: TextStyle(
                color: Color(0xFF4F46E5),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('All models running simultaneously — please wait',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }
}

// ─── METRIC ───────────────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Metric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── ACTION BUTTON ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── OUTPUT PAGE (full-screen) ────────────────────────────────────────────────
// ─── OUTPUT PAGE (full-screen) ────────────────────────────────────────────────

class _OutputPage extends StatefulWidget {
  final String modelName;
  final String output;
  final int initialTab;

  const _OutputPage({
    required this.modelName,
    required this.output,
    required this.initialTab,
  });

  @override
  State<_OutputPage> createState() => _OutputPageState();
}

class _OutputPageState extends State<_OutputPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  int _clarityRating = 3;
  int _accuracyRating = 3;
  int _usefulnessRating = 3;
  bool _feedbackSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),

      // ── HEADER ───────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.black87),
          ),
        ),

        title: Text(
          widget.modelName.toUpperCase(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,

        // ✅ FIXED: TabBar inside AppBar
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black45,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Flashcards'),
            Tab(text: 'Quiz'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),

      // ── BODY ───────────────────────────────────────
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSummaryTab(),
          _buildFlashcardsTab(),
          _buildQuizTab(),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  // ─── SUMMARY ───────────────────────────────────────

  Widget _buildSummaryTab() {
    final text = _extractSection(widget.output, 'SUMMARY');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }

  // ─── FLASHCARDS ───────────────────────────────────

  Widget _buildFlashcardsTab() {
    final cards =
        _parseFlashcards(_extractSection(widget.output, 'FLASHCARDS'));

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: Color(0xFF4F46E5), size: 16),
              const SizedBox(width: 8),
              Text('${cards.length} cards · tap to reveal',
                  style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  for (final card in cards) {
                    if ((card['q'] ?? '').isNotEmpty &&
                        card['q'] != 'No flashcards found') {
                      await ApiService.saveFlashcard(
                        question: card['q']!,
                        answer: card['a'] ?? '',
                        modelName: widget.modelName,
                      );
                    }
                  }
                  if (context.mounted) {
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('Save All',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
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
            itemBuilder: (_, i) {
              return _FlashCard(
                question: cards[i]['q'] ?? '',
                answer: cards[i]['a'] ?? '',
                modelName: widget.modelName,
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── QUIZ ─────────────────────────────────────────

  Widget _buildQuizTab() {
    final text = _extractSection(widget.output, 'QUIZ');
    return _InteractiveQuiz(quizText: text, modelName: widget.modelName);
  }

  // ─── FEEDBACK ─────────────────────────────────────

  Widget _buildFeedbackTab() {
    if (_feedbackSubmitted) {
      return const Center(
        child: Text("Thanks for your feedback!"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _rating("Clarity", _clarityRating,
              (v) => setState(() => _clarityRating = v)),
          _rating("Accuracy", _accuracyRating,
              (v) => setState(() => _accuracyRating = v)),
          _rating("Usefulness", _usefulnessRating,
              (v) => setState(() => _usefulnessRating = v)),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              setState(() => _feedbackSubmitted = true);
            },
            child: const Text("Submit Feedback"),
          )
        ],
      ),
    );
  }

  Widget _rating(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

// ─── FLASHCARD ──────────────────────────────────────

class _FlashCard extends StatefulWidget {
  final String question;
  final String answer;
  final String modelName;

  const _FlashCard({
    required this.question,
    required this.answer,
    this.modelName = '',
  });

  @override
  State<_FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<_FlashCard> {
  bool _show = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _show = !_show),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _show
              ? const Color(0xFF4F46E5).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _show
                ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.question,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1E1B4B))),
                ),
                GestureDetector(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ApiService.saveFlashcard(
                      question: widget.question,
                      answer: widget.answer,
                      modelName: widget.modelName,
                    );
                    if (mounted) {
                      setState(() => _saved = true);
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
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      _saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                      color: _saved
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
            if (_show) ...[
              const Divider(color: Color(0xFFE5E7EB)),
              Text(widget.answer,
                  style: const TextStyle(
                      color: Color(0xFF4F46E5), fontSize: 13, height: 1.5)),
            ] else ...[
              const SizedBox(height: 4),
              const Text('Tap to reveal answer',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            ]
          ],
        ),
      ),
    );
  }
}

// ─── FLASH CARD (sheet) ───────────────────────────────────────────────────────

class _SheetFlashCard extends StatefulWidget {
  final String question, answer;
  final int index;

  const _SheetFlashCard({
    required this.question,
    required this.answer,
    required this.index,
  });

  @override
  State<_SheetFlashCard> createState() => _SheetFlashCardState();
}

class _SheetFlashCardState extends State<_SheetFlashCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _revealed
              ? const Color(0xFF4F46E5).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
              left: BorderSide(color: Color(0xFF4F46E5), width: 3)),
          boxShadow: [
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
            Text(
              'Q${widget.index + 1}',
              style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              widget.question,
              style: const TextStyle(
                  color: Color(0xFF1E1B4B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            if (_revealed) ...[
              const Divider(height: 16, color: Color(0xFFE5E7EB)),
              Text(
                widget.answer,
                style: const TextStyle(
                    color: Color(0xFF4F46E5), fontSize: 13, height: 1.5),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text('Tap to reveal answer',
                  style:
                      TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── QUIZ DATA MODEL ─────────────────────────────────────────────────────────

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

// ─── INTERACTIVE QUIZ ────────────────────────────────────────────────────────

class _InteractiveQuiz extends StatefulWidget {
  final String quizText;
  final String modelName;

  const _InteractiveQuiz({
    required this.quizText,
    required this.modelName,
  });

  @override
  State<_InteractiveQuiz> createState() => _InteractiveQuizState();
}

class _InteractiveQuizState extends State<_InteractiveQuiz> {
  static const _kIndigo = Color(0xFF4F46E5);
  static const _kGreen = Color(0xFF10B981);
  static const _kRed = Color(0xFFEF4444);
  static const _kAmber = Color(0xFFD97706);

  late List<_QuizQuestion> _questions;
  final Map<int, int> _selected = {};
  bool _submitted = false;
  final ScrollController _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _questions = _parseQuizQuestions(widget.quizText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _score => _questions.asMap().entries
      .where((e) => _selected[e.key] == e.value.correctIndex)
      .length;

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return SingleChildScrollView(
        controller: _ctrl,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SelectableText(
            widget.quizText,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF374151), height: 1.65),
          ),
        ),
      );
    }

    return ListView(
      controller: _ctrl,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
              backgroundColor: _kIndigo,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _selected.length == _questions.length
                  ? 'Submit Quiz'
                  : 'Answer all questions (${_selected.length}/${_questions.length})',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _selected.clear();
              _submitted = false;
            }),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retake Quiz'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kIndigo,
              side: const BorderSide(color: Color(0xFF4F46E5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard() {
    final score = _score;
    final total = _questions.length;
    final pct = (score / total * 100).round();

    final Color color;
    final String label;
    if (pct >= 80) {
      color = _kGreen;
      label = 'Excellent!';
    } else if (pct >= 60) {
      color = const Color(0xFF3B82F6);
      label = 'Good job!';
    } else if (pct >= 40) {
      color = _kAmber;
      label = 'Keep practicing';
    } else {
      color = _kRed;
      label = 'Review the material';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '$score / $total',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 44,
                height: 1.1),
          ),
          const SizedBox(height: 4),
          Text('$pct% correct',
              style: TextStyle(
                  color: color.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildQuestion(int qi) {
    final q = _questions[qi];
    final selected = _selected[qi];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${qi + 1}',
                    style: const TextStyle(
                        color: _kIndigo,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    q.question,
                    style: const TextStyle(
                        color: Color(0xFF1E1B4B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(
              q.options.length, (oi) => _buildOption(qi, oi, q, selected)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildOption(int qi, int oi, _QuizQuestion q, int? selected) {
    final isSelected = selected == oi;
    final isCorrect = oi == q.correctIndex;

    Color borderColor = const Color(0xFFE5E7EB);
    Color bgColor = Colors.transparent;
    Color textColor = const Color(0xFF374151);
    Color labelBg = const Color(0xFFF3F4F6);
    Color labelFg = const Color(0xFF6B7280);
    Widget? trailing;

    if (_submitted) {
      if (isCorrect) {
        borderColor = _kGreen;
        bgColor = _kGreen.withValues(alpha: 0.08);
        textColor = const Color(0xFF065F46);
        labelBg = _kGreen;
        labelFg = Colors.white;
        trailing = const Icon(Icons.check_circle_rounded,
            color: _kGreen, size: 18);
      } else if (isSelected) {
        borderColor = _kRed;
        bgColor = _kRed.withValues(alpha: 0.08);
        textColor = const Color(0xFF991B1B);
        labelBg = _kRed;
        labelFg = Colors.white;
        trailing =
            const Icon(Icons.cancel_rounded, color: _kRed, size: 18);
      }
    } else if (isSelected) {
      borderColor = _kIndigo;
      bgColor = const Color(0xFFEEF2FF);
      textColor = _kIndigo;
      labelBg = _kIndigo;
      labelFg = Colors.white;
    }

    final optionLabel = String.fromCharCode('A'.codeUnitAt(0) + oi);

    return GestureDetector(
      onTap: _submitted ? null : () => setState(() => _selected[qi] = oi),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: labelBg, shape: BoxShape.circle),
              child: Text(optionLabel,
                  style: TextStyle(
                      color: labelFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(q.options[oi],
                  style: TextStyle(
                      color: textColor, fontSize: 13, height: 1.4)),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

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
  return match?.group(1)?.trim() ?? output;
}

List<_QuizQuestion> _parseQuizQuestions(String text) {
  final questions = <_QuizQuestion>[];
  // Split on lines that start a new numbered question
  final blocks = text.split(RegExp(r'(?=^\d+[\.\)]\s)', multiLine: true));
  final optionRe = RegExp(r'^([A-Da-d][\.\)]\s*)(.+)$');
  final answerRe =
      RegExp(r'(?:correct\s+)?answer[:\s]+\**([A-Da-d])\**', caseSensitive: false);

  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;

    final qText =
        lines.first.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim();
    if (qText.isEmpty) continue;

    final options = <String>[];
    String? answerLetter;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final aMatch = answerRe.firstMatch(line);
      if (aMatch != null) {
        answerLetter = aMatch.group(1)!.toUpperCase();
        continue;
      }
      final oMatch = optionRe.firstMatch(line);
      if (oMatch != null) {
        options.add(oMatch.group(2)!.trim());
      }
    }

    if (options.length >= 2) {
      final correctIdx = answerLetter != null
          ? (answerLetter.codeUnitAt(0) - 'A'.codeUnitAt(0))
              .clamp(0, options.length - 1)
          : 0;
      questions.add(_QuizQuestion(
        question: qText,
        options: options,
        correctIndex: correctIdx,
      ));
    }
  }
  return questions;
}

List<Map<String, String>> _parseFlashcards(String text) {
  final qPattern = RegExp(r'Q\d*[:.]\s*(.*?)(?=A\d*[:.]\s*)', dotAll: true);
  final aPattern =
      RegExp(r'A\d*[:.]\s*(.*?)(?=Q\d*[:.]\s*|$)', dotAll: true);
  final questions =
      qPattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').toList();
  final answers =
      aPattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').toList();
  final cards = <Map<String, String>>[];
  for (int i = 0; i < questions.length && i < answers.length; i++) {
    if (questions[i].isNotEmpty) cards.add({'q': questions[i], 'a': answers[i]});
  }
  return cards.isEmpty ? [{'q': 'No flashcards found', 'a': text}] : cards;
}
