import 'package:flutter/material.dart';

class SalatiDashboardScreen extends StatelessWidget {
  const SalatiDashboardScreen({
    super.key,
    required this.onOpenQuran,
    required this.onOpenPrayer,
    required this.onOpenAdhkar,
    required this.onOpenDuas,
    required this.onOpenAi,
    required this.onOpenStore,
    required this.onUnavailable,
  });

  final VoidCallback onOpenQuran;
  final VoidCallback onOpenPrayer;
  final VoidCallback onOpenAdhkar;
  final VoidCallback onOpenDuas;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenStore;
  final ValueChanged<String> onUnavailable;

  static const _green = Color(0xFF078467);
  static const _purple = Color(0xFF7446B8);
  static const _iconBackground = Color(0xFFDCEBFF);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final services = <_DashboardService>[
      _DashboardService('قرآن', Icons.menu_book_rounded, onOpenQuran),
      _DashboardService('الصلاة', Icons.schedule_rounded, onOpenPrayer),
      _DashboardService(
        'القبلة',
        Icons.explore_rounded,
        () => onUnavailable('القبلة'),
      ),
      _DashboardService('الأذكار', Icons.spa_outlined, onOpenAdhkar),
      _DashboardService(
        'الحديث',
        Icons.auto_stories_outlined,
        () => onUnavailable('الحديث'),
      ),
      _DashboardService(
        'المساجد',
        Icons.mosque_outlined,
        () => onUnavailable('المساجد'),
      ),
      _DashboardService(
        'دروس',
        Icons.self_improvement_rounded,
        () => onUnavailable('الدروس'),
      ),
      _DashboardService(
        'حلقات',
        Icons.layers_outlined,
        () => onUnavailable('الحلقات'),
      ),
      _DashboardService('الذكاء', Icons.psychology_alt_outlined, onOpenAi),
      _DashboardService(
        'قراء',
        Icons.record_voice_over_outlined,
        () => onUnavailable('القراء'),
      ),
      _DashboardService('كلمات', Icons.chat_bubble_outline_rounded, onOpenDuas),
      _DashboardService('آيات', Icons.bookmark_border_rounded, onOpenQuran),
    ];

    return ColoredBox(
      color: const Color(0xFFFCFBF9),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(now: now)),
          const SliverToBoxAdapter(child: _NextPrayerCard()),
          const SliverToBoxAdapter(child: _PrayerTimesStrip()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 18,
                crossAxisSpacing: 28,
                childAspectRatio: .92,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ServiceCard(service: services[index]),
                childCount: services.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: OutlinedButton.icon(
                onPressed: onOpenStore,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('المتجر والمحتوى الإضافي'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 86)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    const months = <String>[
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 18, 34, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${now.day} ${months[now.month - 1]} ${now.year}',
                  style: const TextStyle(
                    color: Color(0xFFAAA8A6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'الأحد  ربيع الأول 1445',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'المكان',
                  style: TextStyle(color: Color(0xFFAAA8A6), fontSize: 12),
                ),
                SizedBox(height: 5),
                Text(
                  'القاهرة، مصر',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 22, 32, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E6E3), width: 6)),
      ),
      child: const Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '12:30',
                style: TextStyle(
                  color: SalatiDashboardScreen._green,
                  fontSize: 29,
                ),
              ),
              Text(
                'بعد ساعة و 15 دقيقة',
                style: TextStyle(color: Color(0xFF8A8987), fontSize: 12),
              ),
            ],
          ),
          Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'الصلاة القادمة',
                style: TextStyle(color: Color(0xFF8A8987), fontSize: 12),
              ),
              Text(
                'صلاة الظهر',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(width: 12),
          CircleAvatar(
            radius: 25,
            backgroundColor: SalatiDashboardScreen._green,
            child: Icon(Icons.schedule_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimesStrip extends StatelessWidget {
  const _PrayerTimesStrip();

  @override
  Widget build(BuildContext context) {
    const times = <(String, String, Color)>[
      ('الفجر', '5:15', Color(0xFFE8F1FF)),
      ('الشروق', '6:45', Color(0xFFFFF2CC)),
      ('العصر', '3:45', Color(0xFFFFEBD1)),
      ('المغرب', '6:15', Color(0xFFFFE2E2)),
      ('العشاء', '7:45', Color(0xFFE4ECFF)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: times
            .map(
              (item) => Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: item.$3,
                    child: const Icon(
                      Icons.square,
                      size: 12,
                      color: Color(0xFF202020),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777572),
                    ),
                  ),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DashboardService {
  const _DashboardService(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final _DashboardService service;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: service.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: SalatiDashboardScreen._iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  service.icon,
                  color: SalatiDashboardScreen._purple,
                  size: 34,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                service.label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SalatiEpisodesScreen extends StatelessWidget {
  const SalatiEpisodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const episodes = <(String, String, IconData)>[
      ('تأملات قرآنية', '12 حلقة', Icons.menu_book_outlined),
      ('دروس في السيرة', '8 حلقات', Icons.mosque_outlined),
      ('رحلة مع الأذكار', '6 حلقات', Icons.spa_outlined),
      ('بودكاست صلاتي', '10 حلقات', Icons.mic_none_rounded),
    ];
    return ColoredBox(
      color: const Color(0xFFFCFBF9),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
              color: const Color(0xFF447DB7),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الحلقات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'محتوى صوتي ومعرفي مختار',
                    style: TextStyle(color: Color(0xFFD8E7FA)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(18),
            sliver: SliverList.separated(
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEBFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        episode.$3,
                        color: const Color(0xFF7446B8),
                        size: 30,
                      ),
                    ),
                    title: Text(
                      episode.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(episode.$2),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('سيتم إضافة التشغيل قريبًا'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }
}
