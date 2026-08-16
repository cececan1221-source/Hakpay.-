/// Central application configuration for HakPay.
///
/// Keep configuration values in one place so services don't
/// depend on hard-coded values scattered throughout the app.
class AppConfig {
  AppConfig._();

  static const String appName = 'HakPay';

  static const String appVersion = '1.0.0';

  /// Default currency used by the application.
  static const String currency = 'TRY';

  /// HakPay point conversion.
  ///
  /// 1000 points = 1 TL
  static const int pointsPerLira = 1000;

  /// Minimum withdrawal amount in points.
  static const int minimumWithdrawalPoints = 10000;

  /// Maximum withdrawal amount in points.
  static const int maximumWithdrawalPoints = 1000000;

  /// API base URL.
  ///
  /// Change this later when the real backend is ready.
  static const String apiBaseUrl = 'https://api.hakpay.app';

  /// Whether the application is running against a production backend.
  static const bool isProduction = false;
}
