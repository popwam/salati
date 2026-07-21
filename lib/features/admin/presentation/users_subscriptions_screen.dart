import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/plan.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/info_card.dart';
import '../../../shared/widgets/loading_state_view.dart';
import 'admin_guard.dart';
import 'admin_scaffold.dart';

class UsersSubscriptionsScreen extends StatefulWidget {
  const UsersSubscriptionsScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<UsersSubscriptionsScreen> createState() =>
      _UsersSubscriptionsScreenState();
}

class _UsersSubscriptionsScreenState extends State<UsersSubscriptionsScreen> {
  String? _busyUserId;

  String _userTitle(AppUser user) {
    if (user.name.trim().isNotEmpty) {
      return user.name.trim();
    }
    if (user.email?.trim().isNotEmpty == true) {
      return user.email!.trim();
    }
    return user.uid;
  }

  String _planLabelFor(String planId, List<Plan> plans) {
    for (final plan in plans) {
      if (plan.id == planId) {
        return '${plan.name} ($planId)';
      }
    }
    return planId;
  }

  String _buildUserSummary(AppUser user, List<Plan> plans) {
    return 'المعرف: ${user.uid}\n'
        'البريد: ${user.email ?? 'غير متوفر'}\n'
        'الباقة: ${_planLabelFor(user.planId, plans)}\n'
        'النقاط: ${user.points}\n'
        'محظور: ${user.isBlocked ? 'نعم' : 'لا'}\n'
        'حد AI المخصص: ${user.aiUsageLimitOverride?.toString() ?? 'افتراضي'}\n'
        'حالة الاشتراك: ${user.subscriptionStatus}\n'
        'إداري: ${user.isAdmin ? 'نعم' : 'لا'}';
  }

  int _compareUsers(AppUser left, AppUser right) {
    final leftKey = _userTitle(left).toLowerCase();
    final rightKey = _userTitle(right).toLowerCase();
    final byTitle = leftKey.compareTo(rightKey);
    if (byTitle != 0) {
      return byTitle;
    }
    return left.uid.compareTo(right.uid);
  }

  String _successMessageFor(_UserEditResult result) {
    if (result.hasPatch && result.pointsDelta != null) {
      return 'تم تحديث بيانات المستخدم والنقاط';
    }
    if (result.hasPatch) {
      return 'تم تحديث بيانات المستخدم';
    }
    return result.pointsDelta! >= 0
        ? 'تمت إضافة النقاط للمستخدم'
        : 'تم خصم النقاط من المستخدم';
  }

