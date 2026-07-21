import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/operational_config.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/salati_widgets_service.dart';
import '../data/local_quran_progress_repository.dart';
import '../data/quran_service.dart';
import 'quran_access.dart';
import 'quran_locked_feature_view.dart';
import 'quran_reader_support.dart';

const _quranSurahs = <_SurahOption>[
  _SurahOption(1, 'الفاتحة', 7),
  _SurahOption(2, 'البقرة', 286),
  _SurahOption(3, 'آل عمران', 200),
  _SurahOption(4, 'النساء', 176),
  _SurahOption(5, 'المائدة', 120),
  _SurahOption(6, 'الأنعام', 165),
  _SurahOption(7, 'الأعراف', 206),
  _SurahOption(8, 'الأنفال', 75),
  _SurahOption(9, 'التوبة', 129),
  _SurahOption(10, 'يونس', 109),
  _SurahOption(11, 'هود', 123),
  _SurahOption(12, 'يوسف', 111),
  _SurahOption(13, 'الرعد', 43),
  _SurahOption(14, 'إبراهيم', 52),
  _SurahOption(15, 'الحجر', 99),
  _SurahOption(16, 'النحل', 128),
  _SurahOption(17, 'الإسراء', 111),
  _SurahOption(18, 'الكهف', 110),
  _SurahOption(19, 'مريم', 98),
  _SurahOption(20, 'طه', 135),
  _SurahOption(21, 'الأنبياء', 112),
  _SurahOption(22, 'الحج', 78),
  _SurahOption(23, 'المؤمنون', 118),
  _SurahOption(24, 'النور', 64),
  _SurahOption(25, 'الفرقان', 77),
  _SurahOption(26, 'الشعراء', 227),
  _SurahOption(27, 'النمل', 93),
  _SurahOption(28, 'القصص', 88),
  _SurahOption(29, 'العنكبوت', 69),
  _SurahOption(30, 'الروم', 60),
  _SurahOption(31, 'لقمان', 34),
  _SurahOption(32, 'السجدة', 30),
  _SurahOption(33, 'الأحزاب', 73),
  _SurahOption(34, 'سبأ', 54),
  _SurahOption(35, 'فاطر', 45),
  _SurahOption(36, 'يس', 83),
  _SurahOption(37, 'الصافات', 182),
  _SurahOption(38, 'ص', 88),
  _SurahOption(39, 'الزمر', 75),
  _SurahOption(40, 'غافر', 85),
  _SurahOption(41, 'فصلت', 54),
  _SurahOption(42, 'الشورى', 53),
  _SurahOption(43, 'الزخرف', 89),
  _SurahOption(44, 'الدخان', 59),
  _SurahOption(45, 'الجاثية', 37),
  _SurahOption(46, 'الأحقاف', 35),
  _SurahOption(47, 'محمد', 38),
  _SurahOption(48, 'الفتح', 29),
  _SurahOption(49, 'الحجرات', 18),
  _SurahOption(50, 'ق', 45),
  _SurahOption(51, 'الذاريات', 60),
  _SurahOption(52, 'الطور', 49),
  _SurahOption(53, 'النجم', 62),
  _SurahOption(54, 'القمر', 55),
  _SurahOption(55, 'الرحمن', 78),
  _SurahOption(56, 'الواقعة', 96),
  _SurahOption(57, 'الحديد', 29),
  _SurahOption(58, 'المجادلة', 22),
  _SurahOption(59, 'الحشر', 24),
  _SurahOption(60, 'الممتحنة', 13),
  _SurahOption(61, 'الصف', 14),
  _SurahOption(62, 'الجمعة', 11),
  _SurahOption(63, 'المنافقون', 11),
  _SurahOption(64, 'التغابن', 18),
  _SurahOption(65, 'الطلاق', 12),
  _SurahOption(66, 'التحريم', 12),
  _SurahOption(67, 'الملك', 30),
  _SurahOption(68, 'القلم', 52),
  _SurahOption(69, 'الحاقة', 52),
  _SurahOption(70, 'المعارج', 44),
  _SurahOption(71, 'نوح', 28),
  _SurahOption(72, 'الجن', 28),
  _SurahOption(73, 'المزمل', 20),
  _SurahOption(74, 'المدثر', 56),
  _SurahOption(75, 'القيامة', 40),
  _SurahOption(76, 'الإنسان', 31),
  _SurahOption(77, 'المرسلات', 50),
  _SurahOption(78, 'النبأ', 40),
  _SurahOption(79, 'النازعات', 46),
  _SurahOption(80, 'عبس', 42),
  _SurahOption(81, 'التكوير', 29),
  _SurahOption(82, 'الانفطار', 19),
  _SurahOption(83, 'المطففين', 36),
  _SurahOption(84, 'الانشقاق', 25),
  _SurahOption(85, 'البروج', 22),
  _SurahOption(86, 'الطارق', 17),
  _SurahOption(87, 'الأعلى', 19),
  _SurahOption(88, 'الغاشية', 26),
  _SurahOption(89, 'الفجر', 30),
  _SurahOption(90, 'البلد', 20),
  _SurahOption(91, 'الشمس', 15),
  _SurahOption(92, 'الليل', 21),
  _SurahOption(93, 'الضحى', 11),
  _SurahOption(94, 'الشرح', 8),
  _SurahOption(95, 'التين', 8),
  _SurahOption(96, 'العلق', 19),
  _SurahOption(97, 'القدر', 5),
  _SurahOption(98, 'البينة', 8),
  _SurahOption(99, 'الزلزلة', 8),
  _SurahOption(100, 'العاديات', 11),
  _SurahOption(101, 'القارعة', 11),
  _SurahOption(102, 'التكاثر', 8),
  _SurahOption(103, 'العصر', 3),
  _SurahOption(104, 'الهمزة', 9),
  _SurahOption(105, 'الفيل', 5),
  _SurahOption(106, 'قريش', 4),
  _SurahOption(107, 'الماعون', 7),
  _SurahOption(108, 'الكوثر', 3),
  _SurahOption(109, 'الكافرون', 6),
  _SurahOption(110, 'النصر', 3),
  _SurahOption(111, 'المسد', 5),
  _SurahOption(112, 'الإخلاص', 4),
  _SurahOption(113, 'الفلق', 5),
  _SurahOption(114, 'الناس', 6),
];

