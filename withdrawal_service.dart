import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../core/result.dart';
import 'api_client.dart';
import 'wallet_service.dart';

enum WithdrawalStatus {
  pending,
  approved,
  rejected,
  paid,
  cancelled,
}

class WithdrawalRequest {
  final String id;
  final int points;
  final double tl;
  final String method;
  final String destination;
  final WithdrawalStatus status;
  final DateTime createdAt;

  const WithdrawalRequest({
    required this.id,
    required this.points,
    required this.tl,
    required this.method,
    required this.destination,
    required this.status,
    required this.createdAt,
  });

  WithdrawalRequest copyWith({
    String? id,
    int? points,
    double? tl,
    String? method,
    String? destination,
    WithdrawalStatus? status,
    DateTime? createdAt,
  }) {
    return WithdrawalRequest(
      id: id ?? this.id,
      points: points ?? this.points,
      tl: tl ?? this.tl,
      method: method ?? this.method,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points,
      'tl': tl,
      'method': method,
      'destination': destination,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'pending';

    final status = WithdrawalStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => WithdrawalStatus.pending,
    );

    return WithdrawalRequest(
      id: json['id']?.toString() ?? '',
      points: _toInt(json['points']),
      tl: _toDouble(json['tl']),
      method: json['method']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      status: status,
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class WithdrawalService {
  WithdrawalService({
    ApiClient? apiClient,
    WalletService? walletService,
  })  : _apiClient = apiClient,
        _walletService = walletService;

  final ApiClient? _apiClient;
  final WalletService? _walletService;

  final Uuid _uuid = const Uuid();

  /// Creates a new withdrawal request.
  ///
  /// 1000 points = 1 TL.
  Future<Result<WithdrawalRequest>> createWithdrawal({
    required int points,
    required String method,
    required String destination,
  }) async {
    if (points <= 0) {
      return const Err('Çekim puanı 0’dan büyük olmalıdır.');
    }

    if (points < AppConfig.minimumWithdrawalPoints) {
      return Err(
        'Minimum çekim miktarı '
        '${AppConfig.minimumWithdrawalPoints} puandır.',
      );
    }

    if (points > AppConfig.maximumWithdrawalPoints) {
      return Err(
        'Maksimum çekim miktarı '
        '${AppConfig.maximumWithdrawalPoints} puandır.',
      );
    }

    if (method.trim().isEmpty) {
      return const Err('Ödeme yöntemi belirtilmelidir.');
    }

    if (destination.trim().isEmpty) {
      return const Err('Ödeme adresi belirtilmelidir.');
    }

    final tl = points / AppConfig.pointsPerLira;

    final request = WithdrawalRequest(
      id: _uuid.v4(),
      points: points,
      tl: tl,
      method: method.trim(),
      destination: destination.trim(),
      status: WithdrawalStatus.pending,
      createdAt: DateTime.now(),
    );

    try {
      if (_apiClient != null) {
        try {
          await _apiClient!.post(
            '/withdrawals',
            body: request.toJson(),
          );
        } catch (_) {
          // Backend is optional during development.
          // Keep the local request usable.
        }
      }

      return Ok(request);
    } catch (e) {
      return Err('Çekim oluşturulamadı: $e');
    }
  }

  /// Returns the current withdrawal status.
  Future<Result<WithdrawalStatus>> getStatus(
    String withdrawalId,
  ) async {
    if (withdrawalId.trim().isEmpty) {
      return const Err('Çekim ID boş olamaz.');
    }

    try {
      if (_apiClient != null) {
        try {
          final response = await _apiClient!.get(
            '/withdrawals/$withdrawalId',
          );

          if (response is Map<String, dynamic>) {
            final statusName = response['status']?.toString();

            final status = WithdrawalStatus.values.firstWhere(
              (item) => item.name == statusName,
              orElse: () => WithdrawalStatus.pending,
            );

            return Ok(status);
          }
        } catch (_) {
          // Backend unavailable; return pending state.
        }
      }

      return const Ok(WithdrawalStatus.pending);
    } catch (e) {
      return Err('Çekim durumu alınamadı: $e');
    }
  }

  /// Cancels a pending withdrawal.
  Future<Result<WithdrawalRequest>> cancelWithdrawal(
    WithdrawalRequest request,
  ) async {
    if (request.status != WithdrawalStatus.pending) {
      return const Err(
        'Sadece bekleyen çekimler iptal edilebilir.',
      );
    }

    try {
      final cancelled = request.copyWith(
        status: WithdrawalStatus.cancelled,
      );

      if (_apiClient != null) {
        try {
          await _apiClient!.post(
            '/withdrawals/${request.id}/cancel',
            body: {
              'id': request.id,
            },
          );
        } catch (_) {
          // Backend optional during development.
        }
      }

      return Ok(cancelled);
    } catch (e) {
      return Err('Çekim iptal edilemedi: $e');
    }
  }

  /// Validates whether the requested withdrawal amount is allowed.
  Result<double> validateAmount(int points) {
    if (points <= 0) {
      return const Err(
        'Çekim miktarı 0’dan büyük olmalıdır.',
      );
    }

    if (points < AppConfig.minimumWithdrawalPoints) {
      return Err(
        'Minimum çekim: '
        '${AppConfig.minimumWithdrawalPoints} puan.',
      );
    }

    if (points > AppConfig.maximumWithdrawalPoints) {
      return Err(
        'Maksimum çekim: '
        '${AppConfig.maximumWithdrawalPoints} puan.',
      );
    }

    return Ok(
      points / AppConfig.pointsPerLira,
    );
  }
}

/// Backwards-compatible service name.
///
/// If another part of the project already uses
/// RemoteWithdrawalService, this prevents a missing-class error.
class RemoteWithdrawalService extends WithdrawalService {
  RemoteWithdrawalService({
    super.apiClient,
    super.walletService,
  });
}
