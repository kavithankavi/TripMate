import '../config.dart';

/// How often a location sample is saved for the given battery [level] (%).
/// 3 s normally, 10 s when the battery is below 30%.
Duration sampleIntervalFor(int level) => level < AppConfig.lowBatteryThreshold
    ? AppConfig.lowBatterySampleInterval
    : AppConfig.sampleInterval;

/// Slack for timing jitter, so a fix that is due is not skipped.
const sampleTolerance = Duration(milliseconds: 800);

/// Whether a fix at [now] should be saved, given the last saved fix at
/// [lastSaved] and the current [interval].
bool isSampleDue(DateTime? lastSaved, DateTime now, Duration interval) =>
    lastSaved == null || now.difference(lastSaved) >= interval - sampleTolerance;
