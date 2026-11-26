import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../models/trip.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/line_chart.dart';
import '../widgets/route_map.dart';

/// Details of one trip, with Prev (older) and Next (newer) navigation.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.trips,
    required this.initialIndex,
    this.notice,
  });

  /// Trips newest first.
  final List<Trip> trips;
  final int initialIndex;
  final String? notice;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late List<Trip> _trips = widget.trips;
  late int _index = widget.initialIndex;
  Future<List<TrackPoint>>? _points;

  Trip get _trip => _trips[_index];

  @override
  void initState() {
    super.initState();
    _loadRoute();
    // Opened right after a trip: load the full history for Prev/Next.
    if (_trips.length == 1) {
      final id = _trip.id;
      Services.db.recentTrips().then((all) {
        final i = all.indexWhere((t) => t.id == id);
        if (mounted && i >= 0) {
          setState(() {
            _trips = all;
            _index = i;
          });
        }
      });
    }
  }

  void _loadRoute() {
    _points = Services.db.points(_trip.id!);
  }

  void _go(int i) => setState(() {
        _index = i;
        _loadRoute();
      });

  Future<void> _rename() async {
    final c = TextEditingController(text: _trip.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename trip'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Trip name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    await Services.db.renameTrip(_trip.id!, name);
    setState(() => _trip.name = name);
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    final hasOlder = _index < _trips.length - 1;
    final hasNewer = _index > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              tooltip: 'Rename',
              onPressed: _rename,
              icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.notice != null)
            Card(
              color: AppColors.accent.withValues(alpha: 0.18),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.notice!),
              ),
            ),
          Text(
            '${fmtDateTime(t.startTime)}  to  ${t.endTime == null ? '-' : fmtDateTime(t.endTime!)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: FutureBuilder<List<TrackPoint>>(
                key: ValueKey(t.id),
                future: _points,
                builder: (_, s) => s.hasData
                    ? RouteMap(
                        route: [
                          for (final p in s.data!) LatLng(p.lat, p.lng)
                        ],
                        follow: false,
                        interactive: true)
                    : const ColoredBox(color: Color(0xFFE2EBEA)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              _Row(Icons.trip_origin_rounded, 'Start location',
                  fmtPlace(t.startAddress, t.startLat, t.startLng)),
              _Row(Icons.place_rounded, 'Stop location',
                  fmtPlace(t.endAddress, t.endLat, t.endLng)),
              _Row(Icons.straighten_rounded, 'Distance covered',
                  fmtKm(t.distanceM)),
              _Row(Icons.timer_outlined, 'Duration', fmtDuration(t.duration)),
              _Row(Icons.speed_rounded, 'Average speed',
                  fmtSpeed(t.avgSpeedKmh)),
              _Row(Icons.bolt_rounded, 'Max speed', fmtSpeed(t.maxSpeedKmh)),
              _Row(Icons.terrain_rounded, 'Max altitude',
                  fmtAlt(t.maxAltitudeM)),
            ]),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<TrackPoint>>(
            key: ValueKey('charts-${t.id}'),
            future: _points,
            builder: (_, s) => s.hasData
                ? _TripCharts(trip: t, points: s.data!)
                : const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator())),
          ),
          const SizedBox(height: 8),
          Text('Trip ${_trips.length - _index} of ${_trips.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasOlder ? () => _go(_index + 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Prev trip'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                iconAlignment: IconAlignment.end,
                onPressed: hasNewer ? () => _go(_index - 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next trip'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Speed and altitude over the whole trip, each in its own line graph.
/// The speed graph also shows the trip's average speed as a dashed line.
class _TripCharts extends StatelessWidget {
  const _TripCharts({required this.trip, required this.points});
  final Trip trip;
  final List<TrackPoint> points;

  @override
  Widget build(BuildContext context) {
    final start = trip.startTime;
    final total = trip.duration;
    ChartPoint at(TrackPoint p, double v) => ChartPoint(p.time.difference(start), v);
    return Column(children: [
      _ChartCard(
        icon: Icons.speed_rounded,
        title: 'Speed (km/h)',
        child: TripLineChart(
          points: [for (final p in points) at(p, p.speedKmh)],
          total: total,
          startAtZero: true,
          reference: trip.avgSpeedKmh,
          referenceLabel: 'Avg ${fmtSpeed(trip.avgSpeedKmh)}',
        ),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        icon: Icons.terrain_rounded,
        title: 'Altitude (m)',
        child: TripLineChart(
          points: [for (final p in points) at(p, p.altitudeM)],
          total: total,
          color: AppColors.primaryDark,
        ),
      ),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard(
      {required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('over trip time',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        subtitle: Text(value,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
      );
}
