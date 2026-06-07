import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/device_service.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/onboarding/policy_screen.dart';
import '../../features/onboarding/tutorial_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final needsOnboarding = !DeviceService.hasCompletedOnboarding;

  return GoRouter(
    initialLocation: needsOnboarding ? '/policy' : '/home',
    routes: [
      GoRoute(
        path: '/policy',
        builder: (_, __) => const PolicyScreen(),
      ),
      GoRoute(
        path: '/tutorial',
        builder: (_, __) => const TutorialScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
