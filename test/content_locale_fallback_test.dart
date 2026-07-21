import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/localization/content_locale_fallback.dart';
import 'package:salati/features/store/models/store_catalog_item.dart';

void main() {
  group('ContentLocaleFallback', () {
    test('ar uses Arabic field', () {
      final value = ContentLocaleFallback.resolve(
        localeCode: 'ar',
        ar: 'عنوان عربي',
        en: 'English title',
        fr: 'Titre francais',
      );

      expect(value, 'عنوان عربي');
    });

    test('fr uses French field', () {
      final value = ContentLocaleFallback.resolve(
        localeCode: 'fr',
        ar: 'عنوان عربي',
        en: 'English title',
        fr: 'Titre francais',
      );

      expect(value, 'Titre francais');
    });

    test('unsupported locale falls back to English field', () {
      final value = ContentLocaleFallback.resolve(
        localeCode: 'de',
        ar: 'عنوان عربي',
        en: 'English title',
        fr: 'Titre francais',
      );

      expect(value, 'English title');
    });

    test('missing English falls back to Arabic field', () {
      final value = ContentLocaleFallback.resolve(
        localeCode: 'de',
        ar: 'عنوان عربي',
        fr: 'Titre francais',
      );

      expect(value, 'عنوان عربي');
    });

    test('store title does not fall back to technical unlock keys', () {
      const item = StoreCatalogItem(
        id: 'widget_next_prayer',
        type: 'widget_unlock',
        title: '',
        titleAr: '',
        titleEn: '',
        titleFr: '',
        description: '',
        previewUrl: '',
        value: 'next_prayer_widget',
        unlockKey: 'widget.next_prayer_widget',
        pricePoints: 30,
        requiredPlan: 'free',
        isActive: true,
      );

      expect(item.localizedTitle('de'), 'Widget');
      expect(item.localizedTitle('de'), isNot('widget_next_prayer'));
      expect(item.localizedTitle('de'), isNot('next_prayer_widget'));
      expect(item.localizedTitle('de'), isNot('widget.next_prayer_widget'));
    });
  });
}
