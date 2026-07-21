import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';

class AdminDashboardLocalizer {
  const AdminDashboardLocalizer._(this.locale);

  factory AdminDashboardLocalizer.of(BuildContext context) {
    return AdminDashboardLocalizer._(Localizations.localeOf(context));
  }

  final Locale locale;

  String get languageCode => locale.languageCode.toLowerCase();

  bool get isArabic => languageCode.startsWith('ar');
  bool get isFrench => languageCode.startsWith('fr');

  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  String text({required String ar, required String en, required String fr}) {
    if (isArabic) {
      return ar;
    }
    if (isFrench) {
      return fr;
    }
    return en;
  }

  String routeTitle(String route) {
    switch (route) {
      case AppRouter.adminDashboardHomeRoute:
        return text(ar: 'لوحة التحكم', en: 'Admin Dashboard', fr: 'Tableau');
      case AppRouter.adminDashboardUsersRoute:
        return text(ar: 'المستخدمون', en: 'Users', fr: 'Utilisateurs');
      case AppRouter.adminDashboardPermissionsRoute:
        return text(ar: 'الصلاحيات', en: 'Permissions', fr: 'Autorisations');
      case AppRouter.adminDashboardSubscriptionsRoute:
        return text(ar: 'الاشتراكات', en: 'Subscriptions', fr: 'Abonnements');
      case AppRouter.adminDashboardLanguagesRoute:
        return text(ar: 'اللغات', en: 'Languages', fr: 'Langues');
      case AppRouter.adminDashboardAzkarRoute:
        return text(ar: 'الأذكار', en: 'Azkar', fr: 'Adhkar');
      case AppRouter.adminDashboardDuasRoute:
        return text(ar: 'الأدعية', en: 'Duas', fr: 'Invocations');
      case AppRouter.adminDashboardMoshafRoute:
        return text(ar: 'المصحف', en: 'Mushaf', fr: 'Mushaf');
      case AppRouter.adminDashboardHadithRoute:
        return text(ar: 'الأحاديث', en: 'Hadith', fr: 'Hadith');
      case AppRouter.adminDashboardAdhanRoute:
        return text(ar: 'الأذان', en: 'Adhan', fr: 'Adhan');
      case AppRouter.adminDashboardRecitersRoute:
        return text(ar: 'القراء', en: 'Reciters', fr: 'Récitateurs');
      case AppRouter.adminDashboardLessonsRoute:
        return text(ar: 'الدروس والمحاضرات', en: 'Lessons', fr: 'Cours');
      case AppRouter.adminDashboardNasheedsRoute:
        return text(ar: 'الأناشيد', en: 'Nasheeds', fr: 'Anasheed');
      case AppRouter.adminDashboardThemesRoute:
        return text(ar: 'الثيمات', en: 'Themes', fr: 'Thèmes');
      case AppRouter.adminDashboardStoreRoute:
        return text(ar: 'المتجر', en: 'Store', fr: 'Boutique');
      case AppRouter.adminDashboardSharedRoute:
        return text(
          ar: 'الإعدادات المشتركة',
          en: 'Shared Settings',
          fr: 'Réglages partagés',
        );
      case AppRouter.adminDashboardGeneralSettingsRoute:
        return text(
          ar: 'الإعدادات العامة',
          en: 'General Settings',
          fr: 'Réglages généraux',
        );
      case AppRouter.adminDashboardAiUsageRoute:
        return text(ar: 'استخدام الذكاء الاصطناعي', en: 'AI Usage', fr: 'IA');
      case AppRouter.adminDashboardAppConfigRoute:
        return text(
          ar: 'تخصيص التطبيق',
          en: 'App Customization',
          fr: 'Personnalisation',
        );
      case AppRouter.adminDashboardMaintenanceRoute:
        return text(ar: 'الصيانة', en: 'Maintenance', fr: 'Maintenance');
      case AppRouter.adminDashboardSecurityRoute:
        return text(ar: 'الأمان', en: 'Security', fr: 'Sécurité');
      case AppRouter.adminDashboardDocsRoute:
        return text(ar: 'التوثيق', en: 'Documentation', fr: 'Documentation');
      case AppRouter.adminDashboardSupportRoute:
        return text(ar: 'الدعم', en: 'Support', fr: 'Support');
      case AppRouter.adminDashboardStreamRoute:
        return text(ar: 'الحلقات المباشرة', en: 'Halaqat', fr: 'Halaqat');
      default:
        return text(ar: 'الإدارة', en: 'Admin', fr: 'Admin');
    }
  }