class _SurahOption {
  const _SurahOption(this.number, this.name, this.ayahCount);

  final int number;
  final String name;
  final int ayahCount;
}

String _positionLabel(QuranReadingPosition position) {
  final surah = _quranSurahs.firstWhere(
    (item) => item.number == position.surah,
    orElse: () => _quranSurahs.first,
  );
  return '${surah.name}، آية ${position.ayah}';
}

class QuranHubScreen extends StatelessWidget {
  const QuranHubScreen({
    super.key,
    required this.repository,
    required this.services,
    required this.preferences,
  });

  final LocalQuranProgressRepository repository;
  final AppServices services;
  final AppPreferences preferences;

  Future<void> _openQuranIndex(BuildContext context) async {
    final current = await loadSavedReadingPosition(repository);
    if (!context.mounted) {
      return;
    }

    var selectedSurah = _quranSurahs.firstWhere(
      (surah) => surah.number == current.surah,
      orElse: () => _quranSurahs.first,
    );
    var selectedAyah = current.ayah.clamp(1, selectedSurah.ayahCount).toInt();
    final searchController = TextEditingController();
    var searchQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filteredSurahs = searchQuery.trim().isEmpty
                ? _quranSurahs
                : _quranSurahs
                      .where(
                        (surah) =>
                            surah.name.contains(searchQuery.trim()) ||
                            '${surah.number}'.contains(searchQuery.trim()),
                      )
                      .toList(growable: false);
            final visibleSurahs =
                filteredSurahs.any(
                  (surah) => surah.number == selectedSurah.number,
                )
                ? filteredSurahs
                : [selectedSurah, ...filteredSurahs];
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'فهرس القرآن',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'بحث باسم السورة أو رقمها',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) {
                      setSheetState(() => searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('quran-index-surah'),
                    initialValue: selectedSurah.number,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'السورة'),
                    items: visibleSurahs
                        .map(
                          (surah) => DropdownMenuItem<int>(
                            value: surah.number,
                            child: Text('${surah.number}. ${surah.name}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final nextSurah = _quranSurahs.firstWhere(
                        (surah) => surah.number == value,
                        orElse: () => _quranSurahs.first,
                      );
                      setSheetState(() {
                        selectedSurah = nextSurah;
                        selectedAyah = selectedAyah
                            .clamp(1, selectedSurah.ayahCount)
                            .toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'quran-index-ayah-${selectedSurah.number}-$selectedAyah',
                    ),
                    initialValue: selectedAyah,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الآية'),
                    items: List.generate(
                      selectedSurah.ayahCount,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('آية ${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() => selectedAyah = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final position = QuranReadingPosition(
                        surah: selectedSurah.number,
                        ayah: selectedAyah,
                      );
                      await repository.setActiveQuranWirdId(null);
                      await saveReadingPosition(repository, position.key);
                      await _syncScreenReadingWidget(position);
                      if (!sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم ضبط موضع القراءة على ${selectedSurah.name} آية $selectedAyah.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('ابدأ من هذا الموضع'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _openQuranWirdEditor(BuildContext context) async {
    final current = await loadSavedReadingPosition(repository);
    if (!context.mounted) {
      return;
    }

    final existingWirds = loadSavedQuranWirds(repository);
    final nameController = TextEditingController(
      text: 'ورد ${existingWirds.length + 1}',
    );
    final surahController = TextEditingController(text: '${current.surah}');
    final ayahController = TextEditingController(text: '${current.ayah}');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إضافة ورد قرآن',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم الورد',
                  hintText: 'مثال: ورد الصباح',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: surahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم السورة',
                        hintText: '1 - 114',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: ayahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم الآية',
                        hintText: '1',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final surah =
                      int.tryParse(
                        surahController.text.trim(),
                      )?.clamp(1, 114) ??
                      1;
                  final surahOption = _quranSurahs.firstWhere(
                    (item) => item.number == surah,
                    orElse: () => _quranSurahs.first,
                  );
                  final ayah =
                      int.tryParse(
                        ayahController.text.trim(),
                      )?.clamp(1, surahOption.ayahCount) ??
                      1;
                  final wird = QuranWird(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name.isEmpty ? 'ورد قرآن' : name,
                    position: QuranReadingPosition(surah: surah, ayah: ayah),
                  );
                  await saveQuranWirds(repository, [
                    ...loadSavedQuranWirds(repository),
                    wird,
                  ]);
                  await activateQuranWird(repository, wird);
                  await _syncScreenReadingWidget(wird.position);
                  if (!sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم حفظ ${wird.name} عند ${surahOption.name} آية $ayah.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('حفظ الورد'),
              ),
            ],
          ),
        );
      },
    );
    nameController.dispose();
    surahController.dispose();
    ayahController.dispose();
  }

  Future<void> _openQuranWird(BuildContext context, QuranWird wird) async {
    await activateQuranWird(repository, wird);
    await _syncScreenReadingWidget(wird.position);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم اختيار ${wird.name}. كل طرق القراءة ستبدأ من ${_positionLabel(wird.position)}.',
        ),
      ),
    );
  }

  Future<void> _syncScreenReadingWidget(QuranReadingPosition position) async {
    final surah = _quranSurahs.firstWhere(
      (item) => item.number == position.surah,
      orElse: () => _quranSurahs.first,
    );
    final reference = '${surah.name}، آية ${position.ayah}';
    var body = 'موضع قراءة الشاشة المستقل: $reference';
    try {
      final payload = await QuranService().getAyah(position.key);
      if (payload != null && payload.text.trim().isNotEmpty) {
        body = payload.text.trim();
      }
    } catch (_) {
      // يبقى الودجت صالحا بالموضع حتى لو لم تتوفر الشبكة لحظة التحديث.
    }

    await SalatiWidgetsService.updateScreenReadingWidget(
      title: 'قراءة الشاشة',
      body: body,
      reference: reference,
      surah: position.surah,
      ayah: position.ayah,
      surahName: surah.name,
    );
  }

  Future<void> _openQuranWirdsSheet(
    BuildContext context, {
    required List<QuranWird> wirds,
    required String? activeWirdId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _QuranWirdsCard(
            wirds: wirds,
            activeWirdId: activeWirdId,
            onAdd: () {
              Navigator.of(sheetContext).pop();
              _openQuranWirdEditor(context);
            },
            onOpen: (wird) {
              Navigator.of(sheetContext).pop();
              _openQuranWird(context, wird);
            },
            onDelete: (wird) async {
              await _deleteQuranWird(wird);
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteQuranWird(QuranWird wird) async {
    final updated = loadSavedQuranWirds(
      repository,
    ).where((item) => item.id != wird.id).toList(growable: false);
    await saveQuranWirds(repository, updated);
    if (repository.activeQuranWirdId == wird.id) {
      await repository.setActiveQuranWirdId(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return QuranAccessBuilder(
      services: services,
      builder: (context, access) {
        return StreamBuilder<OperationalConfig>(
          stream: services.appConfigRepository.watchOperationalConfig(),
          builder: (context, configSnapshot) {
            final quranLimits =
                configSnapshot.data?.quranLimits ??
                OperationalConfig.defaults().quranLimits;
            final cards = [
              _QuranHubCardData(
                title: 'قران كريم',
                description: '',
                icon: Icons.auto_stories_outlined,
                routeName: AppRouter.quranPageReaderRoute,
                tierLabel: 'مجاني',
                isLocked: false,
                lockedTitle: '',
                lockedMessage: '',
              ),
              _QuranHubCardData(
                title: 'القران الكريم ايات',
                description: '',
                icon: Icons.short_text_rounded,
                routeName: AppRouter.quranAyahReaderRoute,
                tierLabel: access.hasAyahAccess
                    ? 'غير محدود'
                    : '${quranLimits.ayahFreeMinutes} دقيقة يوميا',
                isLocked: false,
                lockedTitle: 'القران الكريم ايات',
                lockedMessage:
                    'وضع الآيات يبدأ بخطة مجانية يومية، والترقية تفتح الاستخدام الكامل.',
              ),
              _QuranHubCardData(
                title: 'القران الكريم كلمات',
                description: '',
                icon: Icons.timelapse_rounded,
                routeName: AppRouter.quranWordReaderRoute,
                tierLabel: access.hasWordAccess
                    ? 'غير محدود'
                    : '${quranLimits.wordFreeMinutes} دقيقة يوميا',
                isLocked: false,
                lockedTitle: 'القران الكريم كلمات',
                lockedMessage:
                    'وضع الكلمات يبدأ بخطة مجانية يومية، والترقية تفتح الاستخدام الكامل.',
              ),
              _QuranHubCardData(
                title: 'Quran AI',
                description: '',
                icon: Icons.auto_awesome_rounded,
                routeName: AppRouter.quranAiRoute,
                tierLabel: access.hasPlusAccess ? '100 يوميا' : '5 مجاني',
                isLocked: false,
                lockedTitle: 'Quran AI',
                lockedMessage:
                    'Quran AI له نقاط يومية مجانية، والباقات ترفع الحدود.',
              ),
            ];

            return ListenableBuilder(
              listenable: preferences,
              builder: (context, _) {
                final wirds = loadSavedQuranWirds(repository);
                final activeWirdId = repository.activeQuranWirdId;
                return FutureBuilder<QuranReadingPosition>(
                  future: loadSavedReadingPosition(repository),
                  builder: (context, snapshot) {
                    final position = snapshot.data;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _openQuranIndex(context),
                                icon: const Icon(
                                  Icons.format_list_numbered_rtl_rounded,
                                ),
                                label: const Text('الفهرس'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _openQuranWirdsSheet(
                                  context,
                                  wirds: wirds,
                                  activeWirdId: activeWirdId,
                                ),
                                icon: const Icon(Icons.bookmarks_outlined),
                                label: const Text('الأوراد'),
                              ),
                            ),
                          ],
                        ),
                        if (position != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'آخر موضع: ${_positionLabel(position)}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'قرآن كريم',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 720;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cards.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isWide ? 2 : 1,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: isWide ? 1.38 : 1.55,
                                  ),
                              itemBuilder: (context, index) {
                                final card = cards[index];
                                return _QuranHubCard(
                                  data: card,
                                  onTap: () {
                                    if (card.isLocked) {
                                      showQuranUpgradeSheet(
                                        context,
                                        title: card.lockedTitle,
                                        message: card.lockedMessage,
                                      );
                                      return;
                                    }
                                    Navigator.of(
                                      context,
                                    ).pushNamed(card.routeName);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QuranWirdsCard extends StatelessWidget {
  const _QuranWirdsCard({
    required this.wirds,
    required this.activeWirdId,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  final List<QuranWird> wirds;
  final String? activeWirdId;
  final VoidCallback onAdd;
  final ValueChanged<QuranWird> onOpen;
  final ValueChanged<QuranWird> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'أورادي',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onAdd,
                  tooltip: 'إضافة ورد',
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (wirds.isEmpty)
              Text(
                'أضف أكثر من ورد واحفظ لكل واحد آخر موضع قراءة مستقل.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...wirds.map(
                (wird) => _QuranWirdRow(
                  wird: wird,
                  isActive: activeWirdId == wird.id,
                  onOpen: () => onOpen(wird),
                  onDelete: () => onDelete(wird),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuranWirdRow extends StatelessWidget {
  const _QuranWirdRow({
    required this.wird,
    required this.isActive,
    required this.onOpen,
    required this.onDelete,
  });

  final QuranWird wird;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primaryContainer
                : colors.surfaceContainerHighest.withAlpha(150),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? colors.primary.withAlpha(90)
                  : colors.outlineVariant.withAlpha(130),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.bookmark_added_rounded
                    : Icons.menu_book_rounded,
                color: isActive
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wird.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isActive ? colors.onPrimaryContainer : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'آخر موضع: ${_positionLabel(wird.position)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isActive
                            ? colors.onPrimaryContainer.withAlpha(200)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'حذف الورد',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuranHubCardData {
  const _QuranHubCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.routeName,
    required this.tierLabel,
    required this.isLocked,
    required this.lockedTitle,
    required this.lockedMessage,
  });

  final String title;
  final String description;
  final IconData icon;
  final String routeName;
  final String tierLabel;
  final bool isLocked;
  final String lockedTitle;
  final String lockedMessage;
}

class _QuranHubCard extends StatelessWidget {
  const _QuranHubCard({required this.data, required this.onTap});

  final _QuranHubCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baseColor = data.isLocked ? scheme.surfaceContainer : scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                baseColor.withValues(alpha: data.isLocked ? 0.08 : 0.12),
                scheme.surface,
              ],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: baseColor.withValues(
                        alpha: data.isLocked ? 0.12 : 0.16,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      data.icon,
                      color: data.isLocked
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: data.isLocked
                          ? scheme.surfaceContainerHighest
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      data.isLocked ? 'مقفول' : data.tierLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: data.isLocked
                            ? scheme.onSurfaceVariant
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                data.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (data.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  data.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    data.isLocked
                        ? Icons.lock_outline_rounded
                        : Icons.arrow_back_rounded,
                    size: 18,
                    color: data.isLocked
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.isLocked ? 'عرض تفاصيل الترقية' : 'فتح التجربة',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: data.isLocked
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
