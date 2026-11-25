import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import '../theme.dart';
import '../widgets/format.dart';
import 'history_screen.dart';
import 'landing_screen.dart';
import 'pin_setup_screen.dart';
import 'trip_actions.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final tracking = Services.tracker.isTracking;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(tracking
            ? 'Your current trip will be stopped and saved.'
            : 'You will need to log in again with OTP or PIN.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (tracking) await Services.tracker.stop();
    await Services.auth.signOut();
    await Services.session.clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tracker = Services.tracker;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TripMate'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              if (v == 'pin') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const PinSetupScreen()));
              } else if (v == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pin', child: Text('Set / change PIN')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: tracker,
          builder: (context, _) {
            final tracking = tracker.isTracking;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Signed in as ${Services.session.phone ?? ''}',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: tracking
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Icon(
                          tracking
                              ? Icons.directions_car_rounded
                              : Icons.local_parking_rounded,
                          color: tracking
                              ? AppColors.accent
                              : AppColors.primary),
                    ),
                    title: Text(tracking
                        ? tracker.trip!.name
                        : 'No trip in progress'),
                    subtitle: Text(tracking
                        ? 'Recording · ${fmtDuration(tracker.elapsed)}'
                        : 'Tap Start trip when you set off.'),
                    onTap: tracking ? () => startTripFlow(context) : null,
                  ),
                ),
                const SizedBox(height: 28),
                _BigButton(
                  icon: Icons.play_arrow_rounded,
                  label: tracking ? 'Open live trip' : 'Start trip',
                  color: AppColors.primary,
                  onTap: () => startTripFlow(context),
                ),
                const SizedBox(height: 14),
                _BigButton(
                  icon: Icons.stop_rounded,
                  label: 'Stop trip',
                  color: AppColors.danger,
                  onTap: tracking ? () => stopTripFlow(context) : null,
                ),
                const SizedBox(height: 14),
                _BigButton(
                  icon: Icons.history_rounded,
                  label: 'Trip history',
                  color: AppColors.primaryDark,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const HistoryScreen())),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 68,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: const Color(0xFFDDE4E3),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 28),
          label: Text(label, style: const TextStyle(fontSize: 18)),
        ),
      );
}
