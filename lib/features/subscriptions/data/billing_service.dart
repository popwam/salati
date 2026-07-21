import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.raw,
  });

  final String id;
  final String title;
  final String description;
  final String price;
  final ProductDetails raw;
}

class BillingPurchaseResult {
  const BillingPurchaseResult({required this.started, this.message});

  final bool started;
  final String? message;
}

abstract class BillingService {
  Stream<List<PurchaseDetails>> get purchases;

  Future<bool> isAvailable();

  Future<List<BillingProduct>> loadProducts();

  Future<BillingPurchaseResult> buy(BillingProduct product);

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseBillingService implements BillingService {
  InAppPurchaseBillingService({
    InAppPurchase? inAppPurchase,
    Set<String>? productIds,
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
       _productIds = productIds ?? defaultProductIds;

  static const defaultProductIds = <String>{
    'salati_premium_monthly',
    'salati_premium_yearly',
  };

  final InAppPurchase _inAppPurchase;
  final Set<String> _productIds;

  @override
  Stream<List<PurchaseDetails>> get purchases => _inAppPurchase.purchaseStream;

  @override
  Future<bool> isAvailable() {
    if (kIsWeb) {
      return Future<bool>.value(false);
    }
    return _inAppPurchase.isAvailable();
  }

  @override
  Future<List<BillingProduct>> loadProducts() async {
    if (!await isAvailable()) {
      return const [];
    }

    final response = await _inAppPurchase.queryProductDetails(_productIds);
    return response.productDetails
        .map(
          (product) => BillingProduct(
            id: product.id,
            title: product.title,
            description: product.description,
            price: product.price,
            raw: product,
          ),
        )
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<BillingPurchaseResult> buy(BillingProduct product) async {
    if (!await isAvailable()) {
      return const BillingPurchaseResult(
        started: false,
        message: 'Store billing is not available on this device.',
      );
    }

    final purchaseParam = PurchaseParam(productDetails: product.raw);
    final started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    return BillingPurchaseResult(started: started);
  }

  @override
  Future<void> restorePurchases() {
    return _inAppPurchase.restorePurchases();
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }
}
