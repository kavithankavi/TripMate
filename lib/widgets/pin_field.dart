import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Obscured 4 digit numeric input.
class PinField extends StatelessWidget {
  const PinField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        autofocus: autofocus,
        obscureText: true,
        obscuringCharacter: '●',
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 16),
        decoration: InputDecoration(labelText: label, counterText: ''),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: validator ??
            (v) => (v ?? '').length == 4 ? null : 'Enter 4 digits',
        onFieldSubmitted: onSubmitted,
      );
}
