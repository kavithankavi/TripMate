import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TripMate is portrait only (also set in AndroidManifest.xml and Info.plist).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Services.init();
  runApp(const TripMateApp());
}
