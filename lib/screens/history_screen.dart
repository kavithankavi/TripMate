import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../models/trip.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/format.dart';
import 'trip_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Trip>> _trips = Services.db.recentTrips();

  void _reload() => setState(() => _trips = Services.db.recentTrips());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip history')),
      body: FutureBuilder<List<Trip>>(
        future: _trips,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snap.data!;
          if (trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No trips yet. Your last 10 trips will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == trips.length) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                      'Showing your last ${AppConfig.maxTrips} trips.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                );
              }
              final t = trips[i];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.route_rounded,
                        color: AppColors.primary),
                  ),
                  title: Text(t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${fmtDateTime(t.startTime)}\n${fmtKm(t.distanceM)} · ${fmtDuration(t.duration)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) =>
                            TripDetailScreen(trips: trips, initialIndex: i)));
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
