import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/operational_config.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../admin/data/app_config_repository.dart';
import '../../subscriptions/data/plan_repository.dart';
import '../../subscriptions/data/user_profile_repository.dart';
import '../data/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.authService,
    required this.userProfileRepository,
    required this.appConfigRepository,
    required this.planRepository,
    required this.firebaseConfigured,
    this.initialMessage,
  });

  final AuthService authService;
  final UserProfileRepository userProfileRepository;
  final AppConfigRepository appConfigRepository;
  final PlanRepository planRepository;
  final bool firebaseConfigured;
  final String? initialMessage;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _bootstrapSecretController = TextEditingController();

  bool _isSubmitting = false;
  bool _isBootstrapping = false;
  bool _otpRequested = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeExistingAdminSession();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _bootstrapSecretController.dispose();
    super.dispose();
  }

  Future<void> _finalizeAdminAccess() async {
    final session = widget.authService.currentSession;
    if (session == null) {
      throw FirebaseAuthException(
        code: 'missing-session',
        message: 'لم يتم إنشاء جلسة دخول صالحة.',
      );
    }

    final config = await widget.appConfigRepository.loadOperationalConfig();
    await widget.userProfileRepository.ensureUserProfile(
      uid: session.uid,
      email: session.email,
      defaultPlanId: config.defaultUserPlanId,
    );

    final profile = await widget.userProfileRepository.loadUserSessionProfile(
      uid: session.uid,
      defaultPlanId: config.defaultUserPlanId,
      fallbackEmail: session.email,
    );

    final hasAdminAccess =
        profile != null &&
        (profile.role == 'admin' ||
            profile.role == 'superAdmin' ||
            profile.role == 'super_admin' ||
            profile.permissions.contains('dashboard.view'));

    if (!hasAdminAccess) {
      await widget.authService.signOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'هذا الحساب لا يملك صلاحية دخول لوحة الإدارة.',
      );
    }

    if (DateTime.now().microsecondsSinceEpoch == -1) {
      await widget.authService.signOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message:
            'تم تسجيل الدخول، لكن هذا الحساب لا يملك role أو permissions إدارية كافية داخل users/{uid}.',
      );
    }

    unawaited(_runNonBlockingAdminMaintenance());

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacementNamed(AppRouter.adminDashboardHomeRoute);
  }

  Future<void> _runNonBlockingAdminMaintenance() async {
    if (kDebugMode) {
      return;
    }
    try {
      await widget.appConfigRepository.ensureDefaults();
      await widget.planRepository.ensureDefaults();
    } catch (error) {
      debugPrint('[AdminLogin] non-blocking maintenance skipped: $error');
    }
  }

  Future<void> _resumeExistingAdminSession() async {
    if (!mounted || widget.authService.currentSession == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _finalizeAdminAccess();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _error = mapAppErrorToArabic(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = mapAppErrorToArabic(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await action();
      await _finalizeAdminAccess();
    } on FirebaseAuthException catch (error) {
      setState(() {
        _error = mapAppErrorToArabic(error);
      });
    } catch (error) {
      setState(() {
        _error = mapAppErrorToArabic(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _runAction(() {
      return widget.authService.signInAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    });
  }

  Future<void> _submitGoogle() async {
    await _runAction(widget.authService.signInWithGoogle);
  }

  Future<void> _startPhoneFlow() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _error = 'أدخل رقم الهاتف أولًا.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.authService.startPhoneSignIn(phone);
      if (widget.authService.currentSession != null) {
        await _finalizeAdminAccess();
        return;
      }
      if (mounted) {
        setState(() {
          _otpRequested = true;
        });
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        _error = mapAppErrorToArabic(error);
      });
    } catch (error) {
      setState(() {
        _error = mapAppErrorToArabic(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmPhoneCode() async {
    final code = _smsCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = 'أدخل رمز التحقق.';
      });
      return;
    }

    await _runAction(() => widget.authService.confirmPhoneCode(code));
  }

  Future<void> _bootstrapFirstAdmin() async {
    final session = widget.authService.currentSession;
    final secret = _bootstrapSecretController.text.trim();
    if (session == null) {
      setState(() {
        _error = 'سجّل الدخول أولاً ثم أدخل سر bootstrap.';
      });
      return;
    }
    if (secret.isEmpty) {
      setState(() {
        _error = 'أدخل سر bootstrap أولاً.';
      });
      return;
    }

    setState(() {
      _isBootstrapping = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'bootstrapFirstAdmin',
      );
      final response = await callable.call<Map<String, dynamic>>({
        'secret': secret,
      });
      _bootstrapSecretController.clear();
      if (!mounted) {
        return;
      }
      final data = response.data;
      final ok = data['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            ok
                ? 'تم إنشاء أول مشرف: ${data['email'] ?? data['uid']}'
                : 'لم تكتمل عملية bootstrap.',
          ),
        ),
      );
      if (ok) {
        await _finalizeAdminAccess();
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? error.code);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = mapAppErrorToArabic(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.42),
              scheme.surface,
              scheme.secondaryContainer.withValues(alpha: 0.30),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StreamBuilder<OperationalConfig>(
                      stream: widget.appConfigRepository
                          .watchOperationalConfig(),
                      builder: (context, snapshot) {
                        final configError = snapshot.hasError
                            ? mapAppErrorToArabic(snapshot.error!)
                            : null;
                        final config =
                            snapshot.data ?? OperationalConfig.defaults();

                        return ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'لوحة إدارة صلاتي',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'تسجيل دخول لحسابات الإدارة فقط.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (configError != null) ...[
                              _AdminLoginMessageBanner(message: configError),
                              const SizedBox(height: 20),
                            ],
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'يتم فتح اللوحة للحسابات التي تملك صلاحية إدارية داخل Firestore.',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (kDebugMode) ...[
                              _DebugBootstrapAdminCard(
                                controller: _bootstrapSecretController,
                                isSubmitting: _isBootstrapping,
                                signedIn:
                                    widget.authService.currentSession != null,
                                onSubmit: _bootstrapFirstAdmin,
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (config.authAvailability.emailPasswordEnabled)
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'البريد وكلمة المرور',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'البريد الإلكتروني',
                                        prefixIcon: Icon(Icons.alternate_email),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'أدخل البريد الإلكتروني';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'كلمة المرور',
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'أدخل كلمة المرور';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _submitEmail,
                                        icon: _isSubmitting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.login_rounded),
                                        label: const Text(
                                          'تسجيل الدخول بالبريد',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            if (config.authAvailability.googleEnabled)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitGoogle,
                                      icon: const Icon(Icons.login),
                                      label: const Text(
                                        'تسجيل الدخول عبر Google',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            if (config.authAvailability.phoneEnabled)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الهاتف',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'رقم الهاتف',
                                      hintText: '+201000000000',
                                      prefixIcon: Icon(
                                        Icons.phone_iphone_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_otpRequested)
                                    TextField(
                                      controller: _smsCodeController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'رمز التحقق',
                                        prefixIcon: Icon(
                                          Icons.password_rounded,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isSubmitting
                                              ? null
                                              : _startPhoneFlow,
                                          child: const Text('إرسال الرمز'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed:
                                              !_otpRequested || _isSubmitting
                                              ? null
                                              : _confirmPhoneCode,
                                          child: const Text('تأكيد الرمز'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminLoginMessageBanner extends StatelessWidget {
  const _AdminLoginMessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugBootstrapAdminCard extends StatelessWidget {
  const _DebugBootstrapAdminCard({
    required this.controller,
    required this.isSubmitting,
    required this.signedIn,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final bool signedIn;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Debug first-admin bootstrap',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              signedIn
                  ? 'Signed in. Enter the temporary bootstrap secret.'
                  : 'Sign in first, then enter the temporary bootstrap secret.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'BOOTSTRAP_ADMIN_SECRET',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_rounded),
                label: const Text('Bootstrap first admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
