import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../../core/firebase/firestore_debug_logger.dart';
import '../../../core/models/operational_config.dart';
import '../../../core/models/points_config.dart';
import 'app_config_repository.dart';

class FirestoreAppConfigRepository implements AppConfigRepository {
  FirestoreAppConfigRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _settingsCollection =>
      FirebaseFirestore.instance.collection('settings');

  DocumentReference<Map<String, dynamic>> get _appConfigDoc =>
      _settingsCollection.doc('app_config');

  DocumentReference<Map<String, dynamic>> get _prayerProviderDoc =>
      _settingsCollection.doc('prayer_provider');

  DocumentReference<Map<String, dynamic>> get _contentConfigDoc =>
      _settingsCollection.doc('content_config');

  DocumentReference<Map<String, dynamic>> get _authConfigDoc =>
      _settingsCollection.doc('auth_config');

  @override
  Future<void> ensureDefaults() async {
    if (!_firebaseConfigured) {
      return;
    }

    final defaults = OperationalConfig.defaults();
    await _ensureDocument('settings/app_config', _appConfigDoc, {
      'defaultUserPlanId': defaults.defaultUserPlanId,
      'quranLimits': defaults.quranLimits.toMap(),
      'pointsRules': defaults.pointsRules.toMap(),
    });
    await _ensureDocument(
      'settings/auth_config',
      _authConfigDoc,
      defaults.authAvailability.toMap(),
    );
    await _ensureDocument(
      'settings/prayer_provider',
      _prayerProviderDoc,
      defaults.prayerProvider.toMap(),
    );
    await _ensureDocument(
      'settings/content_config',
      _contentConfigDoc,
      defaults.contentSources.toMap(),
    );
  }

  @override
  Future<OperationalConfig> loadOperationalConfig() async {
    if (!_firebaseConfigured) {
      return OperationalConfig.defaults();
    }
    final appConfig = await _readDoc('settings/app_config', _appConfigDoc);
    final authConfig = await _readDoc('settings/auth_config', _authConfigDoc);
    final prayerProvider = await _readDoc(
      'settings/prayer_provider',
      _prayerProviderDoc,
    );
    final contentConfig = await _readDoc(
      'settings/content_config',
      _contentConfigDoc,
    );

    return _composeConfig(appConfig, authConfig, prayerProvider, contentConfig);
  }

  @override
  Future<void> saveOperationalConfig(OperationalConfig config) async {
    if (!_firebaseConfigured) {
      throw StateError('Firebase غير مهيأ.');
    }

    await _writeDoc('settings/app_config', _appConfigDoc, {
      'defaultUserPlanId': config.defaultUserPlanId,
      'quranLimits': config.quranLimits.toMap(),
      'pointsRules': config.pointsRules.toMap(),
    });
    await _writeDoc(
      'settings/auth_config',
      _authConfigDoc,
      config.authAvailability.toMap(),
    );
    await _writeDoc(
      'settings/prayer_provider',
      _prayerProviderDoc,
      config.prayerProvider.toMap(),
    );
    await _writeDoc(
      'settings/content_config',
      _contentConfigDoc,
      config.contentSources.toMap(),
    );
  }

