import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final user = session.user;
      final profileResponse = await Supabase.instance.client
          .from('users')
          .select('onboarding_complete')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        if (profileResponse != null &&
            profileResponse['onboarding_complete'] == true) {
          context.go('/dashboard');
        } else {
          context.go('/onboarding');
        }
      }
    } catch (e) {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: LifeScriptColors.pastelMint),
      ),
    );
  }
}
