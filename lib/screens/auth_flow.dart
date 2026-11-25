import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

/// Called once the phone number is verified (OTP or PIN).
Future<void> completeSignIn(
    BuildContext context, String phone, bool register) async {
  await Services.session.saveSession(phone);
  if (!context.mounted) return;
  final hasPin = await Services.session.hasPin(phone);
  if (!context.mounted) return;
  // After registration, offer to set a PIN (skippable).
  final Widget next = register && !hasPin
      ? const PinSetupScreen(firstTime: true)
      : const HomeScreen();
  Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => next), (_) => false);
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString())));
}
