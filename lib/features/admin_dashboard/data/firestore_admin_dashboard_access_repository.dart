import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../auth/data/auth_service.dart';
import '../models/admin_dashboard_access.dart';

class FirestoreAdminDashboardAccessRepository {
  FirestoreAdminDashboardAccessRepository({
    required AuthService authService,
    required bool firebaseConfigured,
  }) : _authService = authService,
       _firebaseConfigured = firebaseConfigured;

  final AuthService _authService;
  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  Stream<AdminDashboardAccess?> watchCurrentAccess() {
    if (!_firebaseConfigured) {
      return Stream<AdminDashboardAccess?>.value(null);
    }

    return _authService.authStateChanges().asyncExpand((session) {
      if (session == null || session.uid.isEmpty) {
        return Stream<AdminDashboardAccess?>.value(null);
      }

      return _usersCollection.doc(session.uid).snapshots().asyncExpand((
        snapshot,
      ) {
        if (!snapshot.exists) {
          _logAuthz(
            uid: session.uid,
            role: 'missing-user-doc',
            userPermissions: const <String>{},
            rolePermissions: const <String>{},
            effectivePermissions: const <String>{},
            isSuperAdmin: false,
          );
          return Stream<AdminDashboardAccess?>.value(null);
        }

        final userData = snapshot.data() ?? const <String, dynamic>{};
        final role = adminDashboardRoleFromValue(
          _stringValue(userData['role']),
          fallbackIsAdmin: userData['isAdmin'] == true,
        );
        final userPermissions = _stringSetFrom(userData['permissions']);
        if (role == AdminDashboardRole.superAdmin) {
          _logAuthz(
            uid: snapshot.id,
            role: role.name,
            userPermissions: userPermissions,
            rolePermissions: const <String>{},
            effectivePermissions: const <String>{},
            isSuperAdmin: true,
          );
          return Stream<AdminDashboardAccess?>.value(
            AdminDashboardAccess.fromResolvedAccess(
              uid: snapshot.id,
              data: userData,
              resolvedPermissions: userPermissions,
            ),
          );
        }

        _logAuthz(
          uid: snapshot.id,
          role: role.name,
          userPermissions: userPermissions,
          rolePermissions: const <String>{},
          effectivePermissions: userPermissions,
          isSuperAdmin: false,
        );

        return Stream<AdminDashboardAccess?>.value(
          AdminDashboardAccess.fromResolvedAccess(
            uid: snapshot.id,
            data: userData,
            resolvedPermissions: userPermissions,
          ),
        );
      });
    });
  }

  Set<String> _stringSetFrom(dynamic value) {
    if (value == null) {
      return <String>{};
    }
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  // ignore: unused_element
  String _displayNameFor(Map<String, dynamic> userData) {
    final name = _stringValue(userData['name']);
    if (name != null) {
      return name;
    }
    final displayName = _stringValue(userData['displayName']);
    if (displayName != null) {
      return displayName;
    }
    final email = _stringValue(userData['email']);
    if (email != null) {
      final atIndex = email.indexOf('@');
      return atIndex > 0 ? email.substring(0, atIndex) : email;
    }
    return 'المشرف';
  }

  void _logAuthz({
    required String uid,
    required String role,
    required Set<String> userPermissions,
    required Set<String> rolePermissions,
    required Set<String> effectivePermissions,
    required bool isSuperAdmin,
  }) {
    if (!kDebugMode) {
      return;
    }

    final sortedUserPermissions = userPermissions.toList()..sort();
    final sortedRolePermissions = rolePermissions.toList()..sort();
    final sortedEffectivePermissions = effectivePermissions.toList()..sort();

    debugPrint('[Authz] uid: $uid');
    debugPrint('[Authz] role: $role');
    debugPrint('[Authz] userPermissions: $sortedUserPermissions');
    debugPrint('[Authz] rolePermissions: $sortedRolePermissions');
    debugPrint('[Authz] effectivePermissions: $sortedEffectivePermissions');
    debugPrint('[Authz] isSuperAdmin: $isSuperAdmin');
  }
}
