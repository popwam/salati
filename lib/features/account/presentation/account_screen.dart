import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/feature_entitlement.dart';
import '../../../core/models/plan.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/info_card.dart';
import '../../../shared/widgets/loading_state_view.dart';
import '../../auth/models/auth_session.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.services,
    required this.preferences,
  });

  final AppServices services;
  final AppPreferences preferences;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isBusy = false;
  bool _otpRequested = false;
  String? _error;
  String? _syncStatusUid;
  DateTime? _lastBackupAt;
  bool _syncStatusLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await action();
    } on FirebaseException catch (error) {
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
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _ensureProfileForCurrentSession() async {
    final session = widget.services.authService.currentSession;
    if (session == null) {
      throw FirebaseException(
        plugin: 'salati',
        code: 'missing-session',
        message: 'تعذر العثور على جلسة مستخدم صالحة.',
      );
    }

    final config = await widget.services.appConfigRepository
        .loadOperationalConfig();
    await widget.services.userProfileRepository.ensureUserProfile(
      uid: session.uid,
      email: session.email,
      defaultPlanId: config.defaultUserPlanId,
    );
  }

  Future<void> _restoreFreeSession() async {
    final config = await widget.services.appConfigRepository
        .loadOperationalConfig();
    await widget.services.authService.ensureMobileUserSession(
      allowAnonymous: config.authAvailability.anonymousEnabled,
    );
    await _ensureProfileForCurrentSession();
  }

  Future<bool> _confirmAccountLink(String providerName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تجهيز الحساب عبر $providerName'),
          content: const Text(
            'لو وسيلة الدخول مرتبطة بحساب صلاتي موجود، سيتم استخدام الحساب الموجود بدل الحساب المجاني المؤقت. بيانات الجهاز الحالية تبقى محلية لحين اكتمال مزامنة الدمج التجارية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('متابعة'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _openAccountLinkSheet(AuthSession? session) async {
    var otpRequested = _otpRequested;
    var isSheetBusy = false;
    String? sheetError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> runSheetAction(Future<void> Function() action) async {
              setSheetState(() {
                isSheetBusy = true;
                sheetError = null;
              });
              if (mounted) {
                setState(() {
                  _isBusy = true;
                  _error = null;
                });
              }
              try {
                await action();
              } on FirebaseException catch (error) {
                setSheetState(() => sheetError = mapAppErrorToArabic(error));
              } catch (error) {
                setSheetState(() => sheetError = mapAppErrorToArabic(error));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSheetBusy = false);
                }
                if (mounted) {
                  setState(() => _isBusy = false);
                }
              }
            }

            Future<void> linkGoogle() async {
              final confirmed = await _confirmAccountLink('Google');
              if (!confirmed) {
                return;
              }
              await runSheetAction(() async {
                await widget.services.authService.linkWithGoogle();
                await _ensureProfileForCurrentSession();
                if (!sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext).pop();
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم ربط الحساب عبر Google بنجاح'),
                  ),
                );
              });
            }

            Future<void> sendPhoneCode() async {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty) {
                setSheetState(() => sheetError = 'اكتب رقم الهاتف أولًا');
                return;
              }
              final confirmed = await _confirmAccountLink('الهاتف');
              if (!confirmed) {
                return;
              }
              await runSheetAction(() async {
                await widget.services.authService.startPhoneSignIn(
                  phone,
                  linkIfAnonymous: true,
                );
                final currentSession =
                    widget.services.authService.currentSession;
                if (currentSession != null && !currentSession.isAnonymous) {
                  await _ensureProfileForCurrentSession();
                  if (mounted) {
                    setState(() {
                      _otpRequested = false;
                      _error = null;
                    });
                  }
                  if (!sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم ربط الحساب بالهاتف بنجاح'),
                    ),
                  );
                  return;
                }
                if (!sheetContext.mounted) {
                  return;
                }
                setSheetState(() => otpRequested = true);
                if (mounted) {
                  setState(() => _otpRequested = true);
                }
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('أرسلنا رمز التحقق إلى هاتفك')),
                );
              });
            }

            Future<void> confirmPhoneCode() async {
              final code = _smsCodeController.text.trim();
              if (code.isEmpty) {
                setSheetState(() => sheetError = 'اكتب رمز التحقق');
                return;
              }
              await runSheetAction(() async {
                await widget.services.authService.confirmPhoneCode(
                  code,
                  linkIfAnonymous: true,
                );
                await _ensureProfileForCurrentSession();
                if (mounted) {
                  setState(() {
                    _otpRequested = false;
                    _error = null;
                  });
                }
                if (!sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext).pop();
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم ربط الحساب بالهاتف بنجاح')),
                );
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ربط الحساب',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session?.isAnonymous == false
                        ? 'حسابك مرتبط بالفعل ويمكن استخدامه على جهاز آخر.'
                        : 'اختر وسيلة دخول واحدة. لو الحساب موجود قبل كده سنستخدمه بدل الحساب المؤقت.',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isSheetBusy ? null : linkGoogle,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('المتابعة عبر Google'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '+201000000000',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (otpRequested) ...[
                    TextField(
                      controller: _smsCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رمز التحقق',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSheetBusy ? null : sendPhoneCode,
                          child: const Text('إرسال الرمز'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: !otpRequested || isSheetBusy
                              ? null
                              : confirmPhoneCode,
                          child: const Text('تأكيد الربط'),
                        ),
                      ),
                    ],
                  ),
                  if (isSheetBusy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                  if (sheetError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      sheetError!,
                      style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editProfile(AuthSession? session, AppUser? user) async {
    if (session == null) {
      setState(() {
        _error = 'لم يتم تجهيز جلسة مستخدم بعد.';
      });
      return;
    }

    final nameController = TextEditingController(
      text: user?.name.isNotEmpty == true ? user!.name : '',
    );
    String? avatarData = user?.avatarUrl ?? user?.photoUrl;
    Uint8List? selectedAvatarBytes;
    var clearAvatar = false;

    final result = await showModalBottomSheet<_ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickAvatar() async {
              final image = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 70,
              );
              if (image == null) {
                return;
              }
              final bytes = await image.readAsBytes();
              setSheetState(() {
                selectedAvatarBytes = bytes;
                avatarData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                clearAvatar = false;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تعديل البيانات',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _ProfileAvatar(
                      avatarUrl: clearAvatar ? null : avatarData,
                      fallbackName: nameController.text,
                      radius: 44,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: pickAvatar,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('اختيار صورة'),
                      ),
                      if ((avatarData?.isNotEmpty ?? false) && !clearAvatar)
                        TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              clearAvatar = true;
                              avatarData = null;
                              selectedAvatarBytes = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف الصورة'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      hintText: 'اكتب اسمك',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _ProfileEditResult(
                          name: nameController.text.trim(),
                          avatarUrl: avatarData,
                          avatarBytes: selectedAvatarBytes,
                          clearAvatar: clearAvatar,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('حفظ البيانات'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    if (result == null) {
      return;
    }
    if (result.name.isEmpty) {
      setState(() {
        _error = 'اكتب الاسم أولًا';
      });
      return;
    }

    await _runAction(() async {
      var avatarUrl = result.avatarUrl;
      if (result.clearAvatar) {
        await widget.services.userMediaRepository.deleteProfileAvatar(
          uid: session.uid,
        );
      } else if (result.avatarBytes != null) {
        try {
          avatarUrl = await widget.services.userMediaRepository
              .uploadProfileAvatar(
                uid: session.uid,
                bytes: result.avatarBytes!,
              );
          await widget.services.analyticsService.trackEvent(
            'profile_avatar_uploaded',
          );
        } catch (error, stackTrace) {
          await widget.services.crashReportingService.recordError(
            error,
            stackTrace,
          );
        }
      }

      await widget.services.userProfileRepository.updateOwnProfile(
        uid: session.uid,
        name: result.name,
        avatarUrl: avatarUrl,
        clearAvatar: result.clearAvatar,
      );
      await widget.services.analyticsService.trackEvent('profile_updated');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث بياناتك')));
    });
  }

  Future<void> _uploadSync(AuthSession? session) async {
    if (session == null || session.isAnonymous) {
      setState(() {
        _error = 'اربط حسابك أولاً قبل المزامنة السحابية.';
      });
      return;
    }

    await _runAction(() async {
      await widget.services.userDataSyncService.uploadLocalSnapshot(
        uid: session.uid,
        preferences: widget.preferences,
      );
      final backupAt = DateTime.now();
      await widget.preferences.setLastCloudBackupAt(backupAt);
      setState(() => _lastBackupAt = backupAt);
      await widget.services.analyticsService.trackEvent('data_sync_upload');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع نسخة مزامنة جديدة.')),
      );
    });
  }

  Future<void> _ensureSyncStatusLoaded(AuthSession? session) async {
    if (session == null || session.isAnonymous) {
      if (_syncStatusUid != null || _lastBackupAt != null) {
        setState(() {
          _syncStatusUid = null;
          _lastBackupAt = null;
          _syncStatusLoading = false;
        });
      }
      return;
    }

    if (_syncStatusUid == session.uid || _syncStatusLoading) {
      return;
    }

    setState(() {
      _syncStatusUid = session.uid;
      _syncStatusLoading = true;
      _lastBackupAt = widget.preferences.lastCloudBackupAt;
    });

    try {
      final remoteUpdatedAt = await widget.services.userDataSyncService
          .remoteUpdatedAt(session.uid);
      if (!widget.preferences.firstCloudRestoreAttempted) {
        await widget.preferences.setFirstCloudRestoreAttempted(true);
        if (remoteUpdatedAt != null) {
          await widget.services.userDataSyncService.restoreRemoteSnapshot(
            uid: session.uid,
            preferences: widget.preferences,
          );
          await widget.services.analyticsService.trackEvent(
            'data_sync_auto_restore',
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _lastBackupAt = remoteUpdatedAt ?? widget.preferences.lastCloudBackupAt;
        _syncStatusLoading = false;
      });
    } catch (error, stackTrace) {
      await widget.services.crashReportingService.recordError(
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() => _syncStatusLoading = false);
    }
  }

  Future<void> _logout() async {
    await _runAction(() async {
      await widget.services.authService.signOut();
      await _restoreFreeSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _otpRequested = false;
        _phoneController.clear();
        _smsCodeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الخروج والعودة إلى الحساب المجاني'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: widget.services.authService.authStateChanges(),
      builder: (context, authSnapshot) {
        final session = authSnapshot.data;
        if (authSnapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const LoadingStateView(label: 'جارٍ تحميل حالة الحساب');
        }

        if (authSnapshot.hasError) {
          return ErrorStateView(
            title: 'تعذر تحميل الحساب',
            message: mapAppErrorToArabic(authSnapshot.error!),
          );
        }

        final userStream = session == null
            ? Stream<AppUser?>.value(null)
            : widget.services.userProfileRepository.watchCurrentUser(
                session.uid,
              );

        return StreamBuilder<AppUser?>(
          stream: userStream,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                session != null) {
              return const LoadingStateView(label: 'جارٍ تجهيز بيانات الحساب');
            }

            final user = userSnapshot.data;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                unawaited(_ensureSyncStatusLoaded(session));
              }
            });
            return StreamBuilder<List<Plan>>(
              stream: widget.services.planRepository.watchPlans(),
              builder: (context, plansSnapshot) {
                final plans = plansSnapshot.data ?? const <Plan>[];
                final currentPlan = _planFor(user?.effectivePlanId, plans);

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _AccountHeroCard(
                      session: session,
                      user: user,
                      planName:
                          currentPlan?.name ?? user?.effectivePlanId ?? 'free',
                      score: widget.preferences.prayerScoreSummary.totalScore,
                      onEdit: _isBusy
                          ? null
                          : () => _editProfile(session, user),
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle(title: 'الملف الشخصي'),
                    const SizedBox(height: 8),
                    InfoCard(
                      title: 'حالة الدخول',
                      body: _loginStateLabel(session),
                      trailing: Icon(
                        session == null
                            ? Icons.person_off_outlined
                            : session.isAnonymous
                            ? Icons.lock_open_rounded
                            : Icons.verified_user_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoCard(
                      title: 'الاسم',
                      body: user?.name.isNotEmpty == true
                          ? user!.name
                          : 'مستخدم مجاني',
                      trailing: IconButton(
                        onPressed: _isBusy
                            ? null
                            : () => _editProfile(session, user),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'تعديل البيانات',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoCard(
                      title: 'الباقة الحالية',
                      body:
                          currentPlan?.name ?? user?.effectivePlanId ?? 'free',
                    ),
                    const SizedBox(height: 12),
                    _DataSyncCard(
                      session: session,
                      isBusy: _isBusy,
                      lastBackupAt: _lastBackupAt,
                      isStatusLoading: _syncStatusLoading,
                      onUpload: () => _uploadSync(session),
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle(title: 'المظهر والقرآن'),
                    const SizedBox(height: 8),
                    _AppearanceSettingsSection(
                      preferences: widget.preferences,
                      services: widget.services,
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle(title: 'ربط الحساب'),
                    const SizedBox(height: 8),
                    if (session == null || session.isAnonymous) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => _openAccountLinkSheet(session),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('ربط الحساب أو تسجيل الدخول'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const InfoCard(
                        title: 'مهم',
                        body:
                            'لو فتحت التطبيق على هاتف جديد، ادخل بنفس Google أو رقم الهاتف ليستعيد حسابك بدل الحساب المجاني المؤقت.',
                      ),
                    ] else ...[
                      InfoCard(
                        title: 'الحساب مرتبط',
                        body: session.email?.isNotEmpty == true
                            ? 'تم ربط الحساب بالبريد: ${session.email}'
                            : 'تم ربط الحساب بوسيلة دخول موثقة ويمكنك استخدامه للاستعادة لاحقاً.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _SectionTitle(title: 'الدعم والقانونيات'),
                    const SizedBox(height: 8),
                    _LegalAndSupportLinks(isBusy: _isBusy),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Plan? _planFor(String? planId, List<Plan> plans) {
    if (planId == null) {
      return null;
    }
    for (final plan in plans) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  String _loginStateLabel(AuthSession? session) {
    if (session == null) {
      return 'لم يتم تجهيز جلسة مستخدم بعد.';
    }
    if (session.isAnonymous) {
      return 'أنت تستخدم الآن حساباً مجانياً مؤقتاً بدون تسجيل يدوي.';
    }
    if (session.email?.isNotEmpty == true) {
      return 'تم ربط الحساب بحساب Google أو بريد إلكتروني صالح.';
    }
    return 'تم ربط الحساب برقم هاتف موثق.';
  }
}

class _AccountHeroCard extends StatelessWidget {
  const _AccountHeroCard({
    required this.session,
    required this.user,
    required this.planName,
    required this.score,
    required this.onEdit,
  });

  final AuthSession? session;
  final AppUser? user;
  final String planName;
  final double score;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLinked = session != null && !session!.isAnonymous;
    final name = user?.name.isNotEmpty == true ? user!.name : 'مستخدم صلاتي';
    final color = isLinked ? Colors.green : theme.colorScheme.primary;
    final scoreText = score
        .toStringAsFixed(1)
        .replaceFirst(RegExp(r'\.0$'), '');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.95),
            theme.colorScheme.secondary.withValues(alpha: 0.86),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatar(
                avatarUrl: user?.avatarUrl ?? user?.photoUrl,
                fallbackName: name,
                radius: 27,
                borderColor: Colors.white.withValues(alpha: 0.28),
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLinked
                          ? 'حساب مرتبط وجاهز للمزامنة'
                          : 'حساب مجاني مؤقت',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'تعديل البيانات',
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetricPill(
                  icon: Icons.workspace_premium_outlined,
                  label: 'الباقة',
                  value: planName,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetricPill(
                  icon: Icons.insights_rounded,
                  label: 'النقاط',
                  value: scoreText,
                  accent: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricPill extends StatelessWidget {
  const _HeroMetricPill({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditResult {
  const _ProfileEditResult({
    required this.name,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.clearAvatar,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final bool clearAvatar;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.fallbackName,
    required this.radius,
    this.borderColor,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? avatarUrl;
  final String fallbackName;
  final double radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeDataImage(avatarUrl);
    final imageUrl = _networkImageUrl(avatarUrl);
    final initial = fallbackName.trim().isEmpty
        ? 'ص'
        : fallbackName.trim().characters.first;
    final theme = Theme.of(context);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            backgroundColor ??
            theme.colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(
          color:
              borderColor ??
              theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageBytes != null
          ? Image.memory(imageBytes, fit: BoxFit.cover)
          : imageUrl != null
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _AvatarInitial(
                  initial,
                  color: foregroundColor ?? theme.colorScheme.primary,
                  fontSize: radius * 0.78,
                );
              },
            )
          : Center(
              child: _AvatarInitial(
                initial,
                color: foregroundColor ?? theme.colorScheme.primary,
                fontSize: radius * 0.78,
              ),
            ),
    );
  }

  String? _networkImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    return null;
  }

  Uint8List? _decodeDataImage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim();
    final marker = 'base64,';
    final markerIndex = normalized.indexOf(marker);
    if (!normalized.startsWith('data:image/') || markerIndex == -1) {
      return null;
    }
    try {
      return base64Decode(normalized.substring(markerIndex + marker.length));
    } catch (_) {
      return null;
    }
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial(
    this.initial, {
    required this.color,
    required this.fontSize,
  });

  final String initial;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LegalAndSupportLinks extends StatelessWidget {
  const _LegalAndSupportLinks({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _AccountActionTile(
              icon: Icons.privacy_tip_outlined,
              title: 'سياسة الخصوصية',
              subtitle: 'ما البيانات التي يستخدمها صلاتي ولماذا.',
              onTap: isBusy
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushNamed(AppRouter.privacyPolicyRoute),
            ),
            const Divider(height: 1),
            _AccountActionTile(
              icon: Icons.description_outlined,
              title: 'شروط الاستخدام',
              subtitle: 'قواعد الحساب، الاشتراكات، والمحتوى داخل التطبيق.',
              onTap: isBusy
                  ? null
                  : () => Navigator.of(context).pushNamed(AppRouter.termsRoute),
            ),
            const Divider(height: 1),
            _AccountActionTile(
              icon: Icons.family_restroom_outlined,
              title: 'رقابة الأطفال',
              subtitle: 'إرشادات ولي الأمر وسلامة الأسرة.',
              onTap: isBusy
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushNamed(AppRouter.childSafetyRoute),
            ),
            const Divider(height: 1),
            _AccountActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'حذف الحساب',
              subtitle: 'طريقة طلب حذف الحساب والبيانات المرتبطة به.',
              onTap: isBusy
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushNamed(AppRouter.accountDeletionRoute),
            ),
            const Divider(height: 1),
            _AccountActionTile(
              icon: Icons.support_agent_rounded,
              title: 'الدعم والملاحظات',
              subtitle: 'أرسل مشكلة أو اقتراح.',
              onTap: isBusy
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushNamed(AppRouter.feedbackRoute),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DataSyncCard extends StatelessWidget {
  const _DataSyncCard({
    required this.session,
    required this.isBusy,
    required this.lastBackupAt,
    required this.isStatusLoading,
    required this.onUpload,
  });

  final AuthSession? session;
  final bool isBusy;
  final DateTime? lastBackupAt;
  final bool isStatusLoading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final linked = session != null && !session!.isAnonymous;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('المزامنة والنسخ الاحتياطي'),
              subtitle: Text(
                linked
                    ? 'ارفع أو استعد إعدادات الصلاة، الأذكار، تقدم القرآن، والنقاط.'
                    : 'اربط الحساب أولاً لتفعيل المزامنة السحابية.',
              ),
            ),
            if (linked) ...[
              const SizedBox(height: 4),
              Text(
                _backupStatusLabel(),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: linked && !isBusy ? onUpload : null,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('رفع نسخة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _backupStatusLabel() {
    if (isStatusLoading) {
      return 'Checking backup status...';
    }
    if (lastBackupAt == null) {
      return 'Backup is not configured yet.';
    }
    return 'Last backup: ${_formatDateTime(lastBackupAt!)}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _AppearanceSettingsSection extends StatelessWidget {
  const _AppearanceSettingsSection({
    required this.preferences,
    required this.services,
  });

  final AppPreferences preferences;
  final AppServices services;

  static const _themeOptions = [
    _SettingsOption(key: 'emerald', label: 'زمردي هادئ'),
    _SettingsOption(key: 'indigo', label: 'نيلي مركز'),
    _SettingsOption(key: 'sunrise', label: 'شروق دافئ'),
    _SettingsOption(key: 'rose', label: 'وردي ناعم'),
    _SettingsOption(key: 'graphite', label: 'جرافيت عملي'),
  ];

  static const _appFontOptions = [
    _SettingsOption(key: 'cairo', label: 'Cairo'),
    _SettingsOption(key: 'tajawal', label: 'Tajawal'),
    _SettingsOption(key: 'noto', label: 'Noto Sans Arabic'),
    _SettingsOption(key: 'ibm', label: 'IBM Plex Arabic'),
  ];

  static const _quranFontOptions = [
    _SettingsOption(key: 'cairo', label: 'Cairo 300'),
    _SettingsOption(key: 'amiri', label: 'Amiri'),
    _SettingsOption(key: 'naskh', label: 'Noto Naskh Arabic'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = services.authService.currentSession;
    final entitlementStream = session == null
        ? Stream<List<FeatureEntitlement>>.value(const [])
        : services.entitlementRepository.watchUserEntitlements(session.uid);

    return StreamBuilder<List<FeatureEntitlement>>(
      stream: entitlementStream,
      builder: (context, entitlementSnapshot) {
        final entitlements = entitlementSnapshot.data ?? const [];
        return AnimatedBuilder(
          animation: preferences,
          builder: (context, _) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إعدادات المظهر والقرآن',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ThemeMode>(
                      initialValue: preferences.themeMode,
                      decoration: const InputDecoration(
                        labelText: 'وضع الألوان',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('فاتح'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('داكن'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('حسب النظام'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          preferences.setThemeMode(value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _SettingsDropdown(
                      label: 'شكل الثيمة',
                      value: _resolvedValue(
                        preferences.themeStyleKey,
                        _themeOptions,
                        entitlements,
                        'theme',
                      ),
                      options: _themeOptions,
                      entitlements: entitlements,
                      featureType: 'theme',
                      onChanged: preferences.setThemeStyleKey,
                    ),
                    const SizedBox(height: 12),
                    _SettingsDropdown(
                      label: 'خط التطبيق',
                      value: _resolvedValue(
                        preferences.appFontKey,
                        _appFontOptions,
                        entitlements,
                        'font',
                      ),
                      options: _appFontOptions,
                      entitlements: entitlements,
                      featureType: 'font',
                      onChanged: preferences.setAppFontKey,
                    ),
                    const SizedBox(height: 12),
                    _SettingsDropdown(
                      label: 'خط القرآن',
                      value: _resolvedValue(
                        preferences.quranFontKey,
                        _quranFontOptions,
                        entitlements,
                        'quran_font',
                      ),
                      options: _quranFontOptions,
                      entitlements: entitlements,
                      featureType: 'quran_font',
                      onChanged: preferences.setQuranFontKey,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.storeRoute);
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('فتح المتجر'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _resolvedValue(
    String value,
    List<_SettingsOption> options,
    List<FeatureEntitlement> entitlements,
    String featureType,
  ) {
    final optionExists = options.any((option) => option.key == value);
    if (!optionExists) {
      return options.first.key;
    }
    if (_isUnlocked(value, entitlements, featureType)) {
      return value;
    }
    return options.first.key;
  }

  static bool _isUnlocked(
    String key,
    List<FeatureEntitlement> entitlements,
    String featureType,
  ) {
    if (key == 'emerald' || key == 'cairo') {
      return true;
    }
    final featureKey = '$featureType:$key';
    return entitlements.any(
      (entitlement) =>
          entitlement.isActive && entitlement.featureKey == featureKey,
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.entitlements,
    required this.featureType,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_SettingsOption> options;
  final List<FeatureEntitlement> entitlements;
  final String featureType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.map((option) {
        final unlocked = _AppearanceSettingsSection._isUnlocked(
          option.key,
          entitlements,
          featureType,
        );
        final price = _priceFor(featureType, option.key);
        return DropdownMenuItem<String>(
          value: option.key,
          enabled: unlocked,
          child: Row(
            children: [
              Expanded(child: Text(option.label)),
              if (!unlocked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock_outline, size: 16),
                const SizedBox(width: 4),
                Text('$price نقطة'),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }

  static int _priceFor(String type, String key) {
    if (key == 'emerald' || key == 'cairo') {
      return 0;
    }
    if (type == 'theme' && (key == 'indigo' || key == 'sunrise')) {
      return 15;
    }
    if (type == 'font' && key == 'tajawal') {
      return 15;
    }
    return 30;
  }
}

class _SettingsOption {
  const _SettingsOption({required this.key, required this.label});

  final String key;
  final String label;
}
