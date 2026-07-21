import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salati/core/services/app_preferences.dart';
import 'package:salati/features/adhkar/data/local_adhkar_progress_repository.dart';

void main() {
  test('resets completed adhkar when saved date is not today', () async {
    SharedPreferences.setMockInitialValues({
      'adhkar_completed': ['morning_1'],
      'adhkar_completed_date': '2026-01-01',
    });
    final preferences = AppPreferences(await SharedPreferences.getInstance());
    final repository = LocalAdhkarProgressRepository(preferences);

    final completed = await repository.loadCompleted();

    expect(completed, isEmpty);
    expect(preferences.adhkarCompletedDate, isNotNull);
  });
}
