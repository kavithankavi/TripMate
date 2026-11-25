import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Shows an alert with an OK button that closes itself after [duration]
/// if the user does not acknowledge it.
Future<void> showTimedAlert(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.battery_alert_rounded,
  Duration duration = const Duration(seconds: 10),
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TimedAlert(
        title: title, message: message, icon: icon, duration: duration),
  );
}

class _TimedAlert extends StatefulWidget {
  const _TimedAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.duration,
  });

  final String title, message;
  final IconData icon;
  final Duration duration;

  @override
  State<_TimedAlert> createState() => _TimedAlertState();
}

class _TimedAlertState extends State<_TimedAlert> {
  late int _left = widget.duration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        Navigator.of(context).pop();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: Icon(widget.icon, size: 36),
        title: Text(widget.title),
        content: Text(widget.message),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () {
              _timer?.cancel();
              Navigator.of(context).pop();
            },
            child: Text('OK ($_left)'),
          ),
        ],
      );
}
