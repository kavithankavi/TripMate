import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/trip_detail_screen.dart';
import 'services/services.dart';
import 'services/trip_tracker.dart';
import 'theme.dart';
import 'widgets/timed_alert.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class TripMateApp extends StatefulWidget {
  const TripMateApp({super.key});

  @override
  State<TripMateApp> createState() => _TripMateAppState();
}

class _TripMateAppState extends State<TripMateApp> {
  StreamSubscription<TrackerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    // Tracker events can arrive on any screen, so they are shown from here.
    _sub = Services.tracker.events.listen(_onTrackerEvent);
  }

  void _onTrackerEvent(TrackerEvent e) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    switch (e) {
      case LowBatteryEvent(:final level):
        showTimedAlert(
          ctx,
          title: 'Battery low ($level%)',
          message: 'Please charge your phone. To save power, TripMate now '
              'records your location every 30 seconds.',
          duration: AppConfig.lowBatteryAlertDuration,
        );
      case AutoStoppedEvent(:final trip):
        navigatorKey.currentState?.push(MaterialPageRoute<void>(
          builder: (_) => TripDetailScreen(
            trips: [trip],
            initialIndex: 0,
            notice: 'This trip was stopped automatically after 2 hours '
                'without movement.',
          ),
        ));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripMate',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: Services.session.isLoggedIn
          ? const HomeScreen()
          : const LandingScreen(),
    );
  }
}
