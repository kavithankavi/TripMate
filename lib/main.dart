import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Services.init();
  runApp(const TripMateApp());
}
