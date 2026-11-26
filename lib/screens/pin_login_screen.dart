import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/session_store.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/pin_field.dart';
import '../widgets/snack.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

/// Asks for the 4 digit PIN each time the app opens (and after Lock).
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  Duration _locked = Duration.zero;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _refreshLock();
  }

  Future<void> _refreshLock() async {
    final left = await Services.session.lockedFor();
    if (!mounted) return;
    setState(() => _locked = left);
    _lockTimer?.cancel();
    if (left > Duration.zero) {
      _lockTimer = Timer(left, _refreshLock);
    }
  }

  Future<void> _login() async {
    if (_busy || _pin.text.length != 4) return;
    setState(() => _busy = true);
    final r = await Services.session.verifyPin(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == PinCheck.ok) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false);
      return;
    }
    _pin.clear();
    if (r == PinCheck.locked) {
      showError(context, 'Too many wrong tries. Please wait 30 seconds.');
      await _refreshLock();
    } else {
      final left = await Services.session.remainingAttempts();
      if (mounted) showError(context, 'Wrong PIN. $left tries left.');
    }
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
            'Without the PIN, TripMate can only start fresh. This erases your '
            'saved trips on this phone, then you create a new PIN.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(96, 44),
                backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase and reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (Services.tracker.isTracking) await Services.tracker.stop();
    await Services.db.deleteAllTrips();
    await Services.session.removePin();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => const PinSetupScreen(firstTime: true)),
        (_) => false);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked > Duration.zero;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            const Center(child: AppLogo(size: 96)),
            const SizedBox(height: 16),
            Text('TripMate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            const Text('Enter your 4-digit PIN',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15)),
            const SizedBox(height: 28),
            PinField(
              controller: _pin,
              label: 'PIN',
              autofocus: true,
              enabled: !locked,
              onChanged: (v) {
                if (v.length == 4) _login();
              },
              onSubmitted: (_) => _login(),
            ),
            if (locked) ...[
              const SizedBox(height: 8),
              const Text('Too many wrong tries. Try again in a moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
                onPressed: _busy || locked ? null : _login,
                child: const Text('Unlock')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : _forgot,
              child: const Text('Forgot PIN?'),
            ),
          ],
        ),
      ),
    );
  }
}
