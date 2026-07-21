import 'package:flutter/material.dart';

import '../../../core/models/operational_config.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_state_view.dart';
import '../models/daily_prayer_times.dart';
import '../models/prayer_settings.dart';
import '../services/local_prayer_times_service.dart';
import '../services/prayer_experience_service.dart';

class DailyResultsScreen extends StatefulWidget {
  const DailyResultsScreen({
    super.key,
    required this.settings,
    required this.preferences,
    required this.operationalConfig,
    required this.initialDate,
  });

  final PrayerSettings settings;
  final AppPreferences preferences;
  final OperationalConfig operationalConfig;
  final DateTime initialDate;

  @override
  State<DailyResultsScreen> createState() => _DailyResultsScreenState();
}

enum _CalendarDisplayMode { hijri, gregorian }

enum _PrayerResultState {
  prayed,
  prayedWithNawafil,
  missed,
  pending,
  upcoming,
  informational,
}

class _DailyResultsScreenState extends State<DailyResultsScreen> {
  static const PrayerExperienceService _experienceService =
      PrayerExperienceService();
  static const _obligatoryPrayerKeys = <String>{
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  };

  late DateTime _selectedDate;
  DailyPrayerTimes? _times;
  bool _isLoading = true;
  String? _error;
  _CalendarDisplayMode _calendarDisplayMode = _CalendarDisplayMode.hijri;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = LocalPrayerTimesService(
        operationalConfig: widget.operationalConfig,
      );
      final times = await service.getPrayerTimesForDate(
        settings: widget.settings,
        date: _selectedDate,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _times = times;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = mapAppErrorToArabic(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر اليوم',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);

    return Scaffold(
      appBar: AppBar(title: const Text('النتيجة')),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateView(label: 'جارٍ تحميل النتيجة');
    }

    if (_error != null) {
      return ErrorStateView(
        title: 'تعذر تحميل النتيجة',
        message: _error!,
        onRetry: _load,
      );
    }

    final times = _times;
    if (times == null) {
      return ErrorStateView(
        title: 'تعذر تحميل النتيجة',
        message: mapAppErrorToArabic(StateError('missing-prayer-times')),
        onRetry: _load,
      );
    }

    final hijriDate = _HijriDate.fromGregorian(_selectedDate);
    final summary = _buildSummary(times, DateTime.now());
    final qiyamSuggestion = _experienceService.calculateQiyamSuggestion(
      dailyTimes: times,
      preference: widget.settings.qiyamPreference,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _ResultsDateHero(
          selectedDate: _selectedDate,
          hijriDate: hijriDate,
          mode: _calendarDisplayMode,
          onModeChanged: (mode) {
            setState(() {
              _calendarDisplayMode = mode;
            });
          },
          onPickDate: _pickDate,
        ),
        const SizedBox(height: 16),
        _DailySummaryCard(summary: summary),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صلوات اليوم',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(times.locationLabel),
                const SizedBox(height: 4),
                Text(times.calculationLabel),
                const SizedBox(height: 16),
                ...times.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PrayerResultRow(
                      entry: entry,
                      state: _stateForPrayer(entry, DateTime.now()),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _SpecialMomentRow(
                  label: 'قيام الليل',
                  value: qiyamSuggestion.label,
                  subtitle: qiyamSuggestion.isApproximate
                      ? 'وقت تقريبي حسب تفضيلك'
                      : 'وقت مفضل حسب تفضيلك',
                  icon: Icons.nightlight_round,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _PrayerDaySummary _buildSummary(DailyPrayerTimes times, DateTime reference) {
    var score = 0.0;
    var completedCount = 0;
    var missedCount = 0;
    var pendingCount = 0;

    for (final entry in times.entries) {
      if (!_obligatoryPrayerKeys.contains(entry.key)) {
        continue;
      }

      switch (_stateForPrayer(entry, reference)) {
        case _PrayerResultState.prayed:
          score += 1;
          completedCount += 1;
          break;
        case _PrayerResultState.prayedWithNawafil:
          score += 1.25;
          completedCount += 1;
          break;
        case _PrayerResultState.missed:
          score -= 0.25;
          missedCount += 1;
          break;
        case _PrayerResultState.pending:
          score -= 0.25;
          pendingCount += 1;
          break;
        case _PrayerResultState.upcoming:
        case _PrayerResultState.informational:
          break;
      }
    }

    return _PrayerDaySummary(
      score: score,
      completedCount: completedCount,
      missedCount: missedCount,
      pendingCount: pendingCount,
    );
  }

  _PrayerResultState _stateForPrayer(
    PrayerTimeEntry entry,
    DateTime reference,
  ) {
    if (entry.key == 'sunrise') {
      return _PrayerResultState.informational;
    }

    final completed = widget.preferences.completedPrayerKeysForDate(entry.time);
    if (completed.contains(entry.key)) {
      final nawafil = widget.preferences.nawafilPrayerKeysForDate(entry.time);
      return nawafil.contains(entry.key)
          ? _PrayerResultState.prayedWithNawafil
          : _PrayerResultState.prayed;
    }

    final missed = widget.preferences.missedPrayerKeysForDate(entry.time);
    if (missed.contains(entry.key)) {
      return _PrayerResultState.missed;
    }

    if (!_obligatoryPrayerKeys.contains(entry.key)) {
      return _PrayerResultState.informational;
    }

    final selectedDay = DateUtils.dateOnly(entry.time);
    final today = DateUtils.dateOnly(reference);
    if (selectedDay.isBefore(today)) {
      return _PrayerResultState.pending;
    }
    if (selectedDay.isAfter(today)) {
      return _PrayerResultState.upcoming;
    }
    return entry.time.isAfter(reference)
        ? _PrayerResultState.upcoming
        : _PrayerResultState.pending;
  }
}

class _ResultsDateHero extends StatelessWidget {
  const _ResultsDateHero({
    required this.selectedDate,
    required this.hijriDate,
    required this.mode,
    required this.onModeChanged,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final _HijriDate hijriDate;
  final _CalendarDisplayMode mode;
  final ValueChanged<_CalendarDisplayMode> onModeChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hijriLabel = hijriDate.label;
    final gregorianLabel = _formatGregorian(selectedDate);
    final primaryLabel = mode == _CalendarDisplayMode.hijri
        ? hijriLabel
        : gregorianLabel;
    final secondaryLabel = mode == _CalendarDisplayMode.hijri
        ? gregorianLabel
        : hijriLabel;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('هجري'),
                selected: mode == _CalendarDisplayMode.hijri,
                onSelected: (_) => onModeChanged(_CalendarDisplayMode.hijri),
              ),
              ChoiceChip(
                label: const Text('ميلادي'),
                selected: mode == _CalendarDisplayMode.gregorian,
                onSelected: (_) =>
                    onModeChanged(_CalendarDisplayMode.gregorian),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            primaryLabel,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            secondaryLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withAlpha(215),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('اختيار يوم آخر'),
          ),
        ],
      ),
    );
  }

  String _formatGregorian(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.summary});

  final _PrayerDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreLabel = summary.score >= 0
        ? '+${summary.score.toStringAsFixed(2)}'
        : summary.score.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نتيجة اليوم',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              scoreLabel,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: summary.score >= 0
                    ? Colors.green.shade700
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ResultMetricChip(
                  label: 'المكتمل',
                  value: '${summary.completedCount}',
                  color: Colors.green,
                ),
                _ResultMetricChip(
                  label: 'المفوّت',
                  value: '${summary.missedCount}',
                  color: Colors.red,
                ),
                _ResultMetricChip(
                  label: 'غير المسجل',
                  value: '${summary.pendingCount}',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetricChip extends StatelessWidget {
  const _ResultMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withAlpha(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PrayerResultRow extends StatelessWidget {
  const _PrayerResultRow({required this.entry, required this.state});

  final PrayerTimeEntry entry;
  final _PrayerResultState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, icon) = switch (state) {
      _PrayerResultState.prayed => (
        'تم الفرض',
        Colors.green,
        Icons.check_circle,
      ),
      _PrayerResultState.prayedWithNawafil => (
        'فرض + نوافل',
        Colors.teal,
        Icons.auto_awesome_rounded,
      ),
      _PrayerResultState.missed => (
        'تم تسجيلها فائتة',
        theme.colorScheme.error,
        Icons.block,
      ),
      _PrayerResultState.pending => (
        '-0.25 لعدم التسجيل',
        Colors.orange.shade700,
        Icons.warning_amber_rounded,
      ),
      _PrayerResultState.upcoming => (
        'قادمة',
        theme.colorScheme.primary,
        Icons.schedule,
      ),
      _PrayerResultState.informational => (
        'محطة اليوم',
        Colors.blueGrey,
        Icons.wb_sunny_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            TimeOfDay.fromDateTime(entry.time).format(context),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialMomentRow extends StatelessWidget {
  const _SpecialMomentRow({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.secondaryContainer.withAlpha(110),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.secondary.withAlpha(26),
            child: Icon(icon, color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerDaySummary {
  const _PrayerDaySummary({
    required this.score,
    required this.completedCount,
    required this.missedCount,
    required this.pendingCount,
  });

  final double score;
  final int completedCount;
  final int missedCount;
  final int pendingCount;
}

class _HijriDate {
  const _HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  String get label => '$day ${_monthNames[month - 1]} $year هـ';

  static const _monthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  factory _HijriDate.fromGregorian(DateTime date) {
    final julianDay = _julianDay(date);
    final daysSinceEpoch = julianDay - 1948439;
    final year = ((30 * daysSinceEpoch + 10646) / 10631).floor();
    final firstDayOfYear =
        (354 * (year - 1)) + (((3 + (11 * year)) / 30).floor()) + 1;
    final dayOfYear = daysSinceEpoch - firstDayOfYear + 1;
    final monthIndex = ((dayOfYear - 1) / 29.5).floor().clamp(0, 11).toInt();
    final month = monthIndex + 1;
    final firstDayOfMonth = ((month - 1) * 29.5).floor() + 1;
    final day = (dayOfYear - firstDayOfMonth + 1).clamp(1, 30).toInt();

    return _HijriDate(year: year, month: month, day: day);
  }

  static int _julianDay(DateTime date) {
    final a = ((14 - date.month) / 12).floor();
    final y = date.year + 4800 - a;
    final m = date.month + (12 * a) - 3;
    return date.day +
        (((153 * m) + 2) / 5).floor() +
        (365 * y) +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;
  }
}
