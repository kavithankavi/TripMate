import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import '../theme.dart';
import '../widgets/pin_field.dart';
import 'auth_flow.dart';
import 'home_screen.dart';

/// Set a PIN after registration ([firstTime]) or set/change it from the menu.
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
  bool _hasPin = false;
  bool _loading = true;

  String get _phone => Services.session.phone!;

  @override
  void initState() {
    super.initState();
    Services.session.hasPin(_phone).then((v) {
      if (!mounted) return;
      setState(() {
        _hasPin = v;
        _loading = false;
      });
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = Services.session;
    if (_hasPin && !await s.verifyPin(_phone, _current.text)) {
      if (!mounted) return;
      _current.clear();
      if (!await s.hasPin(_phone)) {
        if (!mounted) return;
        setState(() => _hasPin = false);
        showError(context, 'Too many wrong attempts. Please set a new PIN.');
      } else {
        if (mounted) showError(context, 'Current PIN is incorrect.');
      }
      return;
    }
    await s.setPin(_phone, _pin.text);
    if (!mounted) return;
    showError(context, _hasPin ? 'PIN changed.' : 'PIN set.');
    _goOn();
  }

  void _goOn() {
    if (widget.firstTime) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false);
    } else {
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
    final title = _hasPin ? 'Change PIN' : 'Set login PIN';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: !widget.firstTime,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Use a 4-digit PIN to log in quickly on this phone '
                      'without waiting for an OTP.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    if (_hasPin) ...[
                      PinField(
                          controller: _current,
                          label: 'Current PIN',
                          autofocus: true),
                      const SizedBox(height: 16),
                    ],
                    PinField(
                        controller: _pin,
                        label: 'New PIN',
                        autofocus: !_hasPin),
                    const SizedBox(height: 16),
                    PinField(
                      controller: _confirm,
                      label: 'Confirm new PIN',
                      validator: (v) =>
                          v != _pin.text ? 'PINs do not match' : null,
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                        onPressed: _save, child: Text(_hasPin ? 'Change PIN' : 'Save PIN')),
                    if (widget.firstTime) ...[
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _goOn, child: const Text('Skip for now')),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
