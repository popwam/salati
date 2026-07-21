// ignore_for_file: unused_element, unused_element_parameter

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/localization/content_locale_fallback.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/admin_dashboard_functions.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_store_repository.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_store_item.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

const _backendPendingMessage =
    'هذه العملية تحتاج endpoint في Backend وسيتم تفعيلها لاحقًا.';
const _hadithPendingMessage =
    'إدارة الأحاديث تحتاج مسار استيراد في Backend وسيتم تفعيله لاحقًا.';
const _usersPendingMessage =
    'إدارة المستخدمين تحتاج endpoints مخصصة في Backend.';
const _halaqatPendingMessage =
    'سيتم تفعيل إنشاء الحلقات بعد إضافة Backend/LiveKit.';
const _contentLanguageNote = 'اللغات المدعومة: العربية، الإنجليزية، الفرنسية.';

CollectionReference<Map<String, dynamic>> dashboardCollection(String path) {
  final cleanPath = path.trim();
  final segments = cleanPath.split('/').where((part) => part.isNotEmpty);
  if (segments.length.isEven) {
    throw ArgumentError.value(
      path,
      'path',
      'Dashboard collection paths must have an odd number of segments.',
    );
  }
  return FirebaseFirestore.instance.collection(cleanPath);
}

enum _FigmaPageKind {
  quranAssets,
  adhanSounds,
  themes,
  hadith,
  sharedSettings,
  generalSettings,
  maintenance,
  security,
  docs,
  support,
  stream,
  reciters,
  lessons,
  nasheeds,
}

class AdminDashboardFigmaScreen extends StatefulWidget {
  const AdminDashboardFigmaScreen._({
    required this.services,
    required this.firebaseConfigured,
    required _FigmaPageKind kind,
    required String currentRoute,
    required String requiredPermission,
  }) : _kind = kind,
       _currentRoute = currentRoute,
       _requiredPermission = requiredPermission;

