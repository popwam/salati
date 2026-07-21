enum QiyamPreference { firstThird, secondThird, lastThird }

QiyamPreference qiyamPreferenceFromKey(String? value) {
  for (final item in QiyamPreference.values) {
    if (item.key == value) {
      return item;
    }
  }
  return QiyamPreference.lastThird;
}

extension QiyamPreferenceX on QiyamPreference {
  String get key {
    switch (this) {
      case QiyamPreference.firstThird:
        return 'first_third';
      case QiyamPreference.secondThird:
        return 'second_third';
      case QiyamPreference.lastThird:
        return 'last_third';
    }
  }

  String get label {
    switch (this) {
      case QiyamPreference.firstThird:
        return 'الثلث الأول';
      case QiyamPreference.secondThird:
        return 'الثلث الثاني';
      case QiyamPreference.lastThird:
        return 'الثلث الأخير';
    }
  }
}
