import 'package:flutter/material.dart';
import 'apiservice.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isBtnHovered = false;

  /// Application Theme Constants
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color darkIndigo = Color(0xFF1E1B4B);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color lightIndigoBg = Color(0xFFE0E7FF);
  static const Color tintIndigo = Color(0xFF818CF8);
  static const Color scaffoldBg = Color(0xFFF0F2FF);
  static const Color fieldGrey = Color(0xFFF3F4F6); // Professional Light Grey

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  /// Processes authentication requests via ApiService
  Future<void> _handleAction() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_tabs.index == 1 && name.isEmpty)) {
      _showSnack('Please fill in all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> result = _tabs.index == 1
        ? await ApiService.register(email: email, password: password, name: name)
        : await ApiService.login(email: email, password: password);

    if (mounted) setState(() => _isLoading = false);

    if (result.containsKey('error')) {
      _showSnack(result['error'], isError: true);
    } else if (_tabs.index == 1) {
      _showSnack(result['message'] ?? 'Account created! Check your email to verify before signing in.');
      _tabs.animateTo(0);
    } else {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    }
  }

  /// Forgot password dialog — sends reset link via SMTP
  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool sending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Reset Password',
            style: TextStyle(fontWeight: FontWeight.w800, color: darkIndigo),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we will send you a link to reset your password.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _buildTextField(
                controller: emailCtrl,
                hint: 'Email Address',
                icon: Icons.email_rounded,
                type: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => sending = true);
                      await ApiService.forgotPassword(email: email);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        _showSnack('If that email is registered, a reset link has been sent.');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: sending
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send Link', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays feedback messages to the user
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : darkIndigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Builds the top decorative header with branding elements
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 35, left: 24, right: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryIndigo, accentPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: primaryIndigo.withValues(alpha: 0.25), blurRadius: 25, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: darkIndigo.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Study Companion',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8),
          ),
          const SizedBox(height: 4),
          const Text(
            'Multi-AI Learning Assistant',
            style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
              child: Column(
                children: [
                  /// Authentication mode selector
                  Container(
                    height: 60,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: lightIndigoBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      indicatorSize: TabBarIndicatorSize.tab, 
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [primaryIndigo, accentPurple]),
                        boxShadow: [
                          BoxShadow(color: primaryIndigo.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: primaryIndigo.withValues(alpha: 0.7),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      tabs: const [Tab(text: 'Sign In'), Tab(text: 'Register')],
                    ),
                  ),

                  const SizedBox(height: 35),

                  /// Input form with layout transitions
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      children: [
                        if (_tabs.index == 1) ...[
                          _buildTextField(
                            controller: _nameController,
                            hint: 'Full Name',
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 18),
                        ],
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Email Address',
                          icon: Icons.email_rounded,
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Password',
                          icon: Icons.lock_rounded,
                          isPassword: true,
                        ),
                      ],
                    ),
                  ),

                  if (_tabs.index == 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPassword,
                        style: TextButton.styleFrom(foregroundColor: primaryIndigo),
                        child: const Text('Forgot Password?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),

                  const SizedBox(height: 30),

                  /// Main submission action component
                  MouseRegion(
                    onEnter: (_) => setState(() => _isBtnHovered = true),
                    onExit: (_) => setState(() => _isBtnHovered = false),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _handleAction,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isBtnHovered 
                                ? [accentPurple, primaryIndigo] 
                                : [primaryIndigo, accentPurple]
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: primaryIndigo.withValues(alpha: _isBtnHovered ? 0.4 : 0.25),
                              blurRadius: _isBtnHovered ? 20 : 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(height: 24, width: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  _tabs.index == 0 ? 'Sign In' : 'Get Started',
                                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/main', (_) => false),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Secure Multi-AI Authentication',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generates a standardized text input field
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fieldGrey, // Light Grey background for visibility
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: type,
        style: const TextStyle(fontWeight: FontWeight.w600, color: darkIndigo),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.indigo.withValues(alpha: 0.4), fontSize: 15),
          prefixIcon: Icon(icon, color: primaryIndigo, size: 22),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, 
                      color: tintIndigo, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)), // Visible border
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primaryIndigo, width: 2.0),
          ),
          filled: true,
          fillColor: fieldGrey,
        ),
      ),
    );
  }
}