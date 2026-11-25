import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import '../widgets/format.dart';
import 'auth_flow.dart';
import 'live_trip_screen.dart';
import 'trip_detail_screen.dart';

/// Asks for a trip name (default "TripN"), starts recording, opens live view.
Future<void> startTripFlow(BuildContext context) async {
  final tracker = Services.tracker;
  if (tracker.isTracking) {
    _openLive(context);
    return;
  }
  final now = DateTime.now();
  final defaultName = await tracker.defaultTripName(now);
  if (!context.mounted) return;
  final controller = TextEditingController(text: defaultName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Start trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Trip name'),
          ),
          Text('Starts ${fmtDateTime(now)}'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().isEmpty
                  ? defaultName
                  : controller.text.trim()),
          child: const Text('Start'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || !context.mounted) return;
  try {
    await tracker.start(name);
    if (context.mounted) _openLive(context);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

void _openLive(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const LiveTripScreen()));

/// Confirms, stops the trip and shows its details.
Future<void> stopTripFlow(BuildContext context, {bool replace = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Stop trip?'),
      content: const Text('The trip will be saved to your history.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Stop'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final trip = await Services.tracker.stop();
  if (trip == null || !context.mounted) return;
  final route = MaterialPageRoute<void>(
      builder: (_) => TripDetailScreen(trips: [trip], initialIndex: 0));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}
