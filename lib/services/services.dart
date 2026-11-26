import '../data/trip_database.dart';
import 'trip_tracker.dart';

/// Simple service locator; keeps the app free of extra state packages.
class Services {
  static late final TripDatabase db;
  static late final TripTracker tracker;

  static Future<void> init() async {
    db = TripDatabase();
    tracker = TripTracker(db);
    await tracker.recoverUnfinished();
  }
}
