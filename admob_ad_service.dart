import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../core/result.dart';
import 'ad_service.dart';
import 'wallet_service.dart';

/// Gerçek Google AdMob reklam servisi.
///
/// AdService arayüzü ile uyumludur:
/// - openSession()
/// - claim()
/// - showRewarded()
/// - showInterstitial()
/// - runTripleAdCycle()
///
/// Test reklam ID'leri AppConfig tarafından varsayılan olarak kullanılır.
/// Production ID'leri --dart-define ile verilebilir.
class AdMobAdService implements AdService {
  AdMobAdService(this._wallet);

  final WalletService _wallet;
  final Uuid _uuid = const Uuid();

  bool _initialized = false;

  /// Açılmış reklam oturumları.
  final Map<String, AdSession> _open = <String, AdSession>{};

  /// Reklamı başarıyla izlenen oturumlar.
  final Set<String> _watchedSessions = <String>{};

  /// Son gösterilen rewarded reklamın ödül verip vermediği.
  bool _rewardedEarned = false;

  /// Son interstitial reklam sonucu.
  bool _interstitialShown = false;

  /// AdMob SDK'yı başlatır.
  Future<void> initialize() async {
    if (_initialized) return;

    await MobileAds.instance.initialize();

    _initialized = true;
  }

  /// AdMob hazır mı?
  bool get isReady => _initialized;

  /// Rewarded reklam gösterir.
  Future<bool> _showOneRewarded() async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (_) {
        return false;
      }
    }

    final Completer<bool> completer = Completer<bool>();

    bool earned = false;

    await RewardedAd.load(
      adUnitId: AppConfig.effectiveRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (Ad ad) {
              ad.dispose();

              if (!completer.isCompleted) {
                completer.complete(earned);
              }
            },
            onAdFailedToShowFullScreenContent:
                (Ad ad, AdError error) {
              ad.dispose();

              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );

          ad.show(
            onUserEarnedReward:
                (AdWithoutView ad, RewardItem reward) {
              earned = true;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  /// Interstitial reklam gösterir.
  Future<bool> _showOneInterstitial() async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (_) {
        return false;
      }
    }

    final Completer<bool> completer = Completer<bool>();

    await InterstitialAd.load(
      adUnitId: AppConfig.effectiveInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (Ad ad) {
              ad.dispose();

              if (!completer.isCompleted) {
                completer.complete(true);
              }
            },
            onAdFailedToShowFullScreenContent:
                (Ad ad, AdError error) {
              ad.dispose();

              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );

          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------
  // AdService IMPLEMENTASYONU
  // -------------------------------------------------------

  @override
  Future<Result<AdSession>> openSession({
    String adType = 'rewarded',
  }) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        return Err('AdMob başlatılamadı: $e');
      }
    }

    final String id = _uuid.v4();

    final AdSession session = AdSession(
      sessionId: id,
      adType: adType,
      createdAt: DateTime.now(),
    );

    _open[id] = session;

    return Ok(session);
  }

  @override
  Future<bool> showRewarded() async {
    _rewardedEarned = false;

    final bool success = await _showOneRewarded();

    _rewardedEarned = success;

    return success;
  }

  @override
  Future<bool> showInterstitial() async {
    _interstitialShown = false;

    final bool success = await _showOneInterstitial();

    _interstitialShown = success;

    return success;
  }

  @override
  Future<Result<int>> claim(String sessionId) async {
    final String id = sessionId.trim();

    if (id.isEmpty) {
      return const Err('Geçersiz oturum kimliği');
    }

    final AdSession? session = _open[id];

    if (session == null) {
      return const Err('Geçersiz veya süresi dolmuş oturum');
    }

    if (_watchedSessions.contains(id)) {
      return const Err('Bu reklam oturumu zaten kullanıldı');
    }

    if (!_rewardedEarned) {
      return const Err('Önce reklamı tamamlayın');
    }

    /// Production'da burada backend / SSV doğrulaması yapılmalıdır.
    final credit = await _wallet.creditByReference(
      referenceId: 'admob_$id',
      reason: 'ad_reward',
    );

    if (credit.isErr) {
      return Err(credit.errorOrNull!);
    }

    _watchedSessions.add(id);

    _rewardedEarned = false;

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

    var total = 0;

    for (var i = 0; i < 3; i++) {
      final sessionResult = await openSession(
        adType: 'rewarded',
      );

      if (sessionResult.isErr) {
        return Err(sessionResult.errorOrNull!);
      }

      final session = sessionResult.valueOrNull;

      if (session == null) {
        return const Err('Reklam oturumu oluşturulamadı');
      }

      final bool shown = await showRewarded();

      if (!shown) {
        return Err(
          'Reklam ${i + 1}/3 gösterilemedi',
        );
      }

      final claimResult = await claim(
        session.sessionId,
      );

      if (claimResult.isErr) {
        return Err(claimResult.errorOrNull!);
      }

      total += claimResult.valueOrNull ?? 0;
    }

    return Ok(total);
  }
}

/// AdMob aware servis oluşturucu.
AdService createAdMobAwareAdService(
  WalletService wallet,
) {
  return AdMobAdService(wallet);
}