  @override
  Stream<OperationalConfig> watchOperationalConfig() {
    if (!_firebaseConfigured) {
      return Stream<OperationalConfig>.value(OperationalConfig.defaults());
    }

    late final StreamController<OperationalConfig> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? appConfigSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? authConfigSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    prayerProviderSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    contentConfigSub;

    Map<String, dynamic> appConfig = const {};
    Map<String, dynamic> authConfig = const {};
    Map<String, dynamic> prayerProvider = const {};
    Map<String, dynamic> contentConfig = const {};

    void emit() {
      controller.add(
        _composeConfig(appConfig, authConfig, prayerProvider, contentConfig),
      );
    }

    controller = StreamController<OperationalConfig>.broadcast(
      onListen: () {
        appConfigSub = _appConfigDoc.snapshots().listen(
          (snapshot) {
            FirestoreDebugLogger.success(
              path: 'settings/app_config',
              operation: 'listen',
            );
            appConfig = snapshot.data() ?? const {};
            emit();
          },
          onError: (error) {
            _logStreamError('settings/app_config', error);
            if (_shouldUseDefaultConfig(error)) {
              _logDefaultConfigFallback('settings/app_config', error);
              emit();
              controller.addError(_defaultConfigException());
              return;
            }
            controller.addError(error);
          },
        );
        FirestoreDebugLogger.attempt(
          path: 'settings/app_config',
          operation: 'listen',
        );
        authConfigSub = _authConfigDoc.snapshots().listen(
          (snapshot) {
            FirestoreDebugLogger.success(
              path: 'settings/auth_config',
              operation: 'listen',
            );
            authConfig = snapshot.data() ?? const {};
            emit();
          },
          onError: (error) {
            _logStreamError('settings/auth_config', error);
            if (_shouldUseDefaultConfig(error)) {
              _logDefaultConfigFallback('settings/auth_config', error);
              emit();
              controller.addError(_defaultConfigException());
              return;
            }
            controller.addError(error);
          },
        );
        FirestoreDebugLogger.attempt(
          path: 'settings/auth_config',
          operation: 'listen',
        );
        prayerProviderSub = _prayerProviderDoc.snapshots().listen(
          (snapshot) {
            FirestoreDebugLogger.success(
              path: 'settings/prayer_provider',
              operation: 'listen',
            );
            prayerProvider = snapshot.data() ?? const {};
            emit();
          },
          onError: (error) {
            _logStreamError('settings/prayer_provider', error);
            if (_shouldUseDefaultConfig(error)) {
              _logDefaultConfigFallback('settings/prayer_provider', error);
              emit();
              controller.addError(_defaultConfigException());
              return;
            }
            controller.addError(error);
          },
        );
        FirestoreDebugLogger.attempt(
          path: 'settings/prayer_provider',
          operation: 'listen',
        );
        contentConfigSub = _contentConfigDoc.snapshots().listen(
          (snapshot) {
            FirestoreDebugLogger.success(
              path: 'settings/content_config',
              operation: 'listen',
            );
            contentConfig = snapshot.data() ?? const {};
            emit();
          },
          onError: (error) {
            _logStreamError('settings/content_config', error);
            if (_shouldUseDefaultConfig(error)) {
              _logDefaultConfigFallback('settings/content_config', error);
              emit();
              controller.addError(_defaultConfigException());
              return;
            }
            controller.addError(error);
          },
        );
        FirestoreDebugLogger.attempt(
          path: 'settings/content_config',
          operation: 'listen',
        );
      },
      onCancel: () async {
        await appConfigSub?.cancel();
        await authConfigSub?.cancel();
        await prayerProviderSub?.cancel();
        await contentConfigSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<Map<String, dynamic>> _readDoc(
    String path,
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      final snapshot = await doc.get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
      return snapshot.data() ?? const {};
    } on FirebaseException catch (error) {
      _logWriteError(path, 'get', error);
      if (_shouldUseDefaultConfig(error)) {
        _logDefaultConfigFallback(path, error);
        return const {};
      }
      rethrow;
    }
  }

  Future<void> _ensureDocument(
    String path,
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      final snapshot = await doc.get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
      if (!snapshot.exists) {
        await _writeDoc(path, doc, data);
      }
    } on FirebaseException catch (error) {
      _logWriteError(path, 'get/set', error);
      rethrow;
    }
  }

  Future<void> _writeDoc(
    String path,
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    FirestoreDebugLogger.attempt(path: path, operation: 'set(merge)');
    try {
      await doc.set(data, SetOptions(merge: true));
      FirestoreDebugLogger.success(path: path, operation: 'set(merge)');
    } on FirebaseException catch (error) {
      _logWriteError(path, 'set(merge)', error);
      rethrow;
    }
  }

  void _logWriteError(String path, String operation, FirebaseException error) {
    if (error.code == 'permission-denied') {
      FirestoreDebugLogger.denied(
        path: path,
        operation: operation,
        error: error,
      );
    } else {
      FirestoreDebugLogger.failure(
        path: path,
        operation: operation,
        error: error,
      );
    }
  }

  void _logStreamError(String path, Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      FirestoreDebugLogger.denied(
        path: path,
        operation: 'listen',
        error: error,
      );
      return;
    }

    FirestoreDebugLogger.failure(path: path, operation: 'listen', error: error);
  }

  bool _shouldUseDefaultConfig(Object error) {
    return error is FirebaseException &&
        const {
          'permission-denied',
          'unavailable',
          'deadline-exceeded',
          'aborted',
          'failed-precondition',
        }.contains(error.code);
  }

  FirebaseException _defaultConfigException() {
    return FirebaseException(
      plugin: 'salati',
      code: 'cloud-config-defaults',
      message:
          'تعذر تحميل إعدادات السحابة مؤقتًا، سيتم استخدام الإعدادات الافتراضية.',
    );
  }

  void _logDefaultConfigFallback(String path, Object error) {
    FirestoreDebugLogger.failure(
      path: path,
      operation: 'default-config-fallback',
      error: error,
    );
  }

  OperationalConfig _composeConfig(
    Map<String, dynamic> appConfig,
    Map<String, dynamic> authConfig,
    Map<String, dynamic> prayerProvider,
    Map<String, dynamic> contentConfig,
  ) {
    return OperationalConfig(
      defaultUserPlanId: appConfig['defaultUserPlanId'] as String? ?? 'free',
      authAvailability: AuthAvailability.fromMap(authConfig),
      prayerProvider: PrayerProviderConfig.fromMap(prayerProvider),
      contentSources: ContentSourcesConfig.fromMap(contentConfig),
      quranLimits: QuranLimitsConfig.fromMap(
        appConfig['quranLimits'] as Map<String, dynamic>? ?? const {},
      ),
      pointsRules: PointsRulesConfig.fromMap(
        appConfig['pointsRules'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
