import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'apiservice.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color darkIndigo = Color(0xFF1E1B4B);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color scaffoldBg = Color(0xFFF0F2FF);

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isLoading = false;
  String _transcript = '';
  String _selectedLocalModel = 'llama3';

  late AnimationController _liveController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) => setState(() => _isListening = status == 'listening'),
      onError: (error) => setState(() => _isListening = false),
    );
    setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _sendToAI() async {
    if (_transcript.isEmpty || _isLoading) return;
    await _speech.stop();
    setState(() => _isLoading = true);
    final result = await ApiService.processText(
      text: _transcript,
      model: _selectedLocalModel,
      localModelName: _selectedLocalModel,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString()), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pushNamed(context, '/results', arguments: {
      'result': result,
      'originalText': _transcript,
    });
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() { _transcript = ''; });
    await _speech.listen(
      onResult: (result) => setState(() => _transcript = result.recognizedWords),
    );
  }

  @override
  void dispose() {
    _liveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: primaryIndigo,
        elevation: 0,
        toolbarHeight: 60,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_voice_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'VOICE ASSISTANT',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth > 600 ? constraints.maxWidth * 0.2 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 30),
            child: Column(
              children: [

                // ── Mic section — fixed height so rings don't push content ──
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Pulse rings — clipped inside the SizedBox, don't affect layout
                      if (_isListening)
                        ...List.generate(3, (index) => _buildPulseRing(index)),

                      // Mic button always centered, fixed size
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _isListening ? () => _speech.stop() : _startListening,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [primaryIndigo, accentPurple],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryIndigo.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  _isListening ? "LIVE LISTENING" : "TAP TO SPEAK",
                  style: TextStyle(
                    color: _isListening ? Colors.redAccent : darkIndigo,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 40),

                // ── Transcript box ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border(
                      left: BorderSide(color: Colors.indigo.shade300, width: 3),
                      top: BorderSide(color: Colors.indigo.shade100),
                      right: BorderSide(color: Colors.indigo.shade100),
                      bottom: BorderSide(color: Colors.indigo.shade100),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REAL-TIME TRANSCRIPT',
                        style: TextStyle(
                          color: Colors.indigo.shade300,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _transcript.isEmpty ? 'Waiting for your voice...' : _transcript,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.indigo.shade900,
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Model selector ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT AI ENGINE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: Colors.indigo.shade300,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['llama3', 'mistral', 'phi3', 'gemma']
                        .map((m) => _buildModelChip(m))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Action buttons ──
                Row(
                  children: [
                    _buildExitButton(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSecondaryButton('CLEAR', () => setState(() => _transcript = '')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildPrimaryButton(
                        _isLoading ? 'THINKING…' : 'SEND TO AI',
                        (_transcript.isEmpty || _isLoading) ? null : _sendToAI,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Pulse ring — stays inside the SizedBox, does NOT affect layout ──
  Widget _buildPulseRing(int index) {
    return AnimatedBuilder(
      animation: _liveController,
      builder: (context, child) {
        double progress = (_liveController.value + (index * 0.33)) % 1.0;
        // Max ring size = 240 (fits inside 260 SizedBox)
        double size = 100 + (140 * progress);
        return SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryIndigo.withValues(alpha: (1 - progress) * 0.6),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModelChip(String label) {
    bool isSelected = _selectedLocalModel == label;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedLocalModel = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryIndigo : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? primaryIndigo : Colors.indigo.shade100,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: primaryIndigo.withValues(alpha: 0.25), blurRadius: 8)]
                : [],
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.indigo.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed) {
    return MouseRegion(
      cursor: onPressed == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed == null ? Colors.grey.shade300 : Colors.indigo.shade900,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return SizedBox(
      height: 58,
      width: 58,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
          foregroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.close_rounded, size: 22),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        height: 58,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.indigo.shade300, width: 1.5),
            foregroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
      ),
    );
  }
}