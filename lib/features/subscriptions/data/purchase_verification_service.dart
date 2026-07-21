import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseVerificationResult {
  const PurchaseVerificationResult({
    required this.verified,
    required this.message,
  });

  final bool verified;
  final String message;
}

typedef PurchaseVerificationCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

class PurchaseVerificationService {
  PurchaseVerificationService({
    required bool firebaseConfigured,
    PurchaseVerificationCallable? callable,
  }) : _firebaseConfigured = firebaseConfigured,
       _callable = callable;

  final bool _firebaseConfigured;
  final PurchaseVerificationCallable? _callable;

  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase) async {
    if (!_firebaseConfigured) {
      return const PurchaseVerificationResult(
        verified: false,
        message: 'Firebase is not configured for purchase verification.',
      );
    }

    final token = purchase.verificationData.serverVerificationData.trim();
    if (token.isEmpty) {
      return const PurchaseVerificationResult(
        verified: false,
        message: 'Store verification token is missing.',
      );
    }

    final platform = _platformForPurchase(purchase);
    if (platform == null) {
      return const PurchaseVerificationResult(
        verified: false,
        message: 'Purchase platform is not supported for verification.',
      );
    }

    try {
      final data = {
        'platform': platform,
        'productId': purchase.productID,
        'purchaseToken': token,
      };
      final response = await (_callable ?? _defaultCallable)(data);
      final success = response['success'] == true;
      return PurchaseVerificationResult(
        verified: success,
        message: success
            ? 'Purchase verified by server.'
            : 'Purchase was not verified by server.',
      );
    } on FirebaseFunctionsException catch (error) {
      return PurchaseVerificationResult(
        verified: false,
        message: error.message ?? 'Purchase verification failed.',
      );
    } catch (_) {
      return const PurchaseVerificationResult(
        verified: false,
        message: 'Purchase verification failed.',
      );
    }
  }

  String? _platformForPurchase(PurchaseDetails purchase) {
    final source = purchase.verificationData.source.toLowerCase();
    if (source.contains('google') || source.contains('play')) {
      return 'android';
    }
    if (source.contains('app_store') ||
        source.contains('appstore') ||
        source.contains('ios')) {
      return 'ios';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> data,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('verifyPurchase');
    final response = await callable.call<Map<dynamic, dynamic>>(data);
    return response.data.map((key, value) => MapEntry(key.toString(), value));
  }
}
