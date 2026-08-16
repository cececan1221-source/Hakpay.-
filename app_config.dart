class AppConfig {
  AppConfig._();

  static const String appName = 'HakPay';

  static const String appVersion = '1.0.0';

  static const String currency = 'TRY';

  /// 1000 HakPay puanı = 1 TL
  static const int pointsPerLira = 1000;

  static const int minimumWithdrawalPoints = 10000;

  static const int maximumWithdrawalPoints = 1000000;

  static const String apiBaseUrl = 'https://api.hakpay.app';

  static const bool isProduction = false;
}
