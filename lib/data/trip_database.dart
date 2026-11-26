import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../models/trip.dart';

/// Local SQLite storage for trips and their sampled points.
class TripDatabase {
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'tripmate.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE trips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            start_lat REAL, start_lng REAL,
            end_lat REAL, end_lng REAL,
            start_address TEXT, end_address TEXT,
            distance_m REAL NOT NULL DEFAULT 0,
            max_speed_kmh REAL NOT NULL DEFAULT 0,
            avg_speed_kmh REAL NOT NULL DEFAULT 0,
            max_altitude_m REAL
          )''');
        await db.execute('''
          CREATE TABLE points(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
            time INTEGER NOT NULL,
            lat REAL NOT NULL, lng REAL NOT NULL,
            alt REAL NOT NULL, speed_kmh REAL NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_points_trip ON points(trip_id)');
      },
    );
  }

  Future<int> insertTrip(Trip t) async => (await db).insert('trips', t.toMap());

  Future<void> updateTrip(Trip t) async =>
      (await db).update('trips', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> renameTrip(int id, String name) async => (await db)
      .update('trips', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<void> insertPoint(int tripId, TrackPoint pt) async =>
      (await db).insert('points', pt.toMap(tripId));

  Future<List<TrackPoint>> points(int tripId) async {
    final rows = await (await db).query('points',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'time');
    return rows.map(TrackPoint.fromMap).toList();
  }

  /// Finished trips, newest first (at most [AppConfig.maxTrips]).
  Future<List<Trip>> recentTrips() async {
    final rows = await (await db).query('trips',
        where: 'end_time IS NOT NULL',
        orderBy: 'start_time DESC',
        limit: AppConfig.maxTrips);
    return rows.map(Trip.fromMap).toList();
  }

  Future<List<Trip>> unfinishedTrips() async {
    final rows = await (await db).query('trips', where: 'end_time IS NULL');
    return rows.map(Trip.fromMap).toList();
  }

  Future<int> tripCount() async {
    final r = await (await db).rawQuery('SELECT MAX(id) AS n FROM trips');
    return (r.first['n'] as int?) ?? 0;
  }

  /// Keeps only the newest [AppConfig.maxTrips] finished trips.
  Future<void> pruneOldTrips() async {
    await (await db).rawDelete('''
      DELETE FROM trips WHERE end_time IS NOT NULL AND id NOT IN (
        SELECT id FROM trips WHERE end_time IS NOT NULL
        ORDER BY start_time DESC LIMIT ?)''', [AppConfig.maxTrips]);
  }

  Future<void> deleteTrip(int id) async =>
      (await db).delete('trips', where: 'id = ?', whereArgs: [id]);

  /// Erases every trip and point (used by "Forgot PIN").
  Future<void> deleteAllTrips() async {
    final d = await db;
    await d.delete('points');
    await d.delete('trips');
  }
}
