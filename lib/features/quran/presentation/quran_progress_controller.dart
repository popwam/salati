import 'package:flutter/foundation.dart';

import '../../../core/services/analytics_service.dart';
import '../data/local_quran_progress_repository.dart';
import '../models/quran_progress.dart';

class QuranProgressController extends ChangeNotifier {
  QuranProgressController({
    required LocalQuranProgressRepository repository,
    required AnalyticsService analyticsService,
  }) : _repository = repository,
       _analyticsService = analyticsService;

  final LocalQuranProgressRepository _repository;
  final AnalyticsService _analyticsService;

  QuranProgress? _progress;
  bool _isLoading = true;
  bool _isSaving = false;

  QuranProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _progress = await _repository.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> save(QuranProgress progress) async {
    _isSaving = true;
    notifyListeners();
    final updatedProgress = progress.copyWith(lastUpdatedAt: DateTime.now());
    await _repository.save(updatedProgress);
    _progress = updatedProgress;
    _isSaving = false;
    notifyListeners();
    await _analyticsService.trackEvent(
      'quran_progress_saved',
      parameters: {
        'surah': updatedProgress.lastReadSurah,
        'ayah': updatedProgress.lastReadAyah,
        'goal_pages': updatedProgress.dailyGoalPages,
      },
    );
  }
}
