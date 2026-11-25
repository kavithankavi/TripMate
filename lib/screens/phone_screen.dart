import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../services/services.dart';
import '../theme.dart';
import 'auth_flow.dart';
import 'otp_screen.dart';
import 'pin_login_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.register});
  final bool register;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _cc = TextEditingController(text: AppConfig.defaultCountryCode);
  final _number = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  String get _phone =>
      '+${_cc.text.replaceAll(RegExp(r'\D'), '')}${_number.text.trim()}';

  Future<void> _continue() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final phone = _phone;

    if (!widget.register && await Services.session.hasPin(phone)) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PinLoginScreen(phone: phone)));
      return;
    }
    await sendOtpAndContinue(phone);
  }

  Future<void> sendOtpAndContinue(String phone) async {
    setState(() => _busy = true);
    try {
      final result = await Services.auth.sendOtp(phone);
      if (!mounted) return;
      if (result == OtpSendResult.autoVerified) {
        await completeSignIn(context, phone, widget.register);
      } else {
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                OtpScreen(phone: phone, register: widget.register)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cc.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.register ? 'Register' : 'Login';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.register
                    ? 'Enter your mobile number. We will send a one-time code to verify it.'
                    : 'Enter your registered mobile number.',
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: TextFormField(
                      controller: _cc,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Code'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: (v) =>
                          (v ?? '').replaceAll(RegExp(r'\D'), '').isEmpty
                              ? 'Code'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _number,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      decoration:
                          const InputDecoration(labelText: 'Mobile number'),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(14),
                      ],
                      validator: (v) => (v ?? '').length < 6
                          ? 'Enter a valid mobile number'
                          : null,
                      onFieldSubmitted: (_) => _continue(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : _continue,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
