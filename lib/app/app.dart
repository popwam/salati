import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/app_preferences.dart';
import '../core/localization/salati_localizations.dart';
import '../core/utils/app_error_mapper.dart';
import '../core/utils/connectivity.dart';
import '../shared/screens/app_error_screen.dart';
import '../shared/screens/app_loading_screen.dart';
import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/app_bootstrap_result.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

class SalatiBootstrapApp extends StatefulWidget {
  const SalatiBootstrapApp({super.key});

  @override
  State<SalatiBootstrapApp> createState() => _SalatiBootstrapAppState();
}

class _SalatiBootstrapAppState extends State<SalatiBootstrapApp> {
  AppBootstrapResult? _result;
  String _message = 'جاري تجهيز التطبيق...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _errorMessage = null;
      _message = 'جاري تجهيز التطبيق...';
    });

    try {
      final result = await AppBootstrap.initialize(
        onStatusChanged: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _message = message;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Bootstrap] startup failed error=$error');
        debugPrint('[Bootstrap] startup failed stackTrace=$stackTrace');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = mapAppErrorToArabic(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return SalatiApp(
        router: _result!.router,
        preferences: _result!.preferences,
        firebaseConfigured: _result!.firebaseConfigured,
        initialRoute: _result!.initialRoute,
      );
    }

    return _BaseAppShell(
      child: _errorMessage == null
          ? AppLoadingScreen(message: _message)
          : AppErrorScreen(message: _errorMessage!, onRetry: _start),
    );
  }
}

class SalatiApp extends StatelessWidget {
  const SalatiApp({
    super.key,
    required this.router,
    required this.preferences,
    required this.firebaseConfigured,
    required this.initialRoute,
  });

  final AppRouter router;
  final AppPreferences preferences;
  final bool firebaseConfigured;
  final String initialRoute;
  static final GlobalKey<NavigatorState> _nestedNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) {
        return _BaseAppShell(
          locale: preferences.locale,
          themeMode: preferences.themeMode,
          themeStyleKey: preferences.themeStyleKey,
          appFontKey: preferences.appFontKey,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) {
                return;
              }
              final handled =
                  await _nestedNavigatorKey.currentState?.maybePop() ?? false;
              if (!handled) {
                await SystemNavigator.pop();
              }
            },
            child: Navigator(
              key: _nestedNavigatorKey,
              onGenerateRoute: router.onGenerateRoute,
              onGenerateInitialRoutes: (_, _) => [
                router.onGenerateRoute(RouteSettings(name: initialRoute)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BaseAppShell extends StatelessWidget {
  const _BaseAppShell({
    required this.child,
    this.locale = const Locale('ar'),
    this.themeMode = ThemeMode.light,
    this.themeStyleKey = 'emerald',
    this.appFontKey = 'cairo',
  });

  final Widget child;
  final Locale locale;
  final ThemeMode themeMode;
  final String themeStyleKey;
  final String appFontKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SalatiLocalizations(locale.languageCode).text('appName'),
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('fr'),
        Locale('es'),
        Locale('de'),
        Locale('id'),
        Locale('tr'),
        Locale('ur'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: AppTheme.light(styleKey: themeStyleKey, appFontKey: appFontKey),
      darkTheme: AppTheme.dark(styleKey: themeStyleKey, appFontKey: appFontKey),
      home: Directionality(
        textDirection: {'ar', 'ur'}.contains(locale.languageCode)
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: _OfflineAwareShell(child: child),
      ),
    );
  }
}

class _OfflineAwareShell extends StatefulWidget {
  const _OfflineAwareShell({required this.child});

  final Widget child;

  @override
  State<_OfflineAwareShell> createState() => _OfflineAwareShellState();
}

class _OfflineAwareShellState extends State<_OfflineAwareShell> {
  StreamSubscription<bool>? _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    ConnectivityUtils.isOffline().then((value) {
      if (mounted) {
        setState(() => _isOffline = value);
      }
    });
    _subscription = ConnectivityUtils.offlineStream.listen((value) {
      if (mounted) {
        setState(() => _isOffline = value);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'وضع عدم الاتصال: بعض البيانات ستعمل من النسخة المحفوظة.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
