import '../config/app_config.dart';
import '../core/result.dart';
import '../services/api_client.dart';

class TaskItem {
  final String id;
  final String title;
  final String description;
  final int rewardPoints;
  final String type; // daily | once | survey | offer
  final bool completed;

  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.type,
    this.completed = false,
  });

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        rewardPoints: (j['reward_points'] as num?)?.toInt() ?? 0,
        type: j['type']?.toString() ?? 'daily',
        completed: j['completed'] == true,
      );
}

class ShopProduct {
  final String id;
  final String title;
  final int pricePoints;
  final int coinAmount;
  final String assetType; // paradox_manga | uc
  final String imageUrl;
  final bool requiresTripleAd;

  const ShopProduct({
    required this.id,
    required this.title,
    required this.pricePoints,
    required this.coinAmount,
    this.assetType = 'paradox_manga',
    this.imageUrl = '',
    this.requiresTripleAd = true,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> j) => ShopProduct(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        pricePoints: (j['price_points'] as num?)?.toInt() ?? 0,
        coinAmount: (j['coin_amount'] as num?)?.toInt() ?? 0,
        assetType: j['asset_type']?.toString() ?? 'paradox_manga',
        imageUrl: j['image_url']?.toString() ?? '',
        requiresTripleAd: j['requires_triple_ad'] != false,
      );
}

class WheelPrize {
  final String id;
  final String label;
  final int points;
  final double weight;

  const WheelPrize({
    required this.id,
    required this.label,
    required this.points,
    this.weight = 1,
  });

  factory WheelPrize.fromJson(Map<String, dynamic> j) => WheelPrize(
        id: j['id']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        points: (j['points'] as num?)?.toInt() ?? 0,
        weight: (j['weight'] as num?)?.toDouble() ?? 1,
      );
}

/// Katalog sınırı: demo mock veya remote API.
abstract class CatalogRepository {
  Future<Result<List<TaskItem>>> getTasks();
  Future<Result<List<ShopProduct>>> getShop();
  Future<Result<List<WheelPrize>>> getWheelPrizes();
  Future<Result<TaskItem>> completeTask(String taskId);
}

class DemoCatalogRepository implements CatalogRepository {
  final _tasks = [
    const TaskItem(
      id: 't1',
      title: 'Anket Tamamla',
      description: '5–7 dakika · Kısa anketleri tamamla, ödülünü kazan.',
      rewardPoints: 500,
      type: 'survey',
    ),
    const TaskItem(
      id: 't2',
      title: 'Video İzle',
      description: '30 saniye · Kısa videoları izle, kazanmaya devam et.',
      rewardPoints: 60,
      type: 'daily',
    ),
    const TaskItem(
      id: 't3',
      title: 'Arkadaşını Davet Et',
      description: 'Bonus Kazan · Arkadaşlarını davet et, bonus kazan!',
      rewardPoints: 1000,
      type: 'once',
    ),
    const TaskItem(
      id: 't4',
      title: 'Uygulama Puanla',
      description: '2 dakika · Uygulamayı puanla, ödül kazan.',
      rewardPoints: 200,
      type: 'once',
    ),
    const TaskItem(
      id: 't5',
      title: 'Paylaş & Kazan',
      description: '1 dakika · Uygulamayı paylaş, ödül kazan.',
      rewardPoints: 400,
      type: 'once',
    ),
    const TaskItem(
      id: 't6',
      title: 'Oyun Oyna · Para Kazan',
      description: 'Offerwall · Oyun ve teklifleri tamamla · %35 pay',
      rewardPoints: 52,
      type: 'offer',
    ),
    const TaskItem(
      id: 't7',
      title: 'Özel Görevler',
      description: 'Özel görevleri tamamla, yüksek ödüller kazan!',
      rewardPoints: 2000,
      type: 'once',
    ),
  ];

  // MVP: UC paketleri. Nakit yok.
  final _shop = [
    const ShopProduct(
      id: 'uc_30',
      title: '30 UC',
      pricePoints: AppConfig.shopUc30Points,
      coinAmount: AppConfig.shopUc30Amount,
      assetType: 'uc',
      requiresTripleAd: true,
    ),
    const ShopProduct(
      id: 'uc_60',
      title: '60 UC',
      pricePoints: AppConfig.shopUc60Points,
      coinAmount: AppConfig.shopUc60Amount,
      assetType: 'uc',
      requiresTripleAd: true,
    ),
  ];

  final _wheel = [
    const WheelPrize(id: 'w1', label: '10 puan', points: 10, weight: 30),
    const WheelPrize(id: 'w2', label: '25 puan', points: 25, weight: 25),
    const WheelPrize(id: 'w3', label: '50 puan', points: 50, weight: 20),
    const WheelPrize(id: 'w4', label: '100 puan', points: 100, weight: 15),
    const WheelPrize(id: 'w5', label: '250 puan', points: 250, weight: 8),
    const WheelPrize(id: 'w6', label: '1000 puan', points: 1000, weight: 2),
  ];

  @override
  Future<Result<List<TaskItem>>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Ok(List.of(_tasks));
  }

  @override
  Future<Result<List<ShopProduct>>> getShop() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Ok(List.of(_shop));
  }

  @override
  Future<Result<List<WheelPrize>>> getWheelPrizes() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return Ok(List.of(_wheel));
  }

  @override
  Future<Result<TaskItem>> completeTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return const Err('Görev bulunamadı');
    final t = _tasks[idx];
    if (t.completed) return const Err('Görev zaten tamamlandı');
    // Demo: sadece işaretle — puan wallet.creditByReference ile verilir
    return Ok(TaskItem(
      id: t.id,
      title: t.title,
      description: t.description,
      rewardPoints: t.rewardPoints,
      type: t.type,
      completed: true,
    ));
  }
}

class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<TaskItem>>> getTasks() async {
    final res = await _api.get('/v1/tasks');
    return res.when(
      ok: (d) {
        final list = (d['items'] as List?) ?? [];
        return Ok(list
            .whereType<Map<String, dynamic>>()
            .map(TaskItem.fromJson)
            .toList());
      },
      err: (m) => Err(m),
    );
  }

  @override
  Future<Result<List<ShopProduct>>> getShop() async {
    final res = await _api.get('/v1/shop');
    return res.when(
      ok: (d) {
        final list = (d['items'] as List?) ?? [];
        return Ok(list
            .whereType<Map<String, dynamic>>()
            .map(ShopProduct.fromJson)
            .toList());
      },
      err: (m) => Err(m),
    );
  }

  @override
  Future<Result<List<WheelPrize>>> getWheelPrizes() async {
    final res = await _api.get('/v1/wheel/prizes');
    return res.when(
      ok: (d) {
        final list = (d['items'] as List?) ?? [];
        return Ok(list
            .whereType<Map<String, dynamic>>()
            .map(WheelPrize.fromJson)
            .toList());
      },
      err: (m) => Err(m),
    );
  }

  @override
  Future<Result<TaskItem>> completeTask(String taskId) async {
    final res = await _api.post('/v1/tasks/$taskId/complete');
    return res.when(
      ok: (d) => Ok(TaskItem.fromJson(d)),
      err: (m) => Err(m),
    );
  }
}

CatalogRepository createCatalogRepository(ApiClient? api) {
  if (AppConfig.isRemote && api != null) return RemoteCatalogRepository(api);
  return DemoCatalogRepository();
}
