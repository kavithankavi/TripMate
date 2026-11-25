import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import '../theme.dart';
import '../widgets/pin_field.dart';
import 'auth_flow.dart';
import 'otp_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key, required this.phone});
  final String phone;

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pin = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = Services.session;
    final ok = await s.verifyPin(widget.phone, _pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await completeSignIn(context, widget.phone, false);
      return;
    }
    _pin.clear();
    if (!await s.hasPin(widget.phone)) {
      if (!mounted) return;
      showError(context, 'Too many wrong attempts. Please log in with OTP.');
      await _useOtp();
    } else {
      final left = await s.remainingAttempts(widget.phone);
      if (mounted) showError(context, 'Wrong PIN. $left attempts left.');
    }
  }

  Future<void> _useOtp() async {
    setState(() => _busy = true);
    try {
      await Services.auth.sendOtp(widget.phone);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => OtpScreen(phone: widget.phone, register: false)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Enter the 4-digit PIN for ${widget.phone}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 15)),
              const SizedBox(height: 24),
              PinField(
                  controller: _pin,
                  label: 'PIN',
                  autofocus: true,
                  onSubmitted: (_) => _login()),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _busy ? null : _login, child: const Text('Login')),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _useOtp,
                child: const Text('Forgot PIN? Log in with OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
