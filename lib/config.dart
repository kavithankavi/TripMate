/// Build-time configuration.
///
/// Auth mode is chosen with `--dart-define=AUTH_MODE=firebase`.
/// The default is `mock`, a development mode that runs without any backend
/// and accepts the OTP code [mockOtpCode].
class AppConfig {
  static const String authMode =
      String.fromEnvironment('AUTH_MODE', defaultValue: 'mock');

  static bool get useFirebase => authMode == 'firebase';

  /// OTP accepted in mock (dev) mode.
  static const String mockOtpCode = '123456';

  /// Default country code shown on the phone screen (guess: India).
  static const String defaultCountryCode = '+91';

  /// Normal sampling interval.
  static const Duration sampleInterval = Duration(seconds: 10);

  /// Sampling interval when the battery is below [lowBatteryThreshold].
  static const Duration lowBatterySampleInterval = Duration(seconds: 30);

  /// Battery percentage below which sampling slows down and the user is alerted.
  static const int lowBatteryThreshold = 30;

  /// How long the low battery alert stays on screen without acknowledgement.
  static const Duration lowBatteryAlertDuration = Duration(seconds: 10);

  /// A trip stops automatically after this long without movement.
  static const Duration idleAutoStop = Duration(hours: 2);

  /// Number of trips kept in history.
  static const int maxTrips = 10;
}
