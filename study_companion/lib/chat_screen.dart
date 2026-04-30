import 'package:flutter/material.dart';
import 'apiservice.dart';

// ─── DATA MODEL ───────────────────────────────────────────────────────────────

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String? ?? 'user',
        content: json['content'] as String? ?? '',
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                DateTime.now(),
      );
}

// ─── SCREEN ───────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _kIndigo     = Color(0xFF4F46E5);
  static const _kIndigoDark = Color(0xFF1E1B4B);
  static const _kPurple     = Color(0xFF7C3AED);

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode  = FocusNode();

  List<ChatMessage> _messages     = [];
  String _selectedModel           = 'llama3';
  bool   _isTyping                = false;
  bool   _isSubscribed            = false;
  bool   _sessionLoaded           = false;
  String _sessionId               = '';
  String _sessionTitle            = 'New Chat';

  static const _freeModels = ['llama3', 'mistral', 'phi3', 'gemma'];
  static const _proModels  = ['openai', 'claude', 'gemini'];

  List<String> get _availableModels => [
        ..._freeModels,
        if (_isSubscribed) ..._proModels,
      ];

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _checkSubscription();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sessionLoaded) {
      _sessionLoaded = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('session')) {
        _loadSession(args['session'] as Map<String, dynamic>);
      }
    }
  }

  void _loadSession(Map<String, dynamic> session) {
    final rawMessages = session['messages'] as List? ?? [];
    setState(() {
      _sessionId    = session['id']    as String? ?? _sessionId;
      _sessionTitle = session['title'] as String? ?? 'Chat';
      _selectedModel = session['model'] as String? ?? 'llama3';
      _messages = rawMessages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  Future<void> _checkSubscription() async {
    final sub = await ApiService.isSubscribed();
    if (mounted) setState(() => _isSubscribed = sub);
  }

  // ─── SEND ─────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isTyping) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      if (_messages.length == 1) {
        _sessionTitle = text.length > 50 ? '${text.substring(0, 50)}…' : text;
      }
    });
    _inputController.clear();
    _scrollToBottom();

    // Build history for the API (role + content only)
    final history = _messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final result = await ApiService.sendChatMessage(
      messages: history,
      model: _selectedModel,
      localModelName: _selectedModel,
    );

    final reply = result['response'] as String? ??
        result['output']  as String? ??
        (result.containsKey('error')
            ? 'Error: ${result['error']}'
            : 'No response received.');

    final assistantMsg = ChatMessage(
      role: 'assistant',
      content: reply,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(assistantMsg);
      _isTyping = false;
    });

    _scrollToBottom();
    await _saveSession();
  }

  // ─── PERSISTENCE ──────────────────────────────────────────────────────────

  Future<void> _saveSession() async {
    await ApiService.saveChatSession({
      'id': _sessionId,
      'type': 'chat',
      'session_type': 'conversation',
      'title': _sessionTitle,
      'model': _selectedModel,
      'timestamp': _messages.isNotEmpty
          ? _messages.first.timestamp.toIso8601String()
          : DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'messages': _messages.map((m) => m.toJson()).toList(),
    });
  }

  // ─── SCROLL ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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

  // ─── CLEAR ────────────────────────────────────────────────────────────────

  Future<void> _confirmClear() async {
    if (_messages.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('All messages in this session will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteSession(_sessionId);
      if (mounted) {
        setState(() {
          _messages = [];
          _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          _sessionTitle = 'New Chat';
        });
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _messages.isEmpty && !_isTyping
                  ? _buildEmptyState()
                  : _buildMessageList(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final modelLocked = _messages.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Title + message count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sessionTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _messages.isEmpty
                      ? 'Start a conversation'
                      : '${_messages.length} message${_messages.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Model dropdown (locked once chat begins)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: DropdownButton<String>(
              value: _availableModels.contains(_selectedModel)
                  ? _selectedModel
                  : _availableModels.first,
              dropdownColor: _kIndigoDark,
              underline: const SizedBox(),
              isDense: true,
              icon: const Icon(Icons.expand_more_rounded,
                  color: Colors.white, size: 16),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              items: _availableModels
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.toUpperCase())))
                  .toList(),
              onChanged: modelLocked
                  ? null
                  : (v) =>
                      setState(() => _selectedModel = v ?? _selectedModel),
            ),
          ),

          // Clear button
          if (_messages.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _confirmClear,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    const suggestions = [
      'Explain quantum entanglement',
      'How does photosynthesis work?',
      'Summarise Newton\'s laws',
      'What is machine learning?',
      'Compare TCP and UDP',
      'What causes inflation?',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: _kIndigo),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your AI tutor is ready',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kIndigoDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask anything — follow up as many times as you like.\nThe full conversation is remembered.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking…',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((hint) {
              return GestureDetector(
                onTap: () {
                  _inputController.text = hint;
                  _sendMessage();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kIndigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGE LIST ─────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kIndigo, _kPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      _selectedModel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? _kIndigo : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isUser ? 18 : 4),
                      bottomRight:
                          Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SelectableText(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser
                          ? Colors.white
                          : const Color(0xFF1F2937),
                      height: 1.55,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 3, left: 2, right: 2),
                  child: Text(
                    _formatTime(msg.timestamp),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kIndigo, _kPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ─── INPUT AREA ───────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kIndigo.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: 5,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF1F2937)),
              decoration: const InputDecoration(
                hintText: 'Ask anything…',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTyping
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [_kIndigo, _kPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!_isTyping)
                    BoxShadow(
                      color: _kIndigo.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Icon(
                _isTyping
                    ? Icons.hourglass_top_rounded
                    : Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── TYPING DOTS ─────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final progress = (_ctrl.value + i / 3.0) % 1.0;
            final opacity = (progress < 0.5 ? progress * 2 : (1 - progress) * 2)
                .clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.grey.shade300,
                  const Color(0xFF4F46E5),
                  opacity,
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
