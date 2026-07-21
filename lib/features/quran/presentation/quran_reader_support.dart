import '../data/local_quran_progress_repository.dart';
import '../data/quran_service.dart';

class QuranReadingPosition {
  const QuranReadingPosition({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  String get key => '$surah:$ayah';

  String get displayName => '${quranSurahName(surah)} $ayah';
}

const quranBasmalahText = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

const quranSurahNames = <int, String>{
  1: 'الفاتحة',
  2: 'البقرة',
  3: 'آل عمران',
  4: 'النساء',
  5: 'المائدة',
  6: 'الأنعام',
  7: 'الأعراف',
  8: 'الأنفال',
  9: 'التوبة',
  10: 'يونس',
  11: 'هود',
  12: 'يوسف',
  13: 'الرعد',
  14: 'إبراهيم',
  15: 'الحجر',
  16: 'النحل',
  17: 'الإسراء',
  18: 'الكهف',
  19: 'مريم',
  20: 'طه',
  21: 'الأنبياء',
  22: 'الحج',
  23: 'المؤمنون',
  24: 'النور',
  25: 'الفرقان',
  26: 'الشعراء',
  27: 'النمل',
  28: 'القصص',
  29: 'العنكبوت',
  30: 'الروم',
  31: 'لقمان',
  32: 'السجدة',
  33: 'الأحزاب',
  34: 'سبأ',
  35: 'فاطر',
  36: 'يس',
  37: 'الصافات',
  38: 'ص',
  39: 'الزمر',
  40: 'غافر',
  41: 'فصلت',
  42: 'الشورى',
  43: 'الزخرف',
  44: 'الدخان',
  45: 'الجاثية',
  46: 'الأحقاف',
  47: 'محمد',
  48: 'الفتح',
  49: 'الحجرات',
  50: 'ق',
  51: 'الذاريات',
  52: 'الطور',
  53: 'النجم',
  54: 'القمر',
  55: 'الرحمن',
  56: 'الواقعة',
  57: 'الحديد',
  58: 'المجادلة',
  59: 'الحشر',
  60: 'الممتحنة',
  61: 'الصف',
  62: 'الجمعة',
  63: 'المنافقون',
  64: 'التغابن',
  65: 'الطلاق',
  66: 'التحريم',
  67: 'الملك',
  68: 'القلم',
  69: 'الحاقة',
  70: 'المعارج',
  71: 'نوح',
  72: 'الجن',
  73: 'المزمل',
  74: 'المدثر',
  75: 'القيامة',
  76: 'الإنسان',
  77: 'المرسلات',
  78: 'النبأ',
  79: 'النازعات',
  80: 'عبس',
  81: 'التكوير',
  82: 'الانفطار',
  83: 'المطففين',
  84: 'الانشقاق',
  85: 'البروج',
  86: 'الطارق',
  87: 'الأعلى',
  88: 'الغاشية',
  89: 'الفجر',
  90: 'البلد',
  91: 'الشمس',
  92: 'الليل',
  93: 'الضحى',
  94: 'الشرح',
  95: 'التين',
  96: 'العلق',
  97: 'القدر',
  98: 'البينة',
  99: 'الزلزلة',
  100: 'العاديات',
  101: 'القارعة',
  102: 'التكاثر',
  103: 'العصر',
  104: 'الهمزة',
  105: 'الفيل',
  106: 'قريش',
  107: 'الماعون',
  108: 'الكوثر',
  109: 'الكافرون',
  110: 'النصر',
  111: 'المسد',
  112: 'الإخلاص',
  113: 'الفلق',
  114: 'الناس',
};

String quranSurahName(int number) => quranSurahNames[number] ?? 'سورة $number';

String quranAyahDisplayName(String key) => parseAyahKey(key).displayName;

bool shouldShowBasmalahForPosition(QuranReadingPosition position) {
  return position.ayah == 1 && position.surah != 1 && position.surah != 9;
}

bool shouldShowBasmalahForKey(String ayahKey) {
  return shouldShowBasmalahForPosition(parseAyahKey(ayahKey));
}

class QuranWird {
  const QuranWird({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final QuranReadingPosition position;

  String get encoded {
    return [
      id,
      Uri.encodeComponent(name),
      position.surah,
      position.ayah,
    ].join('|');
  }

  QuranWird copyWith({String? name, QuranReadingPosition? position}) {
    return QuranWird(
      id: id,
      name: name ?? this.name,
      position: position ?? this.position,
    );
  }

  static QuranWird? tryDecode(String value) {
    final parts = value.split('|');
    if (parts.length < 4) {
      return null;
    }
    final id = parts[0].trim();
    final name = Uri.decodeComponent(parts[1]).trim();
    final surah = int.tryParse(parts[2]) ?? 1;
    final ayah = int.tryParse(parts[3]) ?? 1;
    if (id.isEmpty) {
      return null;
    }
    return QuranWird(
      id: id,
      name: name.isEmpty ? 'ورد قرآن' : name,
      position: QuranReadingPosition(
        surah: surah.clamp(1, 114),
        ayah: ayah.clamp(1, 286),
      ),
    );
  }
}

List<QuranWird> loadSavedQuranWirds(LocalQuranProgressRepository repository) {
  return repository.quranWirdRecords
      .map(QuranWird.tryDecode)
      .whereType<QuranWird>()
      .toList(growable: false);
}

Future<void> saveQuranWirds(
  LocalQuranProgressRepository repository,
  List<QuranWird> wirds,
) {
  return repository.setQuranWirdRecords(
    wirds.map((wird) => wird.encoded).toList(growable: false),
  );
}

Future<void> activateQuranWird(
  LocalQuranProgressRepository repository,
  QuranWird wird,
) async {
  await repository.setActiveQuranWirdId(wird.id);
  await saveReadingPosition(repository, wird.position.key);
}

Future<void> updateActiveQuranWirdPosition(
  LocalQuranProgressRepository repository,
  QuranReadingPosition position,
) async {
  final activeId = repository.activeQuranWirdId?.trim();
  if (activeId == null || activeId.isEmpty) {
    return;
  }
  final wirds = loadSavedQuranWirds(repository);
  final index = wirds.indexWhere((wird) => wird.id == activeId);
  if (index == -1) {
    return;
  }
  final updated = [...wirds];
  updated[index] = updated[index].copyWith(position: position);
  await saveQuranWirds(repository, updated);
}

Future<QuranReadingPosition> loadSavedReadingPosition(
  LocalQuranProgressRepository repository,
) async {
  final progress = await repository.load();
  return QuranReadingPosition(
    surah: progress.lastReadSurah > 0 ? progress.lastReadSurah : 1,
    ayah: progress.lastReadAyah > 0 ? progress.lastReadAyah : 1,
  );
}

Future<void> saveReadingPosition(
  LocalQuranProgressRepository repository,
  String ayahKey,
) async {
  final progress = await repository.load();
  final position = parseAyahKey(ayahKey);
  await repository.save(
    progress.copyWith(
      lastReadSurah: position.surah,
      lastReadAyah: position.ayah,
    ),
  );
  await updateActiveQuranWirdPosition(repository, position);
}

QuranReadingPosition parseAyahKey(String ayahKey) {
  final parts = ayahKey.split(':');
  final surah = int.tryParse(parts.first) ?? 1;
  final ayah = parts.length > 1 ? int.tryParse(parts.last) ?? 1 : 1;
  return QuranReadingPosition(surah: surah, ayah: ayah);
}

Future<String> resolveNextAyahKey({
  required QuranService service,
  required String currentKey,
  required QuranPagePayload? currentPagePayload,
  required int currentPageNumber,
}) async {
  final verses = currentPagePayload?.verses ?? const <QuranVersePayload>[];
  final currentIndex = verses.indexWhere((verse) => verse.key == currentKey);

  if (currentIndex != -1 && currentIndex < verses.length - 1) {
    return verses[currentIndex + 1].key;
  }

  if (currentIndex == verses.length - 1 && currentPageNumber < 604) {
    final nextPagePayload = await service.getPage(currentPageNumber + 1);
    if (nextPagePayload != null && nextPagePayload.verses.isNotEmpty) {
      return nextPagePayload.verses.first.key;
    }
  }

  return incrementAyahKey(currentKey);
}

String incrementAyahKey(String key) {
  final parts = key.split(':');
  final surah = int.tryParse(parts.first) ?? 1;
  final ayah = parts.length > 1 ? int.tryParse(parts.last) ?? 1 : 1;
  return '$surah:${ayah + 1}';
}

bool isKahfCompletionKey(String ayahKey) {
  final position = parseAyahKey(ayahKey);
  return position.surah > 18 || (position.surah == 18 && position.ayah >= 110);
}

bool isKahfCompletionPage(int page) => page >= 304;
