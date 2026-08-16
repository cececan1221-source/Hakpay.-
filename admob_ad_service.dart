import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../core/result.dart';
import 'ad_service.dart';
import 'wallet_service.dart';

/// Gerçek AdMob rewarded entegrasyonu.
/// - Test ID'ler varsayılan (Google resmi örnek birimler)
/// - Production: --dart-define=ADMOB_APP_ID=... ADMOB_REWARDED_ID=...
/// - Ödül kredisi: demo cüzdanda reference_id; production'da backend claim şart
class AdMobAdService implements AdService {
  AdMobAdService(this._wallet);

  final WalletService _wallet;
  final _uuid = const Uuid();
  bool _initialized = false;
  final _open = <String, AdSession>{};

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      // İsteğe bağlı: test cihazı
      // MobileAds.instance.updateRequestConfiguration(
      //   RequestConfiguration(testDeviceIds: ['YOUR_DEVICE_ID']),
      // );
      _initialized = true;
    } catch (e) {
      // SDK yüklenemezse üst katman demo'ya düşebilir
      rethrow;
    }
  }

  bool get isReady => _initialized;

  Future<bool> _showOneRewarded() async {
    final completer = Completer<bool>();
    var earned = false;

    await RewardedAd.load(
      adUnitId: AppConfig.effectiveRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              earned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => false,
    );
  }

  @override
  Future<Result<AdSession>> openSession({String adType = 'rewarded'}) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        return Err('AdMob başlatılamadı: $e');
      }
    }
    final id = _uuid.v4();
    final s = AdSession(
      sessionId: id,
      adType: adType,
      openedAt: DateTime.now(),
    );
    _open[id] = s;
    return Ok(s);
  }

  @override
  Future<Result<bool>> completeSession(String sessionId) async {
    final s = _open[sessionId];
    if (s == null) return const Err('Oturum bulunamadı');
    if (s.completed) return const Err('Oturum zaten tamamlanmış');

    final ok = await _showOneRewarded();
    if (!ok) return const Err('Reklam yüklenemedi veya ödül kazanılmadı');

    _open[sessionId] = AdSession(
      sessionId: s.sessionId,
      adType: s.adType,
      openedAt: s.openedAt,
      completed: true,
    );
    return const Ok(true);
  }

  @override
  Future<Result<int>> claimReward(String sessionId) async {
    final s = _open[sessionId];
    if (s == null || !s.completed) {
      return const Err('Önce reklamı tamamlayın');
    }
    if (s.claimed) return const Err('Ödül zaten alınmış');

    // Production: burada backend'e SSV / server verify gönderilmeli
    final credit = await _wallet.creditByReference(
      referenceId: 'admob_$sessionId',
      reason: 'ad_reward',
    );
    if (credit.isErr) return Err(credit.errorOrNull!);

    _open[sessionId] = AdSession(
      sessionId: s.sessionId,
      adType: s.adType,
      openedAt: s.openedAt,
      completed: true,
      claimed: true,
    );
    return Ok(AppConfig.singleAdPoints);
  }

  @override
  Future<Result<int>> runTripleAdCycle() async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        return Err('AdMob başlatılamadı: $e');
      }
    }

    var watched = 0;
    for (var i = 0; i < 3; i++) {
      final ok = await _showOneRewarded();
      if (!ok) break;
      watched++;
    }
    if (watched == 0) {
      return const Err('Hiç reklam izlenemedi');
    }

    final points = watched * AppConfig.singleAdPoints;
    final ref =
        'admob_triple_${DateTime.now().millisecondsSinceEpoch}_$watched';
    final credit = await _wallet.creditByReference(
      referenceId: ref,
      reason: 'triple_ad',
    );
    if (credit.isErr) return Err(credit.errorOrNull!);
    return Ok(points);
  }
}

AdService createAdMobAwareAdService(WalletService wallet) {
  return AdMobAdService(wallet);
}
