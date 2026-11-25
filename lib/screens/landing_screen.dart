import 'package:material_ui/material_ui.dart';

import '../services/services.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import 'phone_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _open(BuildContext context, bool register) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PhoneScreen(register: register)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const AppLogo(size: 104),
              const SizedBox(height: 20),
              Text('TripMate',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 8),
              const Text(
                'Track speed, location, altitude and time\nfor every drive.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => _open(context, false),
                child: const Text('Login'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _open(context, true),
                child: const Text('Register'),
              ),
              const SizedBox(height: 16),
              if (Services.auth.isDevMode)
                const Text('Demo mode: no SMS is sent, use code 123456',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
