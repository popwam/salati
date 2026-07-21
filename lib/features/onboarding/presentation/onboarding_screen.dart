import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.preferences,
    required this.services,
  });

  final AppPreferences preferences;
  final AppServices services;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.mosque_rounded,
      assetPath: 'assets/icon/app/logo.png',
      title: 'صلاتي',
      body:
          'مواقيت الصلاة، الأذان، القرآن، الأذكار، والدروس في تجربة واحدة هادئة.',
    ),
    _OnboardingPageData(
      icon: Icons.notifications_active_rounded,
      title: 'أذان وتنبيهات دقيقة',
      body:
          'فعّل التنبيهات مرة واحدة، وسنرتب لك مواقيت اليوم والتنبيه قبل الصلاة.',
    ),
    _OnboardingPageData(
      icon: Icons.auto_stories_rounded,
      title: 'مصحف وورد يومي',
      body:
          'اقرأ القرآن، تابع وردك، وافتح الأذكار والأدعية بسرعة من الشاشة الرئيسية.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.preferences.setOnboardingCompleted(true);
    await widget.services.analyticsService.trackEvent('onboarding_completed');
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRouter.homeRoute);
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('تخطي'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    return _OnboardingPage(data: _pages[index]);
                  },
                ),
              ),
              Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (dotIndex) {
                      final selected = dotIndex == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selected ? 26 : 8,
                        height: 8,
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: selected
                              ? const Color(0xFF2F78BD)
                              : const Color(0xFFD7E2EE),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      _index == _pages.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_back_rounded,
                    ),
                    label: Text(
                      _index == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F78BD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: const Color(0xFFE6EEF7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F78BD).withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xFF2F78BD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: data.assetPath == null
                  ? Icon(data.icon, color: Colors.white, size: 52)
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(data.assetPath!, fit: BoxFit.contain),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 34),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF1F2937),
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            data.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
    this.assetPath,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? assetPath;
}
