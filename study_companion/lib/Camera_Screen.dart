import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isProcessing = false;
  String _extractedText = '';
  String _ocrStatus = '';
  bool _showOcrResult = false;
  String _selectedMode = 'Notes';
  String _selectedLocalModel = 'llama3';

  final _modes = ['Notes', 'Textbook', 'Whiteboard'];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _controller = CameraController(_cameras[0], ResolutionPreset.max, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() => _isCameraReady = true);
  }

  Future<void> _captureAndOcr() async {
    if (_controller == null || !_isCameraReady) return;
    setState(() { _isProcessing = true; _ocrStatus = 'Scanning...'; });

    try {
      final photo = await _controller!.takePicture();
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      setState(() {
        _extractedText = recognizedText.text.trim();
        _isProcessing = false;
        _showOcrResult = true;
        _ocrStatus = '';
      });
    } catch (e) {
      setState(() { _isProcessing = false; _ocrStatus = 'Error: $e'; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('Vision AI',
          style: TextStyle(fontWeight: FontWeight.w800, color: _showOcrResult ? Colors.indigo[900] : Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: _showOcrResult ? Colors.indigo[900] : Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _showOcrResult ? _buildOcrResult() : _buildCameraView(),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        Positioned.fill(
          child: (_isCameraReady && _controller != null)
              ? CameraPreview(_controller!)
              : const Center(child: CircularProgressIndicator(color: Colors.indigo)),
        ),
        if (!_showOcrResult) const _ScanOverlay(),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _modes.map((m) => _ModePill(
                    label: m,
                    isSelected: _selectedMode == m,
                    onTap: () => setState(() => _selectedMode = m),
                  )).toList(),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _RoundIconButton(icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context)),
                    _CaptureButton(isProcessing: _isProcessing, onTap: _captureAndOcr),
                    _RoundIconButton(icon: Icons.bolt_rounded,
                      onTap: () => _controller?.setFlashMode(FlashMode.torch)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_ocrStatus.isNotEmpty) Center(child: _StatusIndicator(text: _ocrStatus)),
      ],
    );
  }

  Widget _buildOcrResult() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double horizontalPadding = constraints.maxWidth > 600 ? constraints.maxWidth * 0.2 : 22.0;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.indigo.shade50, Colors.white],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResultHeader(onRetake: () => setState(() => _showOcrResult = false)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.indigo.shade700),
                        const SizedBox(width: 6),
                        Text(
                          _selectedMode.toUpperCase(),
                          style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
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
                        Row(
                          children: [
                            Icon(Icons.document_scanner_rounded, color: Colors.indigo.shade300, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'RECOGNIZED CONTENT',
                              style: TextStyle(
                                color: Colors.indigo.shade900,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _extractedText,
                          style: TextStyle(
                            color: Colors.indigo.shade900.withValues(alpha: 0.75),
                            fontSize: 15,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'CHOOSE AI ENGINE',
                    style: TextStyle(
                      color: Colors.indigo.shade300,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['llama3', 'mistral', 'phi3'].map((m) => _ModelChip(
                      label: m,
                      isSelected: _selectedLocalModel == m,
                      onTap: () => setState(() => _selectedLocalModel = m),
                    )).toList(),
                  ),
                  const SizedBox(height: 36),
                  _AnimatedActionButton(
                    label: 'ANALYZE WITH ${_selectedLocalModel.toUpperCase()}',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── SUB-WIDGETS ─────────────────────────────────────────────────────────────

class _ModePill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModePill({required this.label, required this.isSelected, required this.onTap});

  @override
  State<_ModePill> createState() => _ModePillState();
}

class _ModePillState extends State<_ModePill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
              ? Colors.indigo
              : (_isHovered ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(widget.label,
            style: TextStyle(
              color: widget.isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatefulWidget {
  final bool isProcessing;
  final VoidCallback onTap;
  const _CaptureButton({required this.isProcessing, required this.onTap});

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isProcessing ? null : widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 85, height: 85,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                if (_isHovered) BoxShadow(color: Colors.indigo.withValues(alpha: 0.5), blurRadius: 20),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: widget.isProcessing
                  ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.indigo, strokeWidth: 3))
                  : const Icon(Icons.camera_rounded, color: Colors.indigo, size: 38),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  final VoidCallback onRetake;
  const _ResultHeader({required this.onRetake});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Result',
              style: TextStyle(
                color: Colors.indigo.shade900,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Text extracted successfully',
              style: TextStyle(color: Colors.indigo.shade300, fontSize: 13),
            ),
          ],
        ),
        _SecondaryButton(label: 'Retake', icon: Icons.refresh_rounded, onTap: onRetake),
      ],
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.icon, required this.onTap});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: OutlinedButton.icon(
          onPressed: widget.onTap,
          icon: Icon(widget.icon, size: 16),
          label: Text(widget.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo,
            backgroundColor: _isHovered ? Colors.indigo.shade50 : Colors.white,
            side: BorderSide(color: Colors.indigo.shade200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }
}

class _ModelChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModelChip({required this.label, required this.isSelected, required this.onTap});

  @override
  State<_ModelChip> createState() => _ModelChipState();
}

class _ModelChipState extends State<_ModelChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.indigo
                : (_isHovered ? Colors.indigo.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected ? Colors.indigo : Colors.indigo.shade200,
            ),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              color: widget.isSelected ? Colors.white : Colors.indigo.shade400,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AnimatedActionButton({required this.label, required this.onTap});

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: double.infinity,
          height: 62,
          child: ElevatedButton(
            onPressed: widget.onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isHovered ? Colors.indigo.shade800 : Colors.indigo.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: _isHovered ? 12 : 0,
              shadowColor: Colors.indigo.withValues(alpha: 0.35),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── STATUS INDICATOR ─────────────────────────────────────────────────────────

class _StatusIndicator extends StatelessWidget {
  final String text;
  const _StatusIndicator({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.indigo)),
          const SizedBox(width: 15),
          Text(text, style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ─── SCAN OVERLAY ─────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Full screen box with small margin on sides
        final boxW = w * 0.88;
        final boxH = h * 0.68;
        final boxL = (w - boxW) / 2;
        final boxT = (h - boxH) / 2 - 30; // slightly above center

        return CustomPaint(
          painter: _CornerPainter(
            boxLeft: boxL,
            boxTop: boxT,
            boxRight: boxL + boxW,
            boxBottom: boxT + boxH,
            cornerLen: 36,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double boxLeft;
  final double boxTop;
  final double boxRight;
  final double boxBottom;
  final double cornerLen;

  const _CornerPainter({
    required this.boxLeft,
    required this.boxTop,
    required this.boxRight,
    required this.boxBottom,
    required this.cornerLen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final l = cornerLen;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(boxLeft, boxTop + l)
        ..lineTo(boxLeft, boxTop)
        ..lineTo(boxLeft + l, boxTop),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(boxRight - l, boxTop)
        ..lineTo(boxRight, boxTop)
        ..lineTo(boxRight, boxTop + l),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(boxLeft, boxBottom - l)
        ..lineTo(boxLeft, boxBottom)
        ..lineTo(boxLeft + l, boxBottom),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(boxRight - l, boxBottom)
        ..lineTo(boxRight, boxBottom)
        ..lineTo(boxRight, boxBottom - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.boxLeft != boxLeft ||
      old.boxTop != boxTop ||
      old.boxRight != boxRight ||
      old.boxBottom != boxBottom;
}