  factory AdminDashboardFigmaScreen.quranAssets({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.quranAssets,
      currentRoute: AppRouter.adminDashboardMoshafRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.adhanSounds({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.adhanSounds,
      currentRoute: AppRouter.adminDashboardAdhanRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.themes({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.themes,
      currentRoute: AppRouter.adminDashboardThemesRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.reciters({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.reciters,
      currentRoute: AppRouter.adminDashboardRecitersRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.lessons({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.lessons,
      currentRoute: AppRouter.adminDashboardLessonsRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.nasheeds({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.nasheeds,
      currentRoute: AppRouter.adminDashboardNasheedsRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.hadith({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.hadith,
      currentRoute: AppRouter.adminDashboardHadithRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.sharedSettings({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.sharedSettings,
      currentRoute: AppRouter.adminDashboardSharedRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.generalSettings({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.generalSettings,
      currentRoute: AppRouter.adminDashboardGeneralSettingsRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.maintenance({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.maintenance,
      currentRoute: AppRouter.adminDashboardMaintenanceRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.security({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.security,
      currentRoute: AppRouter.adminDashboardSecurityRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.docs({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.docs,
      currentRoute: AppRouter.adminDashboardDocsRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.support({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.support,
      currentRoute: AppRouter.adminDashboardSupportRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  factory AdminDashboardFigmaScreen.stream({
    required AppServices services,
    required bool firebaseConfigured,
  }) {
    return AdminDashboardFigmaScreen._(
      services: services,
      firebaseConfigured: firebaseConfigured,
      kind: _FigmaPageKind.stream,
      currentRoute: AppRouter.adminDashboardStreamRoute,
      requiredPermission: AdminDashboardPermission.dashboardView,
    );
  }

  final AppServices services;
  final bool firebaseConfigured;
  final _FigmaPageKind _kind;
  final String _currentRoute;
  final String _requiredPermission;

  @override
  State<AdminDashboardFigmaScreen> createState() =>
      _AdminDashboardFigmaScreenState();
}

class _AdminDashboardFigmaScreenState extends State<AdminDashboardFigmaScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminStoreRepository _storeRepository;
  late final AdminDashboardFunctions _functions;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _storeRepository = FirestoreAdminStoreRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _functions = AdminDashboardFunctions();
  }

  Future<void> _saveAsset(_AssetSpec spec) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AssetDialog(spec: spec),
    );
    if (result == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _functions.call(spec.functionName, data: result);
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(context, message: spec.successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _importQuranManifest() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _JsonImportDialog(
        title: 'استيراد Manifest المصحف',
        sampleLabel: 'Quran/Mushaf JSON manifest',
        requiredKeys: ['id', 'nameAr', 'pricePoints', 'pageStart', 'pageEnd'],
      ),
    );
    if (payload == null) {
      return;
    }
    await _runFunctionAction(
      functionName: 'saveQuranManifest',
      data: payload,
      successMessage: 'تم استيراد Manifest المصحف.',
    );
  }

  Future<void> _importHadithPack() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _JsonImportDialog(
        title: 'استيراد حزمة أحاديث',
        sampleLabel: 'Hadith pack JSON',
        requiredKeys: ['id'],
        sourceNameLabel:
            '\u0627\u0633\u0645 \u0627\u0644\u0645\u0635\u062f\u0631',
        pointsLabel:
            '\u0639\u062f\u062f \u0627\u0644\u0646\u0642\u0627\u0637 \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629',
      ),
    );
    if (payload == null) {
      return;
    }
    await _runFunctionAction(
      functionName: 'importHadithPack',
      data: payload,
      successMessage: 'تم استيراد حزمة الأحاديث.',
    );
  }

  Future<void> _saveLessonMedia(_LessonMediaSpec spec) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _LessonMediaDialog(spec: spec),
    );
    if (payload == null) {
      return;
    }
    await _runFunctionAction(
      functionName: 'saveLessonMedia',
      data: payload,
      successMessage: spec.successMessage,
    );
  }

  Future<void> _saveHalaqaRoom() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _HalaqaRoomDialog(functions: _functions),
    );
    if (payload == null) {
      return;
    }
    await _runFunctionAction(
      functionName: 'saveHalaqaRoomMetadata',
      data: payload,
      successMessage: 'تم حفظ بيانات الحلقة.',
    );
  }

  Future<void> _runFunctionAction({
    required String functionName,
    required Map<String, dynamic> data,
    required String successMessage,
  }) async {
    setState(() => _isSaving = true);
    try {
      await _functions.call(functionName, data: data);
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(context, message: successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveQuickSettingsDraft() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _SettingsDraftDialog(),
    );
    if (result == null) {
      return;
    }
    await _runFunctionAction(
      functionName: 'saveAppConfigDraft',
      data: result,
      successMessage: 'تم حفظ مسودة الإعدادات.',
    );
  }

  Future<void> _saveStoreProduct(_StoreProductSpec spec) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StoreProductDialog(spec: spec),
    );
    if (result == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _storeRepository.createItem(data: result);
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(context, message: spec.successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminDashboardGuard(
      accessRepository: _accessRepository,
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
      requiredPermission: widget._requiredPermission,
      builder: (context, access) {
        final localizer = AdminDashboardLocalizer.of(context);
        return AdminDashboardScaffold(
          title: localizer.routeTitle(widget._currentRoute),
          currentRoute: widget._currentRoute,
          access: access,
          services: widget.services,
          child: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget._kind) {
      case _FigmaPageKind.quranAssets:
        final spec = _AssetSpec.quran();
        return _MinimalFigmaGridBody(
          spec: spec,
          icon: Icons.chrome_reader_mode_outlined,
          isSaving: _isSaving,
          onCreate: () => _saveAsset(spec),
          secondaryActionLabel: 'استيراد JSON',
          onSecondaryAction: _importQuranManifest,
        );
      case _FigmaPageKind.adhanSounds:
        final spec = _AssetSpec.adhan();
        return _MinimalFigmaGridBody(
          spec: spec,
          icon: Icons.volume_up_outlined,
          isSaving: _isSaving,
          onCreate: () => _saveAsset(spec),
        );
      case _FigmaPageKind.reciters:
        final spec = _AssetSpec.audioMushaf();
        return _MinimalFigmaGridBody(
          spec: spec,
          icon: Icons.record_voice_over_outlined,
          isSaving: _isSaving,
          onCreate: () => _saveAsset(spec),
        );
      case _FigmaPageKind.lessons:
        final spec = _LessonMediaSpec.lessons();
        return _LessonMediaLibraryBody(
          spec: spec,
          isSaving: _isSaving,
          onCreate: () => _saveLessonMedia(spec),
        );
      case _FigmaPageKind.nasheeds:
        final spec = _LessonMediaSpec.nasheeds();
        return _LessonMediaLibraryBody(
          spec: spec,
          isSaving: _isSaving,
          onCreate: () => _saveLessonMedia(spec),
        );
      case _FigmaPageKind.themes:
        final spec = _StoreProductSpec.themes();
        return _ThemeFigmaGridBody(
          spec: spec,
          repository: _storeRepository,
          isSaving: _isSaving,
          onCreate: () => _saveStoreProduct(spec),
        );
      case _FigmaPageKind.sharedSettings:
      case _FigmaPageKind.generalSettings:
        return _SettingsFigmaGrid(
          route: widget._currentRoute,
          isSaving: _isSaving,
          onEditSettings: _saveQuickSettingsDraft,
        );
      case _FigmaPageKind.hadith:
        return _HadithFigmaGridBody(
          isSaving: _isSaving,
          onImport: _importHadithPack,
        );
      case _FigmaPageKind.maintenance:
        return const _PendingVisualBody(
          headline: 'الصيانة',
          description: _backendPendingMessage,
          icon: Icons.construction_outlined,
          cards: [
            _VisualCardData('نسخ احتياطي', 'عط حت تفر endpoint'),
            _VisualCardData('تظف باات', 'ا تجد عات حذف باشرة'),
            _VisualCardData('إعادة بناء', 'تحتاج Admin SDK مخصص'),
          ],
        );
      case _FigmaPageKind.security:
        return const _PendingVisualBody(
          headline: 'الأمان',
          description:
              'سجل التدقيق متاح من الشاشة الرئيسية. تغييرات الصلاحيات تحتاج endpoints مخصصة.',
          icon: Icons.security_outlined,
          cards: [
            _VisualCardData('Audit logs', 'قراءة آخر الأحداث'),
            _VisualCardData('Roles', _usersPendingMessage),
            _VisualCardData('Firestore rules', 'لا تعديل من Flutter'),
          ],
        );
      case _FigmaPageKind.docs:
        return const _PendingVisualBody(
          headline: 'التوثيق',
          description: 'بطاات تث تشغة رتبطة بتفذ حة اتح.',
          icon: Icons.description_outlined,
          cards: [
            _VisualCardData('Dashboard map', 'ربط الشاشات بالتصاميم'),
            _VisualCardData('Backend flows', ' احفظ عبر callable Functions'),
            _VisualCardData('Manual QA', 'قائمة تحقق قبل النشر'),
          ],
        );
      case _FigmaPageKind.support:
        return const _PendingVisualBody(
          headline: 'الدعم',
          description: 'اجة دع راءة فط إ أ تفر backend حادثات.',
          icon: Icons.support_agent_outlined,
          cards: [
            _VisualCardData('Inbox', 'Placeholder للطلبات'),
            _VisualCardData('Chat', 'إرسال الرسائل معطل'),
            _VisualCardData('Status', 'لا يوجد backend دعم حاليًا'),
          ],
        );
      case _FigmaPageKind.stream:
        return _StreamFigmaPosterBody(
          isSaving: _isSaving,
          onCreate: _saveHalaqaRoom,
        );
    }
  }
}

class _AssetSpec {
  const _AssetSpec({
    required this.title,
    required this.description,
    required this.collectionPath,
    required this.functionName,
    required this.assetIdField,
    required this.addLabel,
    required this.successMessage,
    required this.typeOptions,
    required this.kindOptions,
    required this.extraFields,
    required this.supportedFiles,
    required this.note,
  });

  factory _AssetSpec.quran() {
    return const _AssetSpec(
      title: 'المصحف / أصول القرآن',
      description:
          'إدارة ملفات المصحف وخطوط القرآن من قاعدة البيانات، بدون عناصر تجريبية.',
      collectionPath: 'content/quran_assets/items',
      functionName: 'saveQuranAsset',
      assetIdField: 'assetId',
      addLabel: 'إضافة ملف قرآن',
      successMessage: 'تم حفظ ملف القرآن.',
      typeOptions: ['mushaf_pack', 'quran_font', 'audio_mushaf'],
      kindOptions: ['remote_pages'],
      extraFields: [
        _SimpleField('coverImageUrl', 'Cover image URL'),
        _SimpleField('pagesBaseUrl', 'رابط المجلد الأساسي للصفحات'),
        _SimpleField('pageFilePattern', 'نمط أسماء الصفحات مثل %03d.png'),
        _SimpleField('pageStart', 'أول صفحة', numeric: true),
        _SimpleField('pageEnd', 'آخر صفحة', numeric: true),
        _SimpleField('license', 'الرخصة'),
      ],
      supportedFiles: [
        'JSON Manifest لخريطة المصحف: page / file',
        'صور صفحات المصحف: png / jpg / webp',
        'ZIP يحتوي صور صفحات المصحف',
        'رابط خارجي Base للصور مثل 001.png',
        'خط قرآن ttf / otf أو رابط تحميل الخط',
      ],
      note:
          'الرفع المباشر للملفات يحتاج تخزين. هذا النموذج يحفظ metadata وروابط الملفات التي يقرأها التطبيق.',
    );
  }

  factory _AssetSpec.adhan() {
    return const _AssetSpec(
      title: 'أصوات الأذان',
      description:
          'إدارة أصوات الأذان الحقيقية من Firestore للمعاينة والتشغيل داخل التطبيق.',
      collectionPath: 'content/adhan_sounds/items',
      functionName: 'saveAdhanSound',
      assetIdField: 'soundId',
      addLabel: 'إضافة صوت أذان',
      successMessage: 'تم حفظ صوت الأذان.',
      typeOptions: ['adhan_sound'],
      kindOptions: ['remote_audio', 'bundled_raw'],
      extraFields: [
        _SimpleField('imageUrl', 'Preview image URL'),
        _SimpleField('audioUrl', 'رابط صوت خارجي'),
        _SimpleField('rawResourceName', 'اسم Android raw resource'),
        _SimpleField('mimeType', 'نوع الملف MIME'),
        _SimpleField('durationSeconds', 'مدة الصوت بالثواني', numeric: true),
      ],
      supportedFiles: [
        'ملف صوت: mp3 / m4a / wav',
        'Android raw resource داخل التطبيق مثل adhan_makkah',
        'رابط صوت خارجي للمعاينة أو التشغيل',
        'JSON Metadata: الاسم، القارئ، المدة، السعر، نوع الملف',
      ],
      note:
          'أصوات notification native لازم تكون داخل APK. الروابط الخارجية مناسبة للمعاينة أو التشغيل داخل التطبيق.',
    );
  }

  factory _AssetSpec.audioMushaf() {
    return const _AssetSpec(
      title: 'القراء / المصحف الصوتي',
      description:
          'أضف مصحفًا صوتيًا لقارئ من رابط أساسي، وسيتم حفظ نمط روابط السور مثل %03d.mp3 بدون رفع ملفات.',
      collectionPath: 'content/quran_assets/items',
      functionName: 'saveQuranAsset',
      assetIdField: 'assetId',
      addLabel: 'إضافة قارئ',
      successMessage: 'تم حفظ بيانات المصحف الصوتي.',
      typeOptions: ['audio_mushaf'],
      kindOptions: ['remote_audio'],
      extraFields: [
        _SimpleField('reciterName', 'اسم القارئ'),
        _SimpleField('audioBaseUrl', 'الرابط الأساسي لملفات السور'),
        _SimpleField('surahFilePattern', 'نمط اسم السورة مثل %03d.mp3'),
        _SimpleField('surahStart', 'أول سورة', numeric: true),
        _SimpleField('surahEnd', 'آخر سورة', numeric: true),
        _SimpleField('coverImageUrl', 'صورة القارئ'),
        _SimpleField('audioManifestUrl', 'رابط Manifest اختياري'),
        _SimpleField('license', 'الرخصة أو المصدر'),
      ],
      supportedFiles: [
        'رابط أساسي مثل https://example.com/reciter/',
        'نمط سور مثل %03d.mp3 ينتج 001.mp3 إلى 114.mp3',
        'رابط Manifest JSON اختياري عند وجود ملف فهرسة جاهز',
      ],
      note:
          'لا يتم رفع ملفات صوتية من الداشبورد. احفظ الرابط الأساسي ونمط أسماء السور ليستنتج التطبيق الروابط.',
    );
  }

  final String title;
  final String description;
  final String collectionPath;
  final String functionName;
  final String assetIdField;
  final String addLabel;
  final String successMessage;
  final List<String> typeOptions;
  final List<String> kindOptions;
  final List<_SimpleField> extraFields;
  final List<String> supportedFiles;
  final String note;
}

class _StoreProductSpec {
  const _StoreProductSpec({
    required this.title,
    required this.description,
    required this.type,
    required this.addLabel,
    required this.successMessage,
    required this.supportedFiles,
    required this.previewCards,
  });

  factory _StoreProductSpec.themes() {
    return const _StoreProductSpec(
      title: 'الثيمات',
      description:
          'ألوان الثيمات وصور المعاينة تأتي من بيانات المتجر المحفوظة.',
      type: 'theme',
      addLabel: 'إضافة ثيم',
      successMessage: 'تم حفظ الثيم.',
      supportedFiles: [
        'JSON ألوان: primaryColor / secondaryColor / backgroundColor / surfaceColor / textColor / isDark',
        'صورة Preview: png / jpg / webp',
        'ألوان مباشرة بصيغة HEX مثل #0F766E',
      ],
      previewCards: [
        _VisualCardData('Dark', 'ثيم داكن هادئ'),
        _VisualCardData('Light', 'ثيم فاتح وبسيط'),
        _VisualCardData('Safe', 'ثيم مريح للقراءة'),
      ],
    );
  }

  factory _StoreProductSpec.widgets() {
    return const _StoreProductSpec(
      title: 'منتجات الويدجت',
      description:
          'إدارة metadata للويدجت الموجودة داخل التطبيق، بدون رفع Kotlin أو XML من الداشبورد.',
      type: 'widget_unlock',
      addLabel: 'إضافة ويدجت',
      successMessage: 'تم حفظ منتج الويدجت.',
      supportedFiles: [
        'Metadata JSON: الاسم، النوع، السعر، الوصف',
        'صورة Preview: png / jpg / webp',
        'إعدادات تصميم: ألوان، عنوان، نوع الويدجت',
        'غير مسموح برفع .kt أو .xml لأنها تحتاج نسخة APK جديدة',
      ],
      previewCards: [
        _VisualCardData('points', 'نقاط اليوم'),
        _VisualCardData('next_prayer', 'الصلاة القادمة'),
        _VisualCardData('today_prayers', 'صلوات اليوم'),
        _VisualCardData('quran_ayah', 'آية اليوم'),
        _VisualCardData('adhkar', 'الأذكار المفضلة'),
        _VisualCardData('quick_controls', 'اختصارات سريعة'),
        _VisualCardData('quran_reading', 'متابعة القراءة'),
      ],
    );
  }

  final String title;
  final String description;
  final String type;
  final String addLabel;
  final String successMessage;
  final List<String> supportedFiles;
  final List<_VisualCardData> previewCards;
}

class _SimpleField {
  const _SimpleField(this.key, this.label, {this.numeric = false});

  final String key;
  final String label;
  final bool numeric;
}

class _MinimalFigmaGridBody extends StatelessWidget {
  const _MinimalFigmaGridBody({
    required this.spec,
    required this.icon,
    required this.isSaving,
    required this.onCreate,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final _AssetSpec spec;
  final IconData icon;
  final bool isSaving;
  final VoidCallback onCreate;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection(spec.collectionPath).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final titles = docs
            .map((doc) => _titleFromData(doc.id, doc.data()))
            .where((title) => title.trim().isNotEmpty)
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.only(top: 70),
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 28,
              children: [
                for (final title in titles)
                  _LargeFigmaTile(title: title, icon: icon),
                _LargeAddTile(
                  isBusy: isSaving,
                  onTap: onCreate,
                  onSecondaryTap: onSecondaryAction,
                ),
              ],
            ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 18),
              _StateCard(
                'تعذر تحميل البيانات',
                mapAppErrorToArabic(snapshot.error!),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ThemeFigmaGridBody extends StatelessWidget {
  const _ThemeFigmaGridBody({
    required this.spec,
    required this.repository,
    required this.isSaving,
    required this.onCreate,
  });

  final _StoreProductSpec spec;
  final FirestoreAdminStoreRepository repository;
  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminStoreItem>>(
      stream: repository.watchItems(),
      builder: (context, snapshot) {
        final saved = (snapshot.data ?? const <AdminStoreItem>[])
            .where((item) => item.type == spec.type)
            .toList(growable: false);
        final cards = saved
            .map(
              (item) => _ThemeTileData(
                item.displayTitle,
                _colorFromTheme(item, 'backgroundColor') ?? Colors.white,
                _colorFromTheme(item, 'primaryColor') ??
                    const Color(0xFF1479FF),
              ),
            )
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.only(top: 70),
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 28,
              children: [
                for (final card in cards) _ThemeFigmaTile(data: card),
                _LargeAddTile(isBusy: isSaving, onTap: onCreate),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WidgetFigmaGridBody extends StatelessWidget {
  const _WidgetFigmaGridBody({
    required this.spec,
    required this.repository,
    required this.isSaving,
    required this.onCreate,
  });

  final _StoreProductSpec spec;
  final FirestoreAdminStoreRepository repository;
  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminStoreItem>>(
      stream: repository.watchItems(),
      builder: (context, snapshot) {
        final saved = (snapshot.data ?? const <AdminStoreItem>[])
            .where((item) => item.type == spec.type)
            .map((item) => item.displayTitle)
            .toList(growable: false);
        final titles = saved;
        return ListView(
          padding: const EdgeInsets.only(top: 70),
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 28,
              children: [
                for (final title in titles)
                  _LargeFigmaTile(title: title, icon: Icons.widgets_outlined),
                _LargeAddTile(isBusy: isSaving, onTap: onCreate),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HadithFigmaGridBody extends StatelessWidget {
  const _HadithFigmaGridBody({required this.isSaving, required this.onImport});

  final bool isSaving;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection('content/hadith_packs/packs').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final titles = docs
            .map((doc) => _titleFromData(doc.id, doc.data()))
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.only(top: 70),
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 28,
              children: [
                for (final title in titles)
                  _LargeFigmaTile(
                    title: title,
                    icon: Icons.history_edu_outlined,
                  ),
                _LargeAddTile(isBusy: isSaving, onTap: onImport),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SettingsFigmaGrid extends StatelessWidget {
  const _SettingsFigmaGrid({
    required this.route,
    required this.isSaving,
    required this.onEditSettings,
  });

  final String route;
  final bool isSaving;
  final VoidCallback onEditSettings;

  @override
  Widget build(BuildContext context) {
    final localizer = AdminDashboardLocalizer.of(context);
    final isGeneral = route == AppRouter.adminDashboardGeneralSettingsRoute;
    final titles = isGeneral
        ? const ['إعدادات عامة', 'النقاط', 'الاشتراكات', 'اللغات']
        : const ['إعدادات مشتركة', 'الظهور', 'المحتوى', 'الخطط'];
    return ListView(
      padding: const EdgeInsets.only(top: 70),
      children: [
        Wrap(
          spacing: 28,
          runSpacing: 28,
          children: [
            for (final title in titles)
              _LargeFigmaTile(title: title, icon: Icons.settings_outlined),
            _LargeActionTile(
              title: localizer.routeTitle(route),
              actionText: isSaving ? 'جار احفظ...' : 'تعد',
              icon: Icons.tune_outlined,
              onTap: isSaving ? () {} : onEditSettings,
            ),
          ],
        ),
      ],
    );
  }
}

class _StreamFigmaPosterBody extends StatelessWidget {
  const _StreamFigmaPosterBody({
    required this.isSaving,
    required this.onCreate,
  });

  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection('content/halaqat/rooms').snapshots(),
      builder: (context, snapshot) {
        final rooms = snapshot.data?.docs ?? const [];
        final titles = rooms
            .map((doc) => _titleFromData(doc.id, doc.data()))
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.only(top: 36),
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 28,
              children: [
                for (var i = 0; i < titles.length; i++)
                  _StreamPosterTile(title: titles[i], index: i),
                _TallAddTile(isBusy: isSaving, onTap: onCreate),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LargeFigmaTile extends StatelessWidget {
  const _LargeFigmaTile({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 180,
      child: AdminDashboardSurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1479FF), size: 30),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D2D2D),
                fontSize: 15,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeAddTile extends StatelessWidget {
  const _LargeAddTile({
    required this.isBusy,
    required this.onTap,
    this.onSecondaryTap,
  });

  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 180,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: isBusy ? null : onTap,
        onLongPress: onSecondaryTap,
        child: AdminDashboardSurfaceCard(
          padding: EdgeInsets.zero,
          child: Center(
            child: isBusy
                ? const CircularProgressIndicator()
                : const Icon(Icons.add, color: Color(0xFF1479FF), size: 70),
          ),
        ),
      ),
    );
  }
}

class _LargeActionTile extends StatelessWidget {
  const _LargeActionTile({
    required this.title,
    required this.actionText,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String actionText;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 180,
      child: AdminDashboardSurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1479FF), size: 34),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onTap, child: Text(actionText)),
          ],
        ),
      ),
    );
  }
}

class _ThemeTileData {
  const _ThemeTileData(this.title, this.background, this.foreground);

  final String title;
  final Color background;
  final Color foreground;
}

class _ThemeFigmaTile extends StatelessWidget {
  const _ThemeFigmaTile({required this.data});

  final _ThemeTileData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 180,
      child: AdminDashboardSurfaceCard(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: data.background,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              data.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: data.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamPosterTile extends StatelessWidget {
  const _StreamPosterTile({required this.title, required this.index});

  final String title;
  final int index;

  @override
  Widget build(BuildContext context) {
    final gradients = [
      const [Color(0xFF3B1F1D), Color(0xFF151515)],
      const [Color(0xFF68736D), Color(0xFF202726)],
      const [Color(0xFF19244D), Color(0xFF382161)],
      const [Color(0xFF133A4A), Color(0xFF171B27)],
    ];
    final colors = gradients[index % gradients.length];
    return SizedBox(
      width: 240,
      height: 300,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.star, color: Color(0xFF00C9BC), size: 18),
                Icon(Icons.star, color: Color(0xFF00C9BC), size: 18),
                Icon(Icons.star, color: Color(0xFF00C9BC), size: 18),
                Icon(Icons.star, color: Color(0xFF00C9BC), size: 18),
                Icon(Icons.star, color: Color(0xFF00C9BC), size: 18),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 34),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00C9BC),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text('Watch'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TallAddTile extends StatelessWidget {
  const _TallAddTile({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 300,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: isBusy ? null : onTap,
        child: AdminDashboardSurfaceCard(
          padding: EdgeInsets.zero,
          child: Center(
            child: isBusy
                ? const CircularProgressIndicator()
                : const Icon(Icons.add, color: Color(0xFF1479FF), size: 76),
          ),
        ),
      ),
    );
  }
}

String _titleFromData(String fallback, Map<String, dynamic> data) {
  final translations = data['translations'];
  if (translations is Map) {
    final ar = translations['ar'];
    if (ar is Map && '${ar['title'] ?? ''}'.trim().isNotEmpty) {
      return '${ar['title']}'.trim();
    }
  }
  for (final key in ['titleAr', 'nameAr', 'title', 'name', 'titleEn']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}

Color? _colorFromTheme(AdminStoreItem item, String key) {
  final theme = item.metadataMap('theme').isNotEmpty
      ? item.metadataMap('theme')
      : item.metadataMap('colors');
  final value = theme[key];
  if (value is! String || !value.startsWith('#') || value.length != 7) {
    return null;
  }
  return Color(int.parse('FF${value.substring(1)}', radix: 16));
}

class _AssetCollectionBody extends StatelessWidget {
  const _AssetCollectionBody({
    required this.spec,
    required this.isSaving,
    required this.onCreate,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final _AssetSpec spec;
  final bool isSaving;
  final VoidCallback onCreate;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection(spec.collectionPath).snapshots(),
      builder: (context, snapshot) {
        final rows = snapshot.data?.docs ?? const [];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _FigmaHeader(
              title: spec.title,
              description: spec.description,
              icon: Icons.auto_stories_outlined,
              actionLabel: spec.addLabel,
              actionBusy: isSaving,
              onAction: onCreate,
              secondaryActionLabel: secondaryActionLabel,
              onSecondaryAction: onSecondaryAction,
            ),
            const SizedBox(height: 14),
            _NoteCard(text: spec.note),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _StateCard(
                'تعذر تحميل البيانات',
                mapAppErrorToArabic(snapshot.error!),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              _StateCard('لا توجد عناصر بعد', 'أضف أ عصر  ازر اع.')
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: rows
                    .map((doc) => _DocumentAssetCard(doc: doc))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _StoreProductBody extends StatelessWidget {
  const _StoreProductBody({
    required this.spec,
    required this.repository,
    required this.isSaving,
    required this.onCreate,
  });

  final _StoreProductSpec spec;
  final FirestoreAdminStoreRepository repository;
  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminStoreItem>>(
      stream: repository.watchItems(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <AdminStoreItem>[])
            .where((item) => item.type == spec.type)
            .toList(growable: false);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _FigmaHeader(
              title: spec.title,
              description: spec.description,
              icon: spec.type == 'theme'
                  ? Icons.palette_outlined
                  : Icons.widgets_outlined,
              actionLabel: spec.addLabel,
              actionBusy: isSaving,
              onAction: onCreate,
            ),
            const SizedBox(height: 14),
            if (spec.type == 'widget_unlock') ...[
              const _NoteCard(
                text:
                    'إضافة ع دجت جدد تحتاج تحدث اتطب شر سخة جددة ا  تثبت فات Kotlin/XML  اداشبرد. ذ اصفحة تدر metadata فتح ادجت اجدة فط.',
              ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: spec.previewCards
                  .map((card) => _PreviewTile(data: card))
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _StateCard(
                'تعذر تحميل المتجر',
                mapAppErrorToArabic(snapshot.error!),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty)
              _StateCard('ا تجد تجات حفظة', 'أضف أ تج  ازر اع.')
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: items
                    .map((item) => _StoreItemVisualCard(item: item))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _HadithImportBody extends StatelessWidget {
  const _HadithImportBody({required this.isSaving, required this.onImport});

  final bool isSaving;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection('content/hadith_packs/packs').snapshots(),
      builder: (context, snapshot) {
        final packs = snapshot.data?.docs ?? const [];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _FigmaHeader(
              title: 'إدارة الأحاديث',
              description:
                  'استراد حز JSON حفظة حا بد استخدا فاتح Sunnah API داخ Flutter.',
              icon: Icons.history_edu_outlined,
              actionLabel: 'استيراد JSON',
              actionBusy: isSaving,
              onAction: onImport,
            ),
            const SizedBox(height: 14),
            const _NoteCard(
              text:
                  'ت احفظ عبر importHadithPack إ content/hadith_packs/packs/{packId}/items. ا تجد فاتح API ف اتطب. $_hadithPendingMessage',
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _StateCard(
                'تعذر تحميل الأحاديث',
                mapAppErrorToArabic(snapshot.error!),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (packs.isEmpty)
              _StateCard('لا توجد حزم أحاديث', 'استرد أ ف JSON  ازر اع.')
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: packs
                    .map((doc) => _DocumentAssetCard(doc: doc))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _HalaqatBody extends StatelessWidget {
  const _HalaqatBody({required this.isSaving, required this.onCreate});

  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection('content/halaqat/rooms').snapshots(),
      builder: (context, snapshot) {
        final rooms = snapshot.data?.docs ?? const [];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _FigmaHeader(
              title: 'الحلقات المباشرة',
              description: 'إدارة باات غرف احات. ا جد LiveKit أ صت ف ذا اجزء.',
              icon: Icons.graphic_eq_outlined,
              actionLabel: 'إشاء غرفة',
              actionBusy: isSaving,
              onAction: onCreate,
            ),
            const SizedBox(height: 14),
            const _NoteCard(
              text:
                  'احد 20 ارئا/تحدثا شطا فط. استع غر حدد بذا ار. ا تسج ا فد. $_halaqatPendingMessage',
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _StateCard(
                'تعذر تحميل الحلقات',
                mapAppErrorToArabic(snapshot.error!),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (rooms.isEmpty)
              _StateCard('لا توجد حلقات', 'أشئ أ غرفة metadata  ازر اع.')
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: rooms
                    .map((doc) => _DocumentAssetCard(doc: doc))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _FigmaHeader extends StatelessWidget {
  const _FigmaHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.actionBusy,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final bool actionBusy;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminDashboardSurfaceCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconBox = Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: const Color(0xFF1479FF), size: 34),
          );
          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(description),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (secondaryActionLabel != null && onSecondaryAction != null)
                OutlinedButton.icon(
                  onPressed: actionBusy ? null : onSecondaryAction,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(secondaryActionLabel!),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1479FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: actionBusy ? null : onAction,
                icon: actionBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [iconBox, actions],
                ),
                const SizedBox(height: 16),
                textBlock,
              ],
            );
          }

          return Row(
            children: [
              iconBox,
              const SizedBox(width: 18),
              Expanded(child: textBlock),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _SettingsDraftDialog extends StatefulWidget {
  const _SettingsDraftDialog();

  @override
  State<_SettingsDraftDialog> createState() => _SettingsDraftDialogState();
}

class _SettingsDraftDialogState extends State<_SettingsDraftDialog> {
  final _themeNameController = TextEditingController();
  final _globalMessageController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _defaultWidgetStyleController = TextEditingController();
  final _defaultPlanController = TextEditingController(text: 'free');

  @override
  void dispose() {
    _themeNameController.dispose();
    _globalMessageController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _defaultWidgetStyleController.dispose();
    _defaultPlanController.dispose();
    super.dispose();
  }

  void _submit() {
    final data = <String, dynamic>{};
    void putText(String key, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        data[key] = value;
      }
    }

    putText('themeName', _themeNameController);
    putText('globalMessage', _globalMessageController);
    putText('primaryColorHex', _primaryColorController);
    putText('secondaryColorHex', _secondaryColorController);
    putText('defaultWidgetStyle', _defaultWidgetStyleController);
    putText('defaultUserPlanId', _defaultPlanController);
    if (data.isEmpty) {
      showAdminDashboardSnackBar(
        context,
        message: 'أضف إعدادا احدا ع اأ ب احفظ.',
        isError: true,
      );
      return;
    }
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل مسودة الإعدادات'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(_themeNameController, 'اسم الثيم'),
                    _field(_globalMessageController, 'رسالة عامة'),
                    _field(_primaryColorController, 'لون أساسي HEX'),
                    _field(_secondaryColorController, 'لون ثانوي HEX'),
                    _field(_defaultWidgetStyleController, 'ش ادجت اافتراض'),
                    _field(_defaultPlanController, 'اخطة اافتراضة'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ اسدة')),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _AssetDialog extends StatefulWidget {
  const _AssetDialog({required this.spec});

  final _AssetSpec spec;

  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  late final String _type = widget.spec.typeOptions.first;
  late final String _assetKind = widget.spec.kindOptions.first;
  String _selectedLanguageCode = 'ar';
  String _requiredPlan = 'free';
  String _selectedIcon = 'sun';
  final _pricePointsController = TextEditingController(text: '0');
  final _controllers = <String, TextEditingController>{};
  bool _active = true;
  bool _previewEnabled = true;

  @override
  void initState() {
    super.initState();
    for (final key in [
      'titleAr',
      'titleEn',
      'titleFr',
      ...widget.spec.extraFields.map((field) => field.key),
    ]) {
      _controllers[key] = TextEditingController(
        text: key == 'pageFilePattern'
            ? '%03d.png'
            : key == 'pageStart'
            ? '1'
            : key == 'pageEnd'
            ? '604'
            : key == 'surahFilePattern'
            ? '%03d.mp3'
            : key == 'surahStart'
            ? '1'
            : key == 'surahEnd'
            ? '114'
            : key == 'mimeType'
            ? 'audio/mpeg'
            : '',
      );
    }
  }

  @override
  void dispose() {
    _pricePointsController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _mainFileKey {
    if (widget.spec.functionName == 'saveAdhanSound') {
      return _assetKind == 'bundled_raw' ? 'rawResourceName' : 'audioUrl';
    }
    if (_type == 'audio_mushaf') {
      return 'audioBaseUrl';
    }
    if (_assetKind == 'bundled_font') {
      return 'fontAssetPath';
    }
    if (_assetKind == 'remote_font') {
      return 'fontUrl';
    }
    if (_assetKind == 'metadata_only') {
      return 'metadataUrl';
    }
    return 'pagesBaseUrl';
  }

  void _submit() {
    final hasTitle = [
      'titleAr',
      'titleEn',
      'titleFr',
    ].any((key) => (_controllers[key]?.text.trim() ?? '').isNotEmpty);
    if (!hasTitle) {
      showAdminDashboardSnackBar(
        context,
        message:
            '\u0627\u0643\u062a\u0628 \u0627\u0633\u0645 \u0627\u0644\u0639\u0631\u0636 \u0641\u064a \u0644\u063a\u0629 \u0648\u0627\u062d\u062f\u0629 \u0639\u0644\u0649 \u0627\u0644\u0623\u0642\u0644.',
        isError: true,
      );
      return;
    }

    final data = <String, dynamic>{
      'type': _type,
      'assetKind': _assetKind,
      'pricePoints': int.tryParse(_pricePointsController.text.trim()) ?? 0,
      'requiredPlan': _requiredPlan,
      'active': _active,
      if (widget.spec.functionName == 'saveAdhanSound')
        'previewEnabled': _previewEnabled,
    };
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        continue;
      }
      _SimpleField? field;
      for (final item in widget.spec.extraFields) {
        if (item.key == entry.key) {
          field = item;
          break;
        }
      }
      data[entry.key] = field?.numeric == true
          ? int.tryParse(value) ?? 0
          : value;
    }
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _selectedLanguageCode == 'ar';
    final fileController =
        _controllers[_mainFileKey] ?? _controllers.values.last;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = MediaQuery.sizeOf(context);
          final width = viewport.width < 520 ? viewport.width - 40 : 460.0;
          final height = viewport.height < 620 ? viewport.height - 40 : 580.0;
          return SizedBox(
            width: width,
            height: height.clamp(360.0, 640.0),
            child: Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Text(
                      widget.spec.addLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _languageTabs(),
                          const SizedBox(height: 28),
                          _figmaField(
                            controller:
                                _controllers[_titleKeyFor(
                                  _selectedLanguageCode,
                                )]!,
                            label: _titleLabelFor(_selectedLanguageCode),
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                          const SizedBox(height: 14),
                          _iconDropdown(isArabic: isArabic),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _figmaField(
                                  controller: _pricePointsController,
                                  label: isArabic
                                      ? '\u0639\u062f\u062f \u0627\u0644\u0646\u0642\u0627\u0637'
                                      : 'Points',
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _planDropdown(isArabic: isArabic),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _figmaField(
                            controller: fileController,
                            label: isArabic
                                ? '\u0627\u0644\u0645\u0644\u0641'
                                : 'File',
                            hintText: _fileHint(isArabic),
                            textDirection: TextDirection.ltr,
                            suffixIcon: Icons.upload_file_outlined,
                          ),
                          for (final field in widget.spec.extraFields)
                            if (field.key != _mainFileKey &&
                                _controllers[field.key] != null) ...[
                              const SizedBox(height: 14),
                              _figmaField(
                                controller: _controllers[field.key]!,
                                label: field.label,
                                keyboardType: field.numeric
                                    ? TextInputType.number
                                    : TextInputType.text,
                                textDirection: TextDirection.ltr,
                                maxLines:
                                    field.key.toLowerCase().contains('json')
                                    ? 5
                                    : 1,
                              ),
                            ],
                          if (widget.spec.functionName == 'saveAdhanSound')
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isArabic
                                    ? '\u062a\u0641\u0639\u064a\u0644 \u0627\u0644\u0645\u0639\u0627\u064a\u0646\u0629'
                                    : 'Preview enabled',
                              ),
                              value: _previewEnabled,
                              onChanged: (value) =>
                                  setState(() => _previewEnabled = value),
                            ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              isArabic ? '\u0645\u0641\u0639\u0644' : 'Active',
                            ),
                            value: _active,
                            onChanged: (value) =>
                                setState(() => _active = value),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(118, 44),
                                backgroundColor: const Color(0xFF58A5FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                isArabic
                                    ? '\u0627\u0644\u062a\u0627\u0644\u064a'
                                    : _selectedLanguageCode == 'fr'
                                    ? 'Le Prochain'
                                    : 'Next',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _fileHint(bool isArabic) {
    if (isArabic) {
      if (_type == 'audio_mushaf') {
        return 'ضع الرابط الأساسي مثل https://example.com/reciter/';
      }
      if (_assetKind == 'remote_pages') {
        return 'ضع الرابط الأساسي مثل https://raw.githubusercontent.com/.../master/';
      }
      if (widget.spec.functionName == 'saveAdhanSound') {
        return 'ضع رابط ملف الصوت mp3/m4a/wav';
      }
      return '\u0627\u062e\u062a\u0631 \u0627\u0644\u0645\u0644\u0641 \u0644\u0644\u062a\u062d\u0645\u064a\u0644';
    }
    if (_selectedLanguageCode == 'fr') {
      return 'Choisissez Le Fichier \u00c0 T\u00e9l\u00e9charger';
    }
    return 'Choose The File To Download';
  }

  String _titleKeyFor(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'titleEn';
      case 'fr':
        return 'titleFr';
      default:
        return 'titleAr';
    }
  }

  String _titleLabelFor(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'Display Name';
      case 'fr':
        return 'Nom D\u2019affichage';
      default:
        return '\u0627\u0633\u0645 \u0627\u0644\u0639\u0631\u0636';
    }
  }

  String _planLabel(String value) {
    switch (value) {
      case 'plus':
        return _selectedLanguageCode == 'ar' ? '\u0628\u0644\u0633' : 'Plus';
      case 'pro':
        return _selectedLanguageCode == 'ar' ? '\u0628\u0631\u0648' : 'Pro';
      default:
        return _selectedLanguageCode == 'ar'
            ? '\u0645\u062c\u0627\u0646\u064a'
            : _selectedLanguageCode == 'fr'
            ? 'Gratuit'
            : 'Free';
    }
  }

  String _iconLabel(String value) {
    switch (value) {
      case 'moon':
        return _selectedLanguageCode == 'ar'
            ? '\u0627\u0644\u0642\u0645\u0631'
            : _selectedLanguageCode == 'fr'
            ? 'La Lune'
            : 'The Moon';
      case 'book':
        return _selectedLanguageCode == 'ar'
            ? '\u0627\u0644\u0643\u062a\u0627\u0628'
            : _selectedLanguageCode == 'fr'
            ? 'Le Livre'
            : 'The Book';
      default:
        return _selectedLanguageCode == 'ar'
            ? '\u0627\u0644\u0634\u0645\u0633'
            : _selectedLanguageCode == 'fr'
            ? 'Le Soleil'
            : 'The Sun';
    }
  }

  Widget _languageTabs() {
    final tabs = const [
      ('en', 'English'),
      ('fr', 'Fran\u00e7ais'),
      ('ar', '\u0627\u0644\u0639\u0631\u0628\u064a\u0629'),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final tab in tabs) ...[
            SizedBox(
              width: 80,
              height: 34,
              child: OutlinedButton(
                onPressed: () => setState(() => _selectedLanguageCode = tab.$1),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _selectedLanguageCode == tab.$1
                      ? const Color(0xFF1479FF)
                      : const Color(0xFFEAF3FF),
                  foregroundColor: _selectedLanguageCode == tab.$1
                      ? Colors.white
                      : const Color(0xFF111827),
                  side: BorderSide(
                    color: _selectedLanguageCode == tab.$1
                        ? const Color(0xFF1479FF)
                        : const Color(0xFF98C5FF),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  tab.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (tab != tabs.last) const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  Widget _iconDropdown({required bool isArabic}) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedIcon,
      decoration: _figmaDecoration(
        isArabic
            ? '\u0627\u0644\u0623\u064a\u0642\u0648\u0646\u0629'
            : _selectedLanguageCode == 'fr'
            ? 'Ic\u00f4ne'
            : 'Icon',
      ),
      items: const ['sun', 'moon', 'book']
          .map(
            (icon) => DropdownMenuItem(
              value: icon,
              child: Row(
                children: [
                  Expanded(
                    child: Text(_iconLabel(icon), textAlign: TextAlign.center),
                  ),
                  const Icon(Icons.wb_sunny_outlined, size: 20),
                ],
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) =>
          setState(() => _selectedIcon = value ?? _selectedIcon),
    );
  }

  Widget _planDropdown({required bool isArabic}) {
    return DropdownButtonFormField<String>(
      initialValue: _requiredPlan,
      decoration: _figmaDecoration(
        isArabic
            ? '\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643'
            : _selectedLanguageCode == 'fr'
            ? 'Abonnement'
            : 'Subscription',
      ),
      items: const ['free', 'plus', 'pro']
          .map(
            (plan) => DropdownMenuItem(
              value: plan,
              child: Text(_planLabel(plan), textAlign: TextAlign.center),
            ),
          )
          .toList(growable: false),
      onChanged: (value) =>
          setState(() => _requiredPlan = value ?? _requiredPlan),
    );
  }

  Widget _figmaField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    TextDirection? textDirection,
    IconData? suffixIcon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: textDirection,
      textAlign: textDirection == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
      decoration: _figmaDecoration(
        label,
        hintText: hintText,
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _figmaDecoration(
    String label, {
    String? hintText,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1479FF), width: 2),
      ),
    );
  }
}

class _JsonImportDialog extends StatefulWidget {
  const _JsonImportDialog({
    required this.title,
    required this.sampleLabel,
    required this.requiredKeys,
    this.sourceNameLabel,
    this.pointsLabel,
  });

  final String title;
  final String sampleLabel;
  final List<String> requiredKeys;
  final String? sourceNameLabel;
  final String? pointsLabel;

  @override
  State<_JsonImportDialog> createState() => _JsonImportDialogState();
}

class _JsonImportDialogState extends State<_JsonImportDialog> {
  final _controller = TextEditingController();
  final _sourceNameController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');
  Map<String, dynamic>? _payload;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _sourceNameController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      final decoded = jsonDecode(_controller.text.trim());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSON root must be an object.');
      }
      final missing = widget.requiredKeys
          .where((key) => !decoded.containsKey(key))
          .toList(growable: false);
      setState(() {
        _payload = _withExtraFields(decoded);
        _error = missing.isEmpty ? null : 'Missing keys: ${missing.join(', ')}';
      });
    } catch (error) {
      setState(() {
        _payload = null;
        _error = 'Invalid JSON: $error';
      });
    }
  }

  Map<String, dynamic> _withExtraFields(Map<String, dynamic> decoded) {
    final next = Map<String, dynamic>.from(decoded);
    final sourceName = _sourceNameController.text.trim();
    if (widget.sourceNameLabel != null && sourceName.isNotEmpty) {
      next['titleAr'] = next['titleAr'] ?? sourceName;
      next['titleEn'] = next['titleEn'] ?? sourceName;
    }
    if (widget.pointsLabel != null) {
      next['pricePoints'] =
          int.tryParse(_pointsController.text.trim()) ??
          next['pricePoints'] ??
          0;
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final items = payload?['items'];
    final pages = payload?['pages'];
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.sampleLabel}: الصق محتوى JSON هنا.'),
              const SizedBox(height: 10),
              if (widget.sourceNameLabel != null) ...[
                TextField(
                  controller: _sourceNameController,
                  decoration: InputDecoration(
                    labelText: widget.sourceNameLabel,
                  ),
                  onChanged: (_) => _parse(),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.pointsLabel != null) ...[
                TextField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: widget.pointsLabel),
                  onChanged: (_) => _parse(),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _controller,
                minLines: 12,
                maxLines: 18,
                decoration: const InputDecoration(
                  labelText: 'JSON',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => _parse(),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (payload != null && _error == null)
                _ImportPreview(
                  title:
                      '${payload['titleAr'] ?? payload['nameAr'] ?? payload['id']}',
                  pricePoints: payload['pricePoints'],
                  count: items is List
                      ? items.length
                      : pages is List
                      ? pages.length
                      : null,
                  first: payload['pageStart'],
                  last: payload['pageEnd'],
                  baseUrl: payload['pagesBaseUrl'],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: payload != null && _error == null
              ? () => Navigator.of(context).pop(payload)
              : null,
          child: const Text('استيراد'),
        ),
      ],
    );
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({
    required this.title,
    required this.pricePoints,
    required this.count,
    required this.first,
    required this.last,
    required this.baseUrl,
  });

  final String title;
  final Object? pricePoints;
  final int? count;
  final Object? first;
  final Object? last;
  final Object? baseUrl;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Count: ${count ?? '-'}'),
          Text('Price points: ${pricePoints ?? 0}'),
          if (first != null || last != null) Text('Pages: $first - $last'),
          if (baseUrl != null) Text('Base URL: $baseUrl'),
        ],
      ),
    );
  }
}

class _SupportedFormatNote extends StatelessWidget {
  const _SupportedFormatNote({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'صيغة الملفات المدعومة',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $item'),
            ),
        ],
      ),
    );
  }
}

class _LessonMediaSpec {
  const _LessonMediaSpec({
    required this.type,
    required this.title,
    required this.description,
    required this.addLabel,
    required this.successMessage,
    required this.icon,
    required this.defaultMediaKind,
  });

  factory _LessonMediaSpec.lessons() {
    return const _LessonMediaSpec(
      type: 'lesson',
      title: 'الدروس والمحاضرات',
      description:
          'أضف رابط فيديو أو صوت للدرس بدون رفع ملفات. يمكن استخدام YouTube أو رابط مباشر.',
      addLabel: 'إضافة درس',
      successMessage: 'تم حفظ بيانات الدرس.',
      icon: Icons.school_outlined,
      defaultMediaKind: 'video',
    );
  }

  factory _LessonMediaSpec.nasheeds() {
    return const _LessonMediaSpec(
      type: 'nasheed',
      title: 'الأناشيد',
      description: 'أضف رابط ملف صوتي للنشيد مع صورة اختيارية وتصنيف بسيط.',
      addLabel: 'إضافة نشيد',
      successMessage: 'تم حفظ بيانات النشيد.',
      icon: Icons.library_music_outlined,
      defaultMediaKind: 'audio',
    );
  }

  final String type;
  final String title;
  final String description;
  final String addLabel;
  final String successMessage;
  final IconData icon;
  final String defaultMediaKind;
}

class _LessonMediaLibraryBody extends StatelessWidget {
  const _LessonMediaLibraryBody({
    required this.spec,
    required this.isSaving,
    required this.onCreate,
  });

  final _LessonMediaSpec spec;
  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dashboardCollection('content/lesson_media/items').snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? const [])
            .where((doc) => '${doc.data()['type'] ?? 'lesson'}' == spec.type)
            .toList(growable: false);

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _FigmaHeader(
              title: spec.title,
              description: spec.description,
              icon: spec.icon,
              actionLabel: spec.addLabel,
              actionBusy: isSaving,
              onAction: onCreate,
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _StateCard(
                'تعذر تحميل البيانات',
                mapAppErrorToArabic(snapshot.error!),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (docs.isEmpty)
              _StateCard('لا توجد عناصر', 'اضغط زر الإضافة لحفظ أول عنصر.')
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: docs
                    .map((doc) => _DocumentAssetCard(doc: doc))
                    .toList(growable: false),
              ),
          ],
        );
      },
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LessonMediaDialog extends StatefulWidget {
  const _LessonMediaDialog({required this.spec});

  final _LessonMediaSpec spec;

  @override
  State<_LessonMediaDialog> createState() => _LessonMediaDialogState();
}

class _LessonMediaDialogState extends State<_LessonMediaDialog> {
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _titleFr = TextEditingController();
  final _descriptionAr = TextEditingController();
  final _descriptionEn = TextEditingController();
  final _descriptionFr = TextEditingController();
  final _previewUrl = TextEditingController();
  final _categoryId = TextEditingController();
  final _categoryTitleAr = TextEditingController();
  final _categoryTitleEn = TextEditingController();
  final _categoryTitleFr = TextEditingController();
  final _pricePoints = TextEditingController(text: '0');
  final _mediaUrl = TextEditingController();
  late String _mediaKind = widget.spec.defaultMediaKind;
  bool _active = true;

  @override
  void dispose() {
    for (final controller in [
      _titleAr,
      _titleEn,
      _titleFr,
      _descriptionAr,
      _descriptionEn,
      _descriptionFr,
      _previewUrl,
      _categoryId,
      _categoryTitleAr,
      _categoryTitleEn,
      _categoryTitleFr,
      _pricePoints,
      _mediaUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final hasTitle =
        _titleAr.text.trim().isNotEmpty ||
        _titleEn.text.trim().isNotEmpty ||
        _titleFr.text.trim().isNotEmpty;
    if (!hasTitle || _mediaUrl.text.trim().isEmpty) {
      showAdminDashboardSnackBar(
        context,
        message: 'اكتب العنوان وأضف رابط الملف قبل الحفظ.',
        isError: true,
      );
      return;
    }
    Navigator.of(context).pop({
      'type': widget.spec.type,
      if (_titleAr.text.trim().isNotEmpty) 'titleAr': _titleAr.text.trim(),
      if (_titleEn.text.trim().isNotEmpty) 'titleEn': _titleEn.text.trim(),
      if (_titleFr.text.trim().isNotEmpty) 'titleFr': _titleFr.text.trim(),
      if (_descriptionAr.text.trim().isNotEmpty)
        'descriptionAr': _descriptionAr.text.trim(),
      if (_descriptionEn.text.trim().isNotEmpty)
        'descriptionEn': _descriptionEn.text.trim(),
      if (_descriptionFr.text.trim().isNotEmpty)
        'descriptionFr': _descriptionFr.text.trim(),
      if (_previewUrl.text.trim().isNotEmpty)
        'imageUrl': _previewUrl.text.trim(),
      if (_categoryId.text.trim().isNotEmpty)
        'categoryId': _categoryId.text.trim(),
      if (_categoryTitleAr.text.trim().isNotEmpty)
        'categoryTitleAr': _categoryTitleAr.text.trim(),
      if (_categoryTitleEn.text.trim().isNotEmpty)
        'categoryTitleEn': _categoryTitleEn.text.trim(),
      if (_categoryTitleFr.text.trim().isNotEmpty)
        'categoryTitleFr': _categoryTitleFr.text.trim(),
      'icon': widget.spec.type == 'nasheed'
          ? 'library_music_outlined'
          : 'school_outlined',
      'pricePoints': int.tryParse(_pricePoints.text.trim()) ?? 0,
      'mediaKind': _mediaKind,
      'mediaUrl': _mediaUrl.text.trim(),
      'durationSeconds': 0,
      'active': _active,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.spec.addLabel),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(_contentLanguageNote),
              const SizedBox(height: 10),
              const _DialogSectionLabel('القسم'),
              _field(_categoryTitleAr, 'اسم القسم بالعربية'),
              _field(_categoryTitleEn, 'Category name in English'),
              _field(_categoryTitleFr, 'Nom de categorie en francais'),
              _field(_categoryId, 'معرف القسم اختياري'),
              const SizedBox(height: 10),
              const _DialogSectionLabel('بيانات العنصر'),
              _field(_titleAr, 'العنوان بالعربية'),
              _field(_titleEn, 'English title'),
              _field(_titleFr, 'Titre francais'),
              _field(_descriptionAr, 'الوصف بالعربية', maxLines: 2),
              _field(_descriptionEn, 'English description', maxLines: 2),
              _field(_descriptionFr, 'Description francaise', maxLines: 2),
              const SizedBox(height: 10),
              const _DialogSectionLabel('الرابط والصورة'),
              DropdownButtonFormField<String>(
                initialValue: _mediaKind,
                decoration: const InputDecoration(labelText: 'نوع الملف'),
                items: const ['video', 'audio']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _mediaKind = value ?? _mediaKind),
              ),
              const SizedBox(height: 10),
              _field(_mediaUrl, 'رابط YouTube أو رابط مباشر للملف'),
              _field(_previewUrl, 'رابط الصورة'),
              _field(_pricePoints, 'عدد النقاط'),
              const _SupportedFormatNote(
                items: [
                  'فيديو: mp4 / mov / webm أو YouTube',
                  'صوت: mp3 / m4a / wav',
                  'رابط مباشر أو مسار Firebase Storage',
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('مفعل'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _StoreProductDialog extends StatefulWidget {
  const _StoreProductDialog({required this.spec});

  final _StoreProductSpec spec;

  @override
  State<_StoreProductDialog> createState() => _StoreProductDialogState();
}

class _StoreProductDialogState extends State<_StoreProductDialog> {
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _titleFr = TextEditingController();
  final _descriptionAr = TextEditingController();
  final _descriptionEn = TextEditingController();
  final _descriptionFr = TextEditingController();
  final _previewUrl = TextEditingController();
  final _pricePoints = TextEditingController(text: '0');
  final _primary = TextEditingController(text: '#0F766E');
  final _secondary = TextEditingController(text: '#B8A84E');
  final _background = TextEditingController(text: '#EAF3F1');
  final _surface = TextEditingController(text: '#F8FBFA');
  final _text = TextEditingController(text: '#1F2933');
  String _requiredPlan = 'free';
  String _widgetType = 'next_prayer';
  bool _active = true;
  bool _isDark = false;

  @override
  void dispose() {
    for (final controller in [
      _titleAr,
      _titleEn,
      _titleFr,
      _descriptionAr,
      _descriptionEn,
      _descriptionFr,
      _previewUrl,
      _pricePoints,
      _primary,
      _secondary,
      _background,
      _surface,
      _text,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final titleAr = _titleAr.text.trim();
    final title = titleAr.isNotEmpty
        ? titleAr
        : _titleEn.text.trim().isNotEmpty
        ? _titleEn.text.trim()
        : _titleFr.text.trim();
    if (title.isEmpty) {
      showAdminDashboardSnackBar(
        context,
        message:
            '\u0627\u0643\u062a\u0628 \u0627\u0633\u0645 \u0627\u0644\u0639\u0631\u0636 \u0641\u064a \u0644\u063a\u0629 \u0648\u0627\u062d\u062f\u0629 \u0639\u0644\u0649 \u0627\u0644\u0623\u0642\u0644.',
        isError: true,
      );
      return;
    }
    final price = int.tryParse(_pricePoints.text.trim()) ?? 0;
    final data = <String, dynamic>{
      'type': widget.spec.type,
      'title': title,
      if (titleAr.isNotEmpty) 'titleAr': titleAr,
      if (_titleEn.text.trim().isNotEmpty) 'titleEn': _titleEn.text.trim(),
      if (_titleFr.text.trim().isNotEmpty) 'titleFr': _titleFr.text.trim(),
      if (_descriptionAr.text.trim().isNotEmpty)
        'descriptionAr': _descriptionAr.text.trim(),
      if (_descriptionEn.text.trim().isNotEmpty)
        'descriptionEn': _descriptionEn.text.trim(),
      if (_descriptionFr.text.trim().isNotEmpty)
        'descriptionFr': _descriptionFr.text.trim(),
      if (_previewUrl.text.trim().isNotEmpty)
        'previewUrl': _previewUrl.text.trim(),
      'pricePoints': price,
      'requiredPlan': _requiredPlan,
      'active': _active,
    };
    if (widget.spec.type == 'theme') {
      data['theme'] = {
        'primaryColor': _primary.text.trim(),
        'secondaryColor': _secondary.text.trim(),
        'backgroundColor': _background.text.trim(),
        'surfaceColor': _surface.text.trim(),
        'textColor': _text.text.trim(),
        'isDark': _isDark,
      };
      data['metadata'] = {
        'colors': {
          'primary': _primary.text.trim(),
          'secondary': _secondary.text.trim(),
          'background': _background.text.trim(),
          'surface': _surface.text.trim(),
          'text': _text.text.trim(),
        },
        'themeName': title,
        if (_previewUrl.text.trim().isNotEmpty)
          'previewUrl': _previewUrl.text.trim(),
      };
    } else {
      data['value'] = _widgetType;
      data['unlockKey'] = 'widget.$_widgetType';
      data['metadata'] = {
        'widgetType': _widgetType,
        'widgetName': title,
        if (_previewUrl.text.trim().isNotEmpty)
          'previewUrl': _previewUrl.text.trim(),
      };
    }
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final isTheme = widget.spec.type == 'theme';
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.spec.addLabel, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(_contentLanguageNote),
              const SizedBox(height: 12),
              _field(
                _titleAr,
                '\u0627\u0633\u0645 \u0627\u0644\u0639\u0631\u0636 \u0628\u0627\u0644\u0639\u0631\u0628\u064a\u0629',
              ),
              _field(_titleEn, 'English display name'),
              _field(_titleFr, 'Nom d\u2019affichage'),
              _field(
                _descriptionAr,
                '\u0627\u0644\u0648\u0635\u0641 \u0628\u0627\u0644\u0639\u0631\u0628\u064a\u0629',
                maxLines: 2,
              ),
              _field(_descriptionEn, 'English description', maxLines: 2),
              _field(_descriptionFr, 'Description fran\u00e7aise', maxLines: 2),
              _field(
                _previewUrl,
                isTheme
                    ? 'Theme preview image URL'
                    : 'Widget preview image URL',
              ),
              if (isTheme) ...[
                _field(_primary, 'Primary color'),
                _field(_secondary, 'Secondary color'),
                _field(_background, 'Background color'),
                _field(_surface, 'Surface color'),
                _field(_text, 'Text color'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark theme'),
                  value: _isDark,
                  onChanged: (value) => setState(() => _isDark = value),
                ),
              ] else
                DropdownButtonFormField<String>(
                  initialValue: _widgetType,
                  decoration: const InputDecoration(labelText: 'Widget type'),
                  items:
                      const [
                            'next_prayer',
                            'today_prayers',
                            'points',
                            'quick_controls',
                            'quran_ayah',
                            'adhkar',
                            'quran_reading',
                            'hadith',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _widgetType = value ?? _widgetType),
                ),
              const SizedBox(height: 10),
              _field(
                _pricePoints,
                '\u0639\u062f\u062f \u0627\u0644\u0646\u0642\u0627\u0637',
              ),
              DropdownButtonFormField<String>(
                initialValue: _requiredPlan,
                decoration: const InputDecoration(
                  labelText: '\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643',
                ),
                items: const ['free', 'plus', 'pro']
                    .map(
                      (plan) =>
                          DropdownMenuItem(value: plan, child: Text(plan)),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _requiredPlan = value ?? _requiredPlan),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('\u0645\u0641\u0639\u0644'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              _SupportedFormatNote(items: widget.spec.supportedFiles),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u0625\u0644\u063a\u0627\u0621'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('\u062d\u0641\u0638'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _DocumentAssetCard extends StatelessWidget {
  const _DocumentAssetCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    return SizedBox(
      width: 286,
      child: AdminDashboardSurfaceCard(
        minHeight: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localizedTitle(data),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['type'] ?? 'asset'} • ${data['assetKind'] ?? 'metadata'}',
            ),
            const SizedBox(height: 12),
            _StatusChip(active: data['isActive'] != false),
          ],
        ),
      ),
    );
  }
}

class _HalaqaRoomDialog extends StatefulWidget {
  const _HalaqaRoomDialog({required this.functions});

  final AdminDashboardFunctions functions;

  @override
  State<_HalaqaRoomDialog> createState() => _HalaqaRoomDialogState();
}

class _HalaqaRoomDialogState extends State<_HalaqaRoomDialog> {
  final _title = TextEditingController();
  final _roomCode = TextEditingController();
  final _hostSearch = TextEditingController();
  final _scheduledAt = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _maxReaders = TextEditingController(text: '20');
  final _pricePoints = TextEditingController(text: '0');
  final _listeners = TextEditingController(text: '0');
  final _activeReaders = TextEditingController(text: '0');
  String _status = 'scheduled';
  String _mode = 'limited_session';
  Map<String, dynamic>? _host;
  List<Map<String, dynamic>> _hostResults = const [];
  bool _searching = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _roomCode,
      _hostSearch,
      _scheduledAt,
      _duration,
      _maxReaders,
      _pricePoints,
      _listeners,
      _activeReaders,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _searchHosts() async {
    final query = _hostSearch.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await widget.functions.call(
        'searchDashboardUsersForHost',
        data: {'query': query, 'limit': 10},
      );
      final users = result['users'];
      setState(() {
        _hostResults = users is List
            ? users
                  .whereType<Map>()
                  .map(
                    (item) => item.map((key, value) => MapEntry('$key', value)),
                  )
                  .toList(growable: false)
            : const [];
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _submit() {
    final host = _host;
    final maxReaders = int.tryParse(_maxReaders.text.trim()) ?? 20;
    if (_title.text.trim().isEmpty ||
        _roomCode.text.trim().isEmpty ||
        host == null) {
      showAdminDashboardSnackBar(
        context,
        message:
            '\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u063a\u0631\u0641\u0629 \u0648\u0627\u0644\u0643\u0648\u062f \u0648\u0627\u0644\u0645\u0634\u0631\u0641 \u0645\u0637\u0644\u0648\u0628\u0629.',
        isError: true,
      );
      return;
    }
    if (maxReaders < 1 || maxReaders > 20) {
      showAdminDashboardSnackBar(
        context,
        message:
            '\u062d\u062f \u0627\u0644\u0642\u0631\u0627\u0621 \u0627\u0644\u0646\u0634\u0637\u064a\u0646 \u0645\u0646 1 \u0625\u0644\u0649 20 \u0641\u0642\u0637.',
        isError: true,
      );
      return;
    }
    Navigator.of(context).pop({
      'titleAr': _title.text.trim(),
      'roomCode': _roomCode.text.trim(),
      'hostUid': '${host['uid']}',
      'hostName': '${host['name'] ?? ''}',
      'hostEmail': '${host['email'] ?? ''}',
      'status': _status,
      'mode': _mode,
      if (_scheduledAt.text.trim().isNotEmpty)
        'scheduledAt': _scheduledAt.text.trim(),
      'durationMinutes': int.tryParse(_duration.text.trim()) ?? 60,
      'maxActiveReaders': maxReaders,
      'pricePoints': int.tryParse(_pricePoints.text.trim()) ?? 0,
      'activeReadersCount': int.tryParse(_activeReaders.text.trim()) ?? 0,
      'listenerCount': int.tryParse(_listeners.text.trim()) ?? 0,
      'recordingEnabled': false,
      'videoEnabled': false,
      'active': _status != 'archived',
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '\u0625\u0646\u0634\u0627\u0621 \u063a\u0631\u0641\u0629 \u062d\u0644\u0642\u0629',
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '\u0647\u0630\u0647 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u063a\u0631\u0641\u0629 \u0641\u0642\u0637. \u0627\u0644\u0645\u0634\u0631\u0641 \u0627\u0644\u0645\u062e\u062a\u0627\u0631 \u064a\u062a\u062d\u0643\u0645 \u0641\u064a \u0628\u0627\u0642\u064a \u062a\u0641\u0627\u0635\u064a\u0644 \u0627\u0644\u062d\u0644\u0642\u0629 \u062f\u0627\u062e\u0644 \u0627\u0644\u062a\u0637\u0628\u064a\u0642.',
              ),
              const SizedBox(height: 10),
              _field(
                _title,
                '\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u062d\u0644\u0642\u0629',
              ),
              _field(
                _roomCode,
                '\u0643\u0648\u062f \u0627\u0644\u063a\u0631\u0641\u0629',
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final searchButton = OutlinedButton.icon(
                    onPressed: _searching ? null : _searchHosts,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('\u0628\u062d\u062b'),
                  );
                  final searchField = _field(
                    _hostSearch,
                    '\u0628\u062d\u062b \u0627\u0644\u0645\u0634\u0631\u0641: \u0627\u0633\u0645/\u0647\u0627\u062a\u0641/uid/email',
                  );
                  if (constraints.maxWidth < 460) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: searchButton,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 8),
                      searchButton,
                    ],
                  );
                },
              ),
              if (_hostResults.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hostResults
                      .map((host) {
                        final selected = _host?['uid'] == host['uid'];
                        return ChoiceChip(
                          selected: selected,
                          label: Text(
                            '${host['name'] ?? host['email'] ?? host['uid']}',
                          ),
                          onSelected: (_) => setState(() => _host = host),
                        );
                      })
                      .toList(growable: false),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['scheduled', 'live', 'ended', 'archived']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: const ['limited_session', '24h_room']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _mode = value ?? _mode),
              ),
              const SizedBox(height: 10),
              _field(
                _scheduledAt,
                '\u0645\u0648\u0639\u062f \u0627\u0644\u062d\u0644\u0642\u0629',
              ),
              _field(
                _duration,
                '\u0645\u062f\u0629 \u0627\u0644\u062d\u0644\u0642\u0629 \u0628\u0627\u0644\u062f\u0642\u0627\u0626\u0642',
              ),
              _field(
                _maxReaders,
                '\u0639\u062f\u062f \u0627\u0644\u0642\u0631\u0627\u0621 \u0627\u0644\u0646\u0634\u0637\u064a\u0646 (1-20)',
              ),
              _field(
                _pricePoints,
                '\u0639\u062f\u062f \u0627\u0644\u0646\u0642\u0627\u0637 \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629',
              ),
              _field(
                _activeReaders,
                '\u0639\u062f\u062f \u0627\u0644\u0642\u0631\u0627\u0621 \u0627\u0644\u062d\u0627\u0644\u064a\u064a\u0646',
              ),
              _field(
                _listeners,
                '\u0639\u062f\u062f \u0627\u0644\u0645\u0633\u062a\u0645\u0639\u064a\u0646',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u0625\u0644\u063a\u0627\u0621'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('\u062d\u0641\u0638'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _VisualCardData {
  const _VisualCardData(this.title, this.description);

  final String title;
  final String description;

  String get subtitle => description;
}

class _PendingVisualBody extends StatelessWidget {
  const _PendingVisualBody({
    required this.headline,
    required this.description,
    required this.icon,
    required this.cards,
  });

  final String headline;
  final String description;
  final IconData icon;
  final List<_VisualCardData> cards;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Icon(icon, color: const Color(0xFF1479FF), size: 34),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  headline,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: cards
                .map((card) => _PreviewTile(data: card))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StoreItemVisualCard extends StatelessWidget {
  const _StoreItemVisualCard({required this.item});

  final AdminStoreItem item;

  @override
  Widget build(BuildContext context) {
    final hasPreview = item.previewUrl.trim().isNotEmpty;
    return SizedBox(
      width: 220,
      height: 220,
      child: AdminDashboardSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: hasPreview
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.previewUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.image_outlined,
                              color: Color(0xFF1479FF),
                              size: 42,
                            ),
                      ),
                    )
                  : const Icon(
                      Icons.widgets_outlined,
                      color: Color(0xFF1479FF),
                      size: 48,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              item.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              item.assetSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${item.pricePoints} points - ${item.requiredPlan}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF1479FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.data});

  final _VisualCardData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AdminDashboardSurfaceCard(
        minHeight: 142,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: Color(0xFF1479FF),
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(data.subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard(this.title, this.message);

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        active ? '\u0646\u0634\u0637' : '\u0645\u062a\u0648\u0642\u0641',
      ),
      backgroundColor: active
          ? const Color(0xFFE4F7EE)
          : const Color(0xFFFFEFEF),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.colors});

  final Map<String, dynamic> colors;

  @override
  Widget build(BuildContext context) {
    final values = colors.values
        .map((value) => _colorFromHex('$value'))
        .whereType<Color>()
        .toList(growable: false);
    return Row(
      children: values
          .take(5)
          .map((color) {
            return Container(
              width: 22,
              height: 22,
              margin: const EdgeInsetsDirectional.only(end: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            );
          })
          .toList(growable: false),
    );
  }
}

String _localizedTitle(Map<String, dynamic> data) {
  return ContentLocaleFallback.resolve(
    localeCode: 'en',
    ar: data['titleAr'] is String ? data['titleAr'] as String : '',
    en: data['titleEn'] is String ? data['titleEn'] as String : '',
    fr: data['titleFr'] is String ? data['titleFr'] as String : '',
    fallback: 'Asset',
  );
}

Color? _colorFromHex(String value) {
  final clean = value.replaceAll('#', '').trim();
  final parsed = int.tryParse(
    clean.length == 6 ? 'FF$clean' : clean,
    radix: 16,
  );
  return parsed == null ? null : Color(parsed);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
