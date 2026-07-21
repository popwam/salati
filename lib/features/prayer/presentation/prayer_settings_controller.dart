import 'package:flutter/foundation.dart';

import '../data/prayer_settings_repository.dart';
import '../models/prayer_settings.dart';

class PrayerSettingsController extends ChangeNotifier {
  PrayerSettingsController({required PrayerSettingsRepository repository})
    : _repository = repository;

  final PrayerSettingsRepository _repository;

  PrayerSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  PrayerSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _settings = await _repository.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> save(PrayerSettings settings) async {
    _isSaving = true;
    notifyListeners();
    await _repository.save(settings);
    _settings = settings;
    _isSaving = false;
    notifyListeners();
  }
}
