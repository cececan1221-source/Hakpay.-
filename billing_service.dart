import '../config/app_config.dart';
import '../core/result.dart';
import 'api_client.dart';

enum VipTier { none, bronze, gold, diamond }

class VipStatus {
  final VipTier tier;
  final DateTime? expiresAt;
  final bool hasSubscription;

  const VipStatus({
    this.tier = VipTier.none,
    this.expiresAt,
    this.hasSubscription = false,
  });
}

/// MVP: Play Billing native SDK yok — demo VIP.
abstract class BillingService {
  Future<void> initialize();
  Future<Result<bool>> purchase(String productId);
  Future<Result<VipStatus>> getVipStatus();
  Future<void> restore();
}

class DemoBillingService implements BillingService {
  VipStatus _status = const VipStatus();

  @override
  Future<void> initialize() async {}

  @override
  Future<Result<bool>> purchase(String productId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (productId.contains('bronze')) {
      _status = VipStatus(
        tier: VipTier.bronze,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
    } else if (productId.contains('gold')) {
      _status = VipStatus(
        tier: VipTier.gold,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
    } else if (productId.contains('diamond')) {
      _status = VipStatus(
        tier: VipTier.diamond,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
    } else if (productId.contains('sub')) {
      _status = VipStatus(
        tier: VipTier.gold,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        hasSubscription: true,
      );
    }
    return const Ok(true);
  }

  @override
  Future<Result<VipStatus>> getVipStatus() async => Ok(_status);

  @override
  Future<void> restore() async {}
}

class RemoteBillingService implements BillingService {
  RemoteBillingService(this._api);
  final ApiClient _api;

  @override
  Future<void> initialize() async {}

  @override
  Future<Result<bool>> purchase(String productId) async {
    final res = await _api.post('/v1/billing/purchase', body: {
      'product_id': productId,
    });
    return res.when(ok: (_) => const Ok(true), err: (m) => Err(m));
  }

  @override
  Future<Result<VipStatus>> getVipStatus() async {
    final res = await _api.get('/v1/vip/status');
    return res.when(
      ok: (d) {
        final tierStr = d['tier']?.toString() ?? 'none';
        final tier = VipTier.values.firstWhere(
          (e) => e.name == tierStr,
          orElse: () => VipTier.none,
        );
        return Ok(VipStatus(
          tier: tier,
          expiresAt: DateTime.tryParse(d['expires_at']?.toString() ?? ''),
          hasSubscription: d['has_subscription'] == true,
        ));
      },
      err: (m) => Err(m),
    );
  }

  @override
  Future<void> restore() async {}
}

BillingService createBillingService(ApiClient? api) {
  if (AppConfig.isRemote && api != null) return RemoteBillingService(api);
  return DemoBillingService();
}
