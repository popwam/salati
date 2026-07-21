import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../auth/models/auth_session.dart';
import 'subscription_state.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({required AppServices services})
    : _services = services {
    _state = SubscriptionState(firebaseConfigured: services.firebaseConfigured);
    _listen();
  }

  final AppServices _services;
  late SubscriptionState _state;

  StreamSubscription<AuthSession?>? _authSub;
  StreamSubscription? _plansSub;
  StreamSubscription? _configSub;
  StreamSubscription? _userSub;
  StreamSubscription? _entitlementsSub;

  SubscriptionState get state => _state;

  void _listen() {
    if (!_services.firebaseConfigured) {
      _state = _state.copyWith(
        isLoading: false,
        error:
            'Firebase غير مهيأ بعد. أضف ملفات FlutterFire أولاً لتفعيل بيانات الاشتراك الحقيقية.',
      );
      notifyListeners();
      return;
    }

    _plansSub = _services.planRepository
        .watchPlans(includeInactive: true)
        .listen(
          (plans) {
            _state = _state.copyWith(
              plans: plans,
              isLoading: false,
              error: null,
            );
            notifyListeners();
          },
          onError: (Object error) {
            _state = _state.copyWith(
              isLoading: false,
              error: mapAppErrorToArabic(error),
            );
            notifyListeners();
          },
        );

    _configSub = _services.appConfigRepository.watchOperationalConfig().listen(
      (config) {
        _state = _state.copyWith(pointsRules: config.pointsRules);
        notifyListeners();
      },
      onError: (Object error) {
        _state = _state.copyWith(
          isLoading: false,
          error: mapAppErrorToArabic(error),
        );
        notifyListeners();
      },
    );

    _authSub = _services.authService.authStateChanges().listen((session) {
      _bindUserStreams(session);
    });
  }

  void _bindUserStreams(AuthSession? session) {
    _userSub?.cancel();
    _entitlementsSub?.cancel();

    if (session == null) {
      _state = _state.copyWith(
        isLoading: false,
        currentUser: null,
        entitlements: const [],
      );
      notifyListeners();
      return;
    }

    _userSub = _services.userProfileRepository
        .watchCurrentUser(session.uid)
        .listen(
          (user) {
            _state = _state.copyWith(
              currentUser: user,
              isLoading: false,
              error: null,
            );
            notifyListeners();
          },
          onError: (Object error) {
            _state = _state.copyWith(
              isLoading: false,
              error: mapAppErrorToArabic(error),
            );
            notifyListeners();
          },
        );

    _entitlementsSub = _services.entitlementRepository
        .watchUserEntitlements(session.uid)
        .listen(
          (items) {
            _state = _state.copyWith(
              entitlements: items,
              isLoading: false,
              error: null,
            );
            notifyListeners();
          },
          onError: (Object error) {
            _state = _state.copyWith(
              isLoading: false,
              error: mapAppErrorToArabic(error),
            );
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _plansSub?.cancel();
    _configSub?.cancel();
    _userSub?.cancel();
    _entitlementsSub?.cancel();
    super.dispose();
  }
}
