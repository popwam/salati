import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobRewardService {
  // Google-provided demo ad units. Replace these with the production IDs
  // before publishing the app.
  static const _androidRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const _iosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  static String get rewardedAdUnitId => switch (defaultTargetPlatform) {
    TargetPlatform.android => _androidRewardedAdUnitId,
    TargetPlatform.iOS => _iosRewardedAdUnitId,
    _ => '',
  };

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _disposed = false;

  bool get isReady =>
      _isSupportedPlatform && _rewardedAd != null && !_isShowing && !_disposed;

  Future<void> loadRewardedAd() async {
    if (!_isSupportedPlatform ||
        _disposed ||
        _isLoading ||
        _rewardedAd != null) {
      return;
    }

    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoading = false;
            if (_disposed) {
              unawaited(ad.dispose());
              return;
            }
            _rewardedAd = ad;
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _rewardedAd = null;
            debugPrint('Rewarded ad failed to load: $error');
          },
        ),
      );
    } catch (error, stackTrace) {
      _isLoading = false;
      _rewardedAd = null;
      debugPrint('Rewarded ad load threw: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> showRewardedAd({
    required VoidCallback onUserEarnedReward,
  }) async {
    if (!_isSupportedPlatform) {
      return false;
    }
    final ad = _rewardedAd;
    if (_disposed || _isShowing || ad == null) {
      unawaited(loadRewardedAd());
      return false;
    }

    _rewardedAd = null;
    _isShowing = true;
    final rewardCompleter = Completer<bool>();
    var earnedReward = false;

    void completeOnce(bool value) {
      if (!rewardCompleter.isCompleted) {
        rewardCompleter.complete(value);
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        _disposeShownAdAndReload(ad);
        completeOnce(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
        _disposeShownAdAndReload(ad);
        completeOnce(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earnedReward = true;
          onUserEarnedReward();
        },
      );
      return rewardCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => earnedReward,
      );
    } catch (error, stackTrace) {
      debugPrint('Rewarded ad show threw: $error');
      debugPrintStack(stackTrace: stackTrace);
      _disposeShownAdAndReload(ad);
      completeOnce(false);
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _isLoading = false;
    _isShowing = false;
    final ad = _rewardedAd;
    _rewardedAd = null;
    if (ad != null) {
      unawaited(ad.dispose());
    }
  }

  void _disposeShownAdAndReload(RewardedAd ad) {
    _isShowing = false;
    unawaited(ad.dispose());
    if (!_disposed) {
      unawaited(loadRewardedAd());
    }
  }
}
