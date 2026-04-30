import 'package:flutter/material.dart';
import 'theme.dart';
import 'home.dart';
import 'Login_screen.dart';
import 'Results_screen.dart';
import 'metrics_screen.dart';
import 'Compare_screen.dart';
import 'Subscription_screen.dart';
import 'camera_screen.dart';
import 'voice_screeen.dart';
import 'text_study_screen.dart';
import 'apiservice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyCompanionApp());
}

/// Root application widget.
class StudyCompanionApp extends StatelessWidget {
  const StudyCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Companion',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const AuthGate(),
      routes: {
        '/main':      (_) => const MainShell(),
        '/login':     (_) => const LoginScreen(),
        '/results':   (_) => const ResultsScreen(),
        '/metrics':   (_) => const MetricsScreen(),
        '/compare':   (_) => const CompareScreen(),
        '/subscribe': (_) => const SubscriptionScreen(),
        '/camera':    (_) => const CameraScreen(),
        '/voice':     (_) => const VoiceScreen(),
        '/text':      (_) => const TextStudyScreen(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH GATE
// Checks token on cold start, routes to login or main shell accordingly.
// ─────────────────────────────────────────────────────────────────────────────

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(loggedIn ? '/main' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SHELL
// Hosts the bottom navigation bar and switches between top-level pages.
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Currently selected bottom nav index.
  int _currentIndex = 0;

  /// Top-level pages corresponding to each nav item.
  final _pages = const [
    HomeScreen(),
    CompareScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  void _onTap(int i) => setState(() => _currentIndex = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody allows page content to scroll behind the navbar.
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION BAR
// Solid indigo bar with animated active indicator pill.
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded,           label: 'Home'),
    (icon: Icons.compare_arrows_rounded, label: 'Compare'),
    (icon: Icons.bookmark_rounded,       label: 'Saved'),
    (icon: Icons.person_rounded,         label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF4F46E5),
        border: Border(
          top: BorderSide(color: Color(0xFF6366F1), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _items.length,
              (i) => _NavItem(
                icon:   _items[i].icon,
                label:  _items[i].label,
                active: i == currentIndex,
                onTap:  () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM
// Single bottom nav icon + label with animated active pill.
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated pill highlight on active state.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// Shows logged-in user's name, email, subscription status, and a logout button.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _kIndigo     = Color(0xFF4F46E5);
  static const _kIndigoDark = Color(0xFF1E1B4B);
  static const _kPurple     = Color(0xFF7C3AED);
  static const _kAmber      = Color(0xFFF59E0B);
  static const _kRed        = Color(0xFFEF4444);

  String _name        = '';
  String _email       = '';
  bool   _subscribed  = false;
  bool   _loading     = true;
  bool   _isLoggedIn  = false;

  List<Map<String, dynamic>> _quizResults = [];
  int    _totalQuizzes = 0;
  double _avgPercent   = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loggedIn = await ApiService.isLoggedIn();

    if (!loggedIn) {
      setState(() {
        _isLoggedIn = false;
        _loading    = false;
      });
      return;
    }

    final meResult    = await ApiService.getMe();
    final quizResults = await ApiService.getQuizResults();
    final subscribed  = await ApiService.isSubscribed();

    String name  = '';
    String email = '';

    if (!meResult.containsKey('error')) {
      name  = meResult['name']  as String? ?? '';
      email = meResult['email'] as String? ?? '';
      await ApiService.saveUserProfile(name: name, email: email);
    } else {
      name  = await ApiService.getUserName()  ?? '';
      email = await ApiService.getUserEmail() ?? '';
    }

    final total = quizResults.length;
    final avg   = total > 0
        ? quizResults.fold<int>(0, (a, r) => a + (r['percent'] as int? ?? 0)) / total
        : 0.0;

    setState(() {
      _isLoggedIn   = true;
      _name         = name;
      _email        = email;
      _subscribed   = subscribed;
      _quizResults  = quizResults;
      _totalQuizzes = total;
      _avgPercent   = avg;
      _loading      = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out',
                style: TextStyle(color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kIndigo))
            : _isLoggedIn
                ? _buildLoggedInView()
                : _buildGuestView(),
      ),
    );
  }

  Widget _buildLoggedInView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),

          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _kIndigo.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white,
                child: _name.isNotEmpty
                    ? Text(
                        _name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: _kIndigo,
                        ),
                      )
                    : const Icon(Icons.person_rounded, size: 55, color: _kIndigo),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Text(
              _name.isNotEmpty ? _name : 'User',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kIndigoDark,
              ),
            ),
          ),
          const SizedBox(height: 6),

          if (_email.isNotEmpty)
            Center(
              child: Text(
                _email,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 20),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _StatusPill(
                  label: 'Logged In',
                  icon: Icons.verified_user_rounded,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: _subscribed ? 'Pro Plan' : 'Free Plan',
                  icon: _subscribed ? Icons.bolt_rounded : Icons.lock_open_rounded,
                  color: _subscribed ? _kAmber : Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _InfoCard(name: _name, email: _email, subscribed: _subscribed),
          const SizedBox(height: 16),

          _QuizProgressCard(
            total: _totalQuizzes,
            avgPercent: _avgPercent,
            results: _quizResults,
          ),
          const SizedBox(height: 24),

          if (!_subscribed)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAmber,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pushNamed(context, '/subscribe'),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Upgrade to Pro',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          if (!_subscribed) const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kRed,
                side: const BorderSide(color: _kRed, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log Out',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 48),

          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_rounded, size: 55, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Center(
            child: Text(
              'Guest User',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kIndigoDark,
              ),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _kIndigo.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kIndigo.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      size: 36, color: _kIndigo),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Login to unlock features',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kIndigoDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign in to unlock session saving, quiz reports, progress tracking, and much more.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const _FeatureRow(icon: Icons.save_rounded,      label: 'Save study sessions'),
                const SizedBox(height: 10),
                const _FeatureRow(icon: Icons.bar_chart_rounded, label: 'Quiz reports & progress'),
                const SizedBox(height: 10),
                const _FeatureRow(icon: Icons.history_rounded,   label: 'Session history'),
                const SizedBox(height: 10),
                const _FeatureRow(icon: Icons.bolt_rounded,      label: 'Pro plan upgrades'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text('Log In',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        'Account',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              fontSize: 18,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.manage_accounts_rounded,
                        color: Color(0xFFFDE047), size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your profile & plans',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE0E7FF),
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE ROW  — icon + label used in the guest view
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1B4B),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS PILL  — small coloured badge (Logged In / Pro Plan etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _StatusPill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CARD  — white card showing name / email / plan rows
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String name;
  final String email;
  final bool   subscribed;
  const _InfoCard({required this.name, required this.email, required this.subscribed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: name.isNotEmpty ? name : '—',
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email.isNotEmpty ? email : '—',
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _InfoRow(
            icon: Icons.star_outline_rounded,
            label: 'Plan',
            value: subscribed ? 'Pro' : 'Free',
            valueColor: subscribed ? const Color(0xFFF59E0B) : null,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF1E1B4B))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ PROGRESS CARD  — shows total quizzes done + average score on Profile
// ─────────────────────────────────────────────────────────────────────────────

class _QuizProgressCard extends StatelessWidget {
  final int    total;
  final double avgPercent;
  final List<Map<String, dynamic>> results;

  const _QuizProgressCard({
    required this.total,
    required this.avgPercent,
    required this.results,
  });

  static const _kIndigo = Color(0xFF4F46E5);

  String get _suggestion {
    if (total == 0) return 'Complete a quiz to see your progress here.';
    if (avgPercent >= 90) return 'Outstanding! You\'ve mastered the material.';
    if (avgPercent >= 75) return 'Great work! Review any questions you missed.';
    if (avgPercent >= 60) return 'Good progress. Focus on strengthening weak areas.';
    if (avgPercent >= 40) return 'Keep practising — review the material again.';
    return 'Needs more attention. Consider revisiting the content.';
  }

  Color get _barColor {
    if (avgPercent >= 75) return const Color(0xFF10B981);
    if (avgPercent >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (avgPercent / 100).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: _kIndigo),
              const SizedBox(width: 8),
              const Text(
                'Quiz Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total quiz${total == 1 ? '' : 'zes'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kIndigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${avgPercent.round()}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _barColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'avg. score',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _suggestion,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVED SCREEN
// Shows all saved chat and compare sessions from SharedPreferences.
// ─────────────────────────────────────────────────────────────────────────────

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final loggedIn = await ApiService.isLoggedIn();
    if (!loggedIn) {
      setState(() {
        _isLoggedIn = false;
        _sessions = [];
        _loading = false;
      });
      return;
    }
    final sessions = await ApiService.getSessions();
    setState(() {
      _isLoggedIn = true;
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all sessions?'),
        content: const Text('This will permanently delete all saved history.'),
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
    if (confirm == true) {
      await ApiService.clearSessions();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5)))
                  : !_isLoggedIn
                      ? _buildLoginWall()
                      : _sessions.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFF4F46E5),
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                                itemCount: _sessions.length,
                                itemBuilder: (context, i) =>
                                    _SessionCard(session: _sessions[i], onRefresh: _load),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                        'Saved Sessions',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  fontSize: 18,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.bookmark_rounded,
                        color: Color(0xFFFDE047), size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_sessions.length} session${_sessions.length == 1 ? '' : 's'} saved',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE0E7FF),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (_sessions.isNotEmpty)
            GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
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
            child: const Icon(Icons.bookmark_border_rounded,
                size: 40, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No sessions yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B4B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your chats and comparisons\nwill appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginWall() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_person_rounded,
                    size: 44, color: Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Unlock your chat session by logging in to the app',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your saved chats and sessions are\nlinked to your account. Sign in to access them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Login / Register'),
                onPressed: () async {
                  await Navigator.pushNamed(context, '/login');
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Free account — no subscription needed',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback? onRefresh;
  const _SessionCard({required this.session, this.onRefresh});
  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  Future<void> _exitSession(BuildContext context) async {
    final id = widget.session['id'] as String?;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove session?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
            'This will permanently remove this session from your saved list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteSession(id);
      widget.onRefresh?.call();
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionType = widget.session['session_type'] as String? ?? '';
    final isConversation = sessionType == 'conversation';

    return isConversation
        ? _buildConversationCard(context)
        : _buildLegacyCard(context);
  }

  // ── Conversation card (multi-turn chat sessions) ─────────────────────────

  Widget _buildConversationCard(BuildContext context) {
    final s         = widget.session;
    final title     = s['title']      as String? ?? 'Chat';
    final model     = s['model']      as String? ?? '';
    final updatedAt = s['updated_at'] as String? ?? s['timestamp'] as String? ?? '';
    final rawMsgs   = s['messages']   as List? ?? [];
    final msgCount  = rawMsgs.length;

    // Preview = last assistant message, or last user message
    String preview = '';
    for (final m in rawMsgs.reversed) {
      final map = m as Map<String, dynamic>;
      if ((map['role'] as String?) == 'assistant') {
        preview = map['content'] as String? ?? '';
        break;
      }
    }
    if (preview.isEmpty && rawMsgs.isNotEmpty) {
      preview = (rawMsgs.last as Map<String, dynamic>)['content'] as String? ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CHAT',
                    style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(width: 8),
                if (model.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      model.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280)),
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatTime(updatedAt),
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1B4B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Last response preview
          if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Text(
                preview.length > 120 ? '${preview.substring(0, 120)}…' : preview,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.45,
                    fontWeight: FontWeight.w400),
              ),
            ),

          // Footer: message count + continue button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '$msgCount message${msgCount == 1 ? '' : 's'}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
                const Spacer(),
                // Exit button
                GestureDetector(
                  onTap: () => _exitSession(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFCA5A5), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            color: Color(0xFFEF4444), size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Exit',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                // Continue Chat button
                GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/compare',
                        arguments: {
                          'resume_session': true,
                          'session': widget.session,
                        });
                    widget.onRefresh?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_rounded,
                            color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text(
                          'Continue Chat',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Legacy card (one-shot compare / single process sessions) ─────────────

  Widget _buildLegacyCard(BuildContext context) {
    final type      = widget.session['type']      as String? ?? 'chat';
    final timestamp = widget.session['timestamp'] as String? ?? '';
    final inputText = widget.session['input_text'] as String? ?? '';
    final models    = (widget.session['models'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final result = widget.session['result'] as Map<String, dynamic>? ?? {};

    final isCompare = type == 'compare';
    final typeColor =
        isCompare ? const Color(0xFF7C3AED) : const Color(0xFF4F46E5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // ── Card header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompare ? 'COMPARE' : 'CHAT',
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(width: 8),
                // Model chips
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: models
                        .map((m) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6B7280)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // Timestamp
                Text(
                  _formatTime(timestamp),
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // ── Input text preview ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Text(
              inputText.startsWith('[File:')
                  ? inputText
                  : inputText.length > 120
                      ? '${inputText.substring(0, 120)}...'
                      : inputText,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  height: 1.5,
                  fontWeight: FontWeight.w400),
            ),
          ),

          // ── Expand/collapse toggle ────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Hide outputs' : 'View outputs',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: const Color(0xFF4F46E5),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded outputs ──────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: isCompare
                  ? _buildCompareOutputs(result)
                  : _buildChatOutput(result),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompareOutputs(Map<String, dynamic> result) {
    final results = result['results'] as Map<String, dynamic>? ?? {};
    if (results.isEmpty) {
      return const Text('No output available.',
          style: TextStyle(color: Colors.grey, fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: results.entries.map((entry) {
        final modelName = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final output = data['output'] as String? ?? '';
        final isError = data.containsKey('error');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      modelName.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!isError)
                    Text(
                      '${data['response_time'] ?? '-'}s',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    isError ? 'Error: ${data['error']}' : output,
                    style: TextStyle(
                        fontSize: 11,
                        color: isError
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF374151),
                        height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatOutput(Map<String, dynamic> result) {
    final output = result['output'] as String? ?? '';
    final error = result['error'] as String?;
    final fallback = result['fallback_output'] as Map<String, dynamic>?;
    final text =
        output.isNotEmpty ? output : (fallback?['text'] ?? error ?? 'No output available');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 250),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        child: Text(
          text.toString(),
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF374151), height: 1.6),
        ),
      ),
    );
  }
}