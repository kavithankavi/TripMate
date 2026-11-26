/// App-wide tunable values.
class AppConfig {
  /// Normal sampling interval.
  static const Duration sampleInterval = Duration(seconds: 3);

  /// Sampling interval when the battery is below [lowBatteryThreshold].
  static const Duration lowBatterySampleInterval = Duration(seconds: 10);

  /// Battery percentage below which sampling slows down and the user is alerted.
  static const int lowBatteryThreshold = 30;

  /// How long the low battery alert stays on screen without acknowledgement.
  static const Duration lowBatteryAlertDuration = Duration(seconds: 10);

  /// A trip stops automatically after this long without movement.
  static const Duration idleAutoStop = Duration(hours: 2);

  /// Number of trips kept in history.
  static const int maxTrips = 10;
}
