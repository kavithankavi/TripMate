import 'package:material_ui/material_ui.dart';

import '../services/session_store.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/pin_field.dart';
import '../widgets/snack.dart';
import 'home_screen.dart';

/// Creates the PIN on first launch ([firstTime]) or changes it from the menu.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, this.firstTime = false});
  final bool firstTime;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  bool get _changing => !widget.firstTime && Services.session.hasPin;

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = Services.session;
    if (_changing) {
      final r = await s.verifyPin(_current.text);
      if (!mounted) return;
      if (r != PinCheck.ok) {
        _current.clear();
        setState(() => _busy = false);
        showError(
            context,
            r == PinCheck.locked
                ? 'Too many wrong tries. Please wait and try again.'
                : 'Current PIN is incorrect.');
        return;
      }
    }
    await s.setPin(_pin.text);
    if (!mounted) return;
    if (widget.firstTime) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false);
    } else {
      showError(context, 'PIN changed.');
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.firstTime ? null : AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.firstTime) ...[
                const SizedBox(height: 24),
                const Center(child: AppLogo(size: 88)),
                const SizedBox(height: 16),
                Text('Welcome to TripMate',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 8),
                const Text(
                  'Create a 4-digit PIN. You will enter it each time you '
                  'open TripMate. No phone number or account is needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
                const SizedBox(height: 28),
              ],
              if (_changing) ...[
                PinField(
                    controller: _current,
                    label: 'Current PIN',
                    autofocus: true),
                const SizedBox(height: 16),
              ],
              PinField(
                  controller: _pin,
                  label: _changing ? 'New PIN' : 'PIN',
                  autofocus: !_changing),
              const SizedBox(height: 16),
              PinField(
                controller: _confirm,
                label: _changing ? 'Confirm new PIN' : 'Confirm PIN',
                validator: (v) => v != _pin.text ? 'PINs do not match' : null,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_changing ? 'Change PIN' : 'Save PIN')),
            ],
          ),
        ),
      ),
    );
  }
}
