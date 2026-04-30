import 'package:flutter/material.dart';

/// SubscriptionScreen
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  /// Application Theme Constants (Synced with LoginScreen)
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color darkIndigo = Color(0xFF1E1B4B);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color lightIndigoBg = Color(0xFFE0E7FF);
  static const Color tintIndigo = Color(0xFF818CF8);
  static const Color scaffoldBg = Color(0xFFF0F2FF);
  static const Color fieldGrey = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        /// Navbar
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: darkIndigo.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'PREMIUM ACCESS', 
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15, letterSpacing: 1.8)
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryIndigo, accentPurple],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          /// Responsive Layout
          double horizontalPadding = constraints.maxWidth > 600 ? constraints.maxWidth * 0.25 : 20.0;

          return SingleChildScrollView(
            child: Column(
              children: [
                /// Hero Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 40, bottom: 40, left: 24, right: 24),
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
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Elevate Your Workflow', 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8)
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select a professional tier to unlock advanced capabilities.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                /// Plans Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 30),
                  child: Column(
                    children: [
                      /// Standard Plan
                      const _PlanCard(
                        title: 'Standard',
                        price: '£0',
                        period: 'lifetime',
                        icon: Icons.layers_outlined,
                        features: ['Basic NLP Analysis', 'Local Model Access', 'Community Resources'],
                        buttonLabel: 'Current Plan',
                        isPro: false,
                        onTap: null,
                      ),
                      const SizedBox(height: 24),
                      
                      /// Professional Plan
                      _PlanCard(
                        title: 'Professional',
                        price: '£9',
                        period: 'per month',
                        icon: Icons.auto_awesome_rounded,
                        isPro: true,
                        features: const [
                          'Comprehensive NLP Analytics',
                          'GPT-4o & Claude 3 Integration',
                          'Gemini Ultra Deep Analysis',
                          'Priority Server Allocation',
                          'Advanced Document Scanning'
                        ],
                        buttonLabel: 'Upgrade to Pro',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// PlanCard Widget
class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final IconData icon;
  final List<String> features;
  final String buttonLabel;
  final bool isPro;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.title, required this.price,
    required this.period, required this.icon,
    required this.features, required this.buttonLabel,
    this.isPro = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPro ? SubscriptionScreen.primaryIndigo : Colors.grey.withValues(alpha: 0.2),
          width: isPro ? 2.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPro ? SubscriptionScreen.primaryIndigo.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20, offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          /// Recommended Badge
          if (isPro)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [SubscriptionScreen.primaryIndigo, SubscriptionScreen.accentPurple]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
              ),
              child: const Text(
                'RECOMMENDED CHOICE', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Card Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: isPro ? SubscriptionScreen.primaryIndigo : SubscriptionScreen.tintIndigo, size: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: SubscriptionScreen.darkIndigo)),
                        Text(period, style: const TextStyle(fontSize: 12, color: SubscriptionScreen.tintIndigo, fontWeight: FontWeight.w700)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SubscriptionScreen.darkIndigo, letterSpacing: 1.0)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 1)),
                
                /// Features List
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: isPro ? SubscriptionScreen.primaryIndigo : SubscriptionScreen.tintIndigo.withValues(alpha: 0.4), size: 18),
                      const SizedBox(width: 12),
                      Expanded(child: Text(feature, style: const TextStyle(fontSize: 14, color: SubscriptionScreen.darkIndigo, fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
                const SizedBox(height: 20),

                /// Action Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPro ? SubscriptionScreen.primaryIndigo : SubscriptionScreen.fieldGrey,
                      foregroundColor: isPro ? Colors.white : SubscriptionScreen.primaryIndigo,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pro button ke liye King/Premium Icon
                        if (isPro) ...[
                          const Icon(Icons.workspace_premium_rounded, size: 22), 
                          const SizedBox(width: 10),
                        ],
                        Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
}