import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/route_map.dart';
import '../widgets/speedometer.dart';
import 'trip_actions.dart';

class LiveTripScreen extends StatelessWidget {
  const LiveTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = Services.tracker;
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final trip = tracker.trip;
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This trip has ended.')),
          );
        }
        final p = tracker.lastPoint;
        final hours = tracker.elapsed.inMilliseconds / 3600000;
        final avg = hours > 0 ? trip.distanceM / 1000 / hours : 0.0;
        final lowBattery = tracker.interval.inSeconds > 10;
        return Scaffold(
          appBar: AppBar(title: Text(trip.name)),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Chip(
                          icon: Icons.timer_outlined,
                          text: fmtDuration(tracker.elapsed)),
                      const SizedBox(width: 8),
                      _Chip(
                        icon: lowBattery
                            ? Icons.battery_alert_rounded
                            : Icons.gps_fixed_rounded,
                        text: 'Every ${tracker.interval.inSeconds}s',
                        color: lowBattery ? AppColors.accent : null,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                        child: Speedometer(speedKmh: p?.speedKmh ?? 0)),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _Stat('Latitude', fmtCoord(p?.lat)),
                      _Stat('Longitude', fmtCoord(p?.lng)),
                      _Stat('Altitude', fmtAlt(p?.altitudeM)),
                      _Stat('Distance', fmtKm(trip.distanceM)),
                      _Stat('Max speed', fmtSpeed(trip.maxSpeedKmh)),
                      _Stat('Avg speed', fmtSpeed(avg)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Map square in the bottom right corner.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Recording continues when the screen is off '
                              'or you switch apps.',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.danger),
                              onPressed: () =>
                                  stopTripFlow(context, replace: true),
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Stop trip'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox.square(
                          dimension: 150,
                          child: RouteMap(route: tracker.route),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color ?? AppColors.primary),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color ?? AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.text)),
            ),
          ],
        ),
      );
}
