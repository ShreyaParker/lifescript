import 'dart:async';
import 'package:frontend/features/profile/screens/connection_screen.dart';
import 'package:frontend/features/resonance/screens/resonance_screen.dart';
import 'package:frontend/features/gallery/screens/gallery_screen.dart';
import 'package:frontend/features/automation/screens/automation_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/features/auth/screens/splash_screen.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/onboarding/screens/interactive_onboarding_screen.dart';
import 'package:frontend/features/journal/screens/journal_entry_screen.dart';
import 'package:frontend/features/home/screens/main_navigation_shell.dart';
import 'package:frontend/features/profile/screens/profile_screen.dart';
import 'package:frontend/features/memory/screens/memory_screen.dart';
import 'package:frontend/shared/widgets/account_scope.dart';

class AuthRefresh extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  AuthRefresh() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthRefresh(),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';

    if (session == null && !isLoggingIn) {
      return '/login';
    }
    if (session != null && isLoggingIn) return '/';

    // Once user is logged in, they can be redirected either to /dashboard or /onboarding depending on their Supabase user profile.
    // The login screen itself will handle routing away from /login after the auth flow is completed.
    // Handled by SplashScreen directly
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/connection',
      builder: (context, state) =>
          const AccountScope(child: ConnectionScreen()),
    ),
    GoRoute(
      path: '/review',
      builder: (context, state) => const AccountScope(
        child: _ToolPage(title: 'Weekly review', child: ResonanceScreen()),
      ),
    ),
    GoRoute(
      path: '/attachments',
      builder: (context, state) => const AccountScope(
        child: _ToolPage(title: 'Saved media', child: GalleryScreen()),
      ),
    ),
    GoRoute(
      path: '/automation',
      builder: (context, state) => const AccountScope(
        child: _ToolPage(
          title: 'Automation and calendar',
          child: AutomationScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/memory',
      builder: (context, state) => const AccountScope(child: MemoryScreen()),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const SplashScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) {
        return const AccountScope(child: InteractiveOnboardingScreen());
      },
    ),
    GoRoute(
      path: '/journal',
      builder: (BuildContext context, GoRouterState state) {
        return const AccountScope(child: JournalEntryScreen());
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return const AccountScope(child: MainNavigationShell());
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (BuildContext context, GoRouterState state) {
        return const AccountScope(child: ProfileScreen());
      },
    ),
  ],
);

class _ToolPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _ToolPage({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: child),
  );
}
