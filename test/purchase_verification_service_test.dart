import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:salati/features/subscriptions/data/purchase_verification_service.dart';

void main() {
  test('verify sends only server verification payload', () async {
    Map<String, dynamic>? captured;
    final service = PurchaseVerificationService(
      firebaseConfigured: true,
      callable: (data) async {
        captured = data;
        return {'success': true};
      },
    );

    final result = await service.verify(_purchase());

    expect(result.verified, isTrue);
    expect(captured, {
      'platform': 'android',
      'productId': 'salati_premium_monthly',
      'purchaseToken': 'purchase-token',
    });
    expect(captured!.containsKey('uid'), isFalse);
    expect(captured!.containsKey('entitlement'), isFalse);
    expect(captured!.containsKey('plan'), isFalse);
  });

  test('verify rejects missing store token before callable', () async {
    var called = false;
    final service = PurchaseVerificationService(
      firebaseConfigured: true,
      callable: (_) async {
        called = true;
        return {'success': true};
      },
    );

    final result = await service.verify(_purchase(token: ''));

    expect(result.verified, isFalse);
    expect(called, isFalse);
  });
}

PurchaseDetails _purchase({String token = 'purchase-token'}) {
  return PurchaseDetails(
    purchaseID: 'purchase-id',
    productID: 'salati_premium_monthly',
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-data',
      serverVerificationData: token,
      source: 'google_play',
    ),
    transactionDate: '1780000000000',
    status: PurchaseStatus.purchased,
  );
}
