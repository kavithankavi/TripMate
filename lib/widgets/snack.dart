import 'package:material_ui/material_ui.dart';

/// Shows a short message at the bottom of the screen.
void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString())));
}