  Future<void> _applyUserEditResult({
    required AppUser user,
    required _UserEditResult result,
  }) async {
    if (!result.hasPatch && result.pointsDelta == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لم يتم إجراء أي تعديل')));
      return;
    }

    setState(() {
      _busyUserId = user.uid;
    });
    try {
      if (result.hasPatch) {
        await widget.services.userProfileRepository.updateUserAdminSettings(
          uid: user.uid,
          planId: result.patch.planId,
          points: result.patch.points,
          isBlocked: result.patch.isBlocked,
          aiUsageLimitOverride: result.patch.aiUsageLimitOverride,
          clearAiUsageLimitOverride: result.patch.clearAiUsageLimitOverride,
        );
      }
      if (result.pointsDelta != null) {
        await widget.services.userProfileRepository.adjustUserPoints(
          uid: user.uid,
          delta: result.pointsDelta!,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessageFor(result))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة المستخدمين والاشتراكات',
      currentRoute: AppRouter.adminUsersRoute,
      services: widget.services,
      firebaseConfigured: widget.firebaseConfigured,
      child: AdminGuard(
        services: widget.services,
        firebaseConfigured: widget.firebaseConfigured,
        child: StreamBuilder<List<Plan>>(
          stream: widget.services.planRepository.watchPlans(
            includeInactive: true,
          ),
          builder: (context, plansSnapshot) {
            if (!widget.firebaseConfigured) {
              return const ErrorStateView(
                title: 'Firebase غير مهيأ',
                message:
                    'لا يمكن قراءة المستخدمين من Firestore قبل إضافة ملفات FlutterFire المطلوبة.',
              );
            }

            if (plansSnapshot.hasError) {
              return ErrorStateView(
                title: 'تعذر تحميل الخطط',
                message: mapAppErrorToArabic(plansSnapshot.error!),
              );
            }

            if (!plansSnapshot.hasData) {
              return const LoadingStateView(label: 'جارٍ تحميل الخطط');
            }

            final plans = plansSnapshot.data!;
            return StreamBuilder<List<AppUser>>(
              stream: widget.services.userProfileRepository.watchUsers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorStateView(
                    title: 'تعذر تحميل المستخدمين',
                    message: mapAppErrorToArabic(snapshot.error!),
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingStateView(label: 'جارٍ تحميل المستخدمين');
                }

                final users = List<AppUser>.of(snapshot.data!)
                  ..sort(_compareUsers);
                if (users.isEmpty) {
                  return const EmptyStateView(
                    title: 'لا يوجد مستخدمون',
                    message:
                        'ستظهر بيانات المستخدمين هنا بعد إضافة مستندات users.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return InfoCard(
                      title: _userTitle(user),
                      body: _buildUserSummary(user, plans),
                      trailing: _busyUserId == user.uid
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              onPressed: () async {
                                final result =
                                    await showDialog<_UserEditResult>(
                                      context: context,
                                      builder: (context) => _UserEditDialog(
                                        user: user,
                                        plans: plans,
                                      ),
                                    );
                                if (result == null || !mounted) {
                                  return;
                                }
                                await _applyUserEditResult(
                                  user: user,
                                  result: result,
                                );
                              },
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'تعديل المستخدم',
                            ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserEditResult {
  const _UserEditResult({required this.patch, this.pointsDelta});

  final _UserAdminPatch patch;
  final int? pointsDelta;

  bool get hasPatch => patch.hasChanges;
}

class _UserAdminPatch {
  const _UserAdminPatch({
    this.planId,
    this.points,
    this.isBlocked,
    this.aiUsageLimitOverride,
    this.clearAiUsageLimitOverride = false,
  });

  final String? planId;
  final int? points;
  final bool? isBlocked;
  final int? aiUsageLimitOverride;
  final bool clearAiUsageLimitOverride;

  bool get hasChanges =>
      planId != null ||
      points != null ||
      isBlocked != null ||
      aiUsageLimitOverride != null ||
      clearAiUsageLimitOverride;
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({required this.user, required this.plans});

  final AppUser user;
  final List<Plan> plans;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController _pointsController;
  late final TextEditingController _deltaController;
  late final TextEditingController _aiLimitController;
  late String _planId;
  late bool _isBlocked;

  @override
  void initState() {
    super.initState();
    _planId = widget.user.planId;
    _isBlocked = widget.user.isBlocked;
    _pointsController = TextEditingController(text: '${widget.user.points}');
    _deltaController = TextEditingController(text: '10');
    _aiLimitController = TextEditingController(
      text: widget.user.aiUsageLimitOverride?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _deltaController.dispose();
    _aiLimitController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String>> _buildPlanItems() {
    final items = widget.plans
        .map(
          (plan) => DropdownMenuItem<String>(
            value: plan.id,
            child: Text('${plan.name} (${plan.id})'),
          ),
        )
        .toList();

    final hasCurrentPlan = widget.plans.any((plan) => plan.id == _planId);
    if (!hasCurrentPlan && _planId.isNotEmpty) {
      items.insert(
        0,
        DropdownMenuItem<String>(
          value: _planId,
          child: Text('$_planId (الحالي)'),
        ),
      );
    }

    return items;
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int? _parsePositiveDelta() {
    final delta = int.tryParse(_deltaController.text.trim());
    if (delta == null || delta <= 0) {
      _showValidationMessage('أدخل عدد نقاط أكبر من صفر');
      return null;
    }
    return delta;
  }

  _UserAdminPatch? _buildPatch({required bool includePoints}) {
    int? points;
    if (includePoints) {
      points = int.tryParse(_pointsController.text.trim());
      if (points == null || points < 0) {
        _showValidationMessage('أدخل قيمة صحيحة للنقاط');
        return null;
      }
    }

    final aiText = _aiLimitController.text.trim();
    int? aiLimit;
    if (aiText.isNotEmpty) {
      aiLimit = int.tryParse(aiText);
      if (aiLimit == null || aiLimit < 0) {
        _showValidationMessage('أدخل حد AI صحيحًا أو اتركه فارغًا');
        return null;
      }
    }

    return _UserAdminPatch(
      planId: _planId != widget.user.planId ? _planId : null,
      points: includePoints && points != widget.user.points ? points : null,
      isBlocked: _isBlocked != widget.user.isBlocked ? _isBlocked : null,
      aiUsageLimitOverride:
          aiText.isNotEmpty && aiLimit != widget.user.aiUsageLimitOverride
          ? aiLimit
          : null,
      clearAiUsageLimitOverride:
          aiText.isEmpty && widget.user.aiUsageLimitOverride != null,
    );
  }

  void _submitPointsDelta({required bool isAddition}) {
    final delta = _parsePositiveDelta();
    if (delta == null) {
      return;
    }

    final patch = _buildPatch(includePoints: false);
    if (patch == null) {
      return;
    }

    Navigator.of(context).pop(
      _UserEditResult(patch: patch, pointsDelta: isAddition ? delta : -delta),
    );
  }

  void _submitSave() {
    final patch = _buildPatch(includePoints: true);
    if (patch == null) {
      return;
    }

    Navigator.of(context).pop(_UserEditResult(patch: patch));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.user.name.isEmpty ? widget.user.uid : widget.user.name,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.user.email ?? widget.user.uid,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _planId.isEmpty ? null : _planId,
              decoration: const InputDecoration(labelText: 'الباقة'),
              items: _buildPlanItems(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _planId = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'النقاط الحالية',
                helperText: 'لتعديل القيمة مباشرة ثم الضغط على حفظ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aiLimitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'حد استخدام AI للمستخدم',
                hintText: 'فارغ = استخدام الحد الافتراضي',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isBlocked,
              onChanged: (value) {
                setState(() {
                  _isBlocked = value;
                });
              },
              title: const Text('حظر المستخدم'),
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _deltaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'إضافة أو خصم نقاط',
                helperText: 'أدخل قيمة موجبة ثم اختر الإضافة أو الخصم',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => _submitPointsDelta(isAddition: true),
          child: const Text('إضافة نقاط'),
        ),
        TextButton(
          onPressed: () => _submitPointsDelta(isAddition: false),
          child: const Text('خصم نقاط'),
        ),
        FilledButton(onPressed: _submitSave, child: const Text('حفظ')),
      ],
    );
  }
}
