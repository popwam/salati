import 'package:flutter_test/flutter_test.dart';
import 'package:salati/features/admin_dashboard/models/admin_dashboard_access.dart';

void main() {
  group('AdminDashboardAccess permission resolution', () {
    test('role superAdmin has all permissions automatically', () {
      final access = AdminDashboardAccess.fromResolvedAccess(
        uid: 'super-1',
        data: const {'role': 'superAdmin'},
        resolvedPermissions: null,
      );

      expect(access.isSuperAdmin, isTrue);
      expect(access.can(AdminDashboardPermission.storeManage), isTrue);
      expect(access.can(AdminDashboardPermission.contentManage), isTrue);
      expect(access.can(AdminDashboardPermission.appConfigManage), isTrue);
      expect(access.effectivePermissions, AdminDashboardPermission.all);
    });

    test('legacy role super_admin has all permissions automatically', () {
      final access = AdminDashboardAccess.fromResolvedAccess(
        uid: 'super-legacy',
        data: const {'role': 'super_admin'},
        resolvedPermissions: null,
      );

      expect(access.isSuperAdmin, isTrue);
      expect(access.can(AdminDashboardPermission.storeManage), isTrue);
      expect(access.can(AdminDashboardPermission.contentManage), isTrue);
      expect(access.can(AdminDashboardPermission.azkarManage), isTrue);
      expect(access.effectivePermissions, AdminDashboardPermission.all);
    });

    test('dashboard.view grants normal admin full dashboard access', () {
      final dashboardAdmin = AdminDashboardAccess.fromResolvedAccess(
        uid: 'admin-1',
        data: const {
          'role': 'admin',
          'permissions': [AdminDashboardPermission.dashboardView],
        },
        resolvedPermissions: null,
      );

      expect(dashboardAdmin.isSuperAdmin, isFalse);
      expect(
        dashboardAdmin.can(AdminDashboardPermission.dashboardView),
        isTrue,
      );
      expect(dashboardAdmin.can(AdminDashboardPermission.storeManage), isTrue);
      expect(
        dashboardAdmin.can(AdminDashboardPermission.contentManage),
        isTrue,
      );
      expect(
        dashboardAdmin.can(AdminDashboardPermission.appConfigManage),
        isTrue,
      );
      expect(
        dashboardAdmin.can(AdminDashboardPermission.halaqatManage),
        isTrue,
      );
    });

    test('non-admin without permissions is denied', () {
      final access = AdminDashboardAccess.fromResolvedAccess(
        uid: 'user-1',
        data: const {'role': 'user'},
        resolvedPermissions: null,
      );

      expect(access.isPrivileged, isFalse);
      expect(access.canOpenDashboardHome, isFalse);
      expect(access.can(AdminDashboardPermission.dashboardView), isFalse);
      expect(access.can(AdminDashboardPermission.storeManage), isFalse);
    });
  });
}