  String routeSubtitle(String route) {
    switch (route) {
      case AppRouter.adminDashboardHomeRoute:
        return text(ar: 'نظرة عامة', en: 'Overview', fr: 'Vue d’ensemble');
      case AppRouter.adminDashboardUsersRoute:
        return text(
          ar: 'قراءة المستخدمين وإجراءات الإدارة',
          en: 'Users, roles, plans, and points',
          fr: 'Utilisateurs, rôles et points',
        );
      case AppRouter.adminDashboardPermissionsRoute:
        return text(
          ar: 'التحكم في الوصول',
          en: 'Access control',
          fr: 'Contrôle d’accès',
        );
      case AppRouter.adminDashboardSubscriptionsRoute:
        return text(
          ar: 'الأسعار والحدود',
          en: 'Pricing and limits',
          fr: 'Tarifs et limites',
        );
      case AppRouter.adminDashboardLanguagesRoute:
        return text(
          ar: 'اللغات النشطة',
          en: 'Active languages',
          fr: 'Langues actives',
        );
      case AppRouter.adminDashboardAzkarRoute:
      case AppRouter.adminDashboardDuasRoute:
        return text(
          ar: 'الأقسام والعناصر',
          en: 'Categories and items',
          fr: 'Catégories et éléments',
        );
      case AppRouter.adminDashboardMoshafRoute:
        return text(
          ar: 'خطوط القرآن وحزم المصحف',
          en: 'Quran fonts and Mushaf packs',
          fr: 'Polices Coran et packs Mushaf',
        );
      case AppRouter.adminDashboardHadithRoute:
        return text(
          ar: 'واجهة جاهزة بانتظار خط الاستيراد',
          en: 'Interface ready for import backend',
          fr: 'Interface prête pour le backend',
        );
      case AppRouter.adminDashboardAdhanRoute:
        return text(
          ar: 'أصوات الأذان والتنبيهات',
          en: 'Adhan sounds and notification audio',
          fr: 'Sons Adhan et notifications',
        );
      case AppRouter.adminDashboardRecitersRoute:
        return text(
          ar: 'مصاحف صوتية بروابط السور',
          en: 'Audio Mushaf by base URL',
          fr: 'Mushaf audio par URL',
        );
      case AppRouter.adminDashboardLessonsRoute:
        return text(
          ar: 'روابط الدروس والمحاضرات',
          en: 'Lessons and lecture links',
          fr: 'Liens de cours',
        );
      case AppRouter.adminDashboardNasheedsRoute:
        return text(
          ar: 'روابط ملفات الأناشيد الصوتية',
          en: 'Nasheed audio links',
          fr: 'Liens audio',
        );
      case AppRouter.adminDashboardThemesRoute:
        return text(
          ar: 'ثيمات المتجر ومعاينة الألوان',
          en: 'Store themes and color previews',
          fr: 'Thèmes boutique et couleurs',
        );
      case AppRouter.adminDashboardStoreRoute:
        return text(
          ar: 'كل منتجات المتجر',
          en: 'All store products',
          fr: 'Tous les produits',
        );
      case AppRouter.adminDashboardSharedRoute:
      case AppRouter.adminDashboardGeneralSettingsRoute:
      case AppRouter.adminDashboardAppConfigRoute:
        return text(
          ar: 'مسودة الإعدادات والنشر',
          en: 'Config draft and publishing',
          fr: 'Brouillon et publication',
        );
      case AppRouter.adminDashboardAiUsageRoute:
        return text(
          ar: 'المراجعة والضبط',
          en: 'Review and control',
          fr: 'Revue et contrôle',
        );
      case AppRouter.adminDashboardMaintenanceRoute:
        return text(
          ar: 'إجراءات مقفلة بدون endpoint',
          en: 'Guarded operations',
          fr: 'Opérations protégées',
        );
      case AppRouter.adminDashboardSecurityRoute:
        return text(
          ar: 'السجل الأمني والصلاحيات',
          en: 'Audit and access',
          fr: 'Audit et accès',
        );
      case AppRouter.adminDashboardDocsRoute:
        return text(
          ar: 'خرائط العمل وخطوات التشغيل',
          en: 'Runbooks and guides',
          fr: 'Guides',
        );
      case AppRouter.adminDashboardSupportRoute:
        return text(
          ar: 'واجهة دعم للقراءة فقط',
          en: 'Read-only support view',
          fr: 'Support lecture seule',
        );
      case AppRouter.adminDashboardStreamRoute:
        return text(
          ar: 'LiveKit لاحقًا',
          en: 'LiveKit later',
          fr: 'LiveKit plus tard',
        );
      default:
        return '';
    }
  }
}

String adminDashText(
  BuildContext context, {
  required String ar,
  required String en,
  required String fr,
}) {
  return AdminDashboardLocalizer.of(context).text(ar: ar, en: en, fr: fr);
}
