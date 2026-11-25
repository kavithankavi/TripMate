import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../services/services.dart';
import '../theme.dart';
import 'auth_flow.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, required this.register});
  final String phone;
  final bool register;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  int _resendIn = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendIn = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      setState(() => _resendIn--);
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    setState(() => _busy = true);
    try {
      await Services.auth.verifyOtp(_code.text);
      if (mounted) await completeSignIn(context, widget.phone, widget.register);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await Services.auth.sendOtp(widget.phone);
      if (!mounted) return;
      _startResendTimer();
      showError(context, 'A new code was sent.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify number')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Enter the 6-digit code sent to ${widget.phone}',
                style: const TextStyle(color: AppColors.muted, fontSize: 15)),
            if (Services.auth.isDevMode) ...[
              const SizedBox(height: 8),
              const Text('Demo mode: use ${AppConfig.mockOtpCode}',
                  style: TextStyle(color: AppColors.primary)),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: const TextStyle(fontSize: 28, letterSpacing: 12),
              decoration: const InputDecoration(counterText: ''),
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Verify'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _resendIn > 0 ? null : _resend,
              child: Text(
                  _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
