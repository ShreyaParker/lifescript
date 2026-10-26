import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/config.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:frontend/core/theme/colors.dart';
import 'package:frontend/shared/widgets/glass_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: LifeScriptColors.pastelMint.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: LifeScriptColors.pastelPeach.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: GlassContainer(
                  baseColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'lifescript.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                            color: LifeScriptColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Engineer your reality.',
                          style: TextStyle(
                            fontSize: 14,
                            color: LifeScriptColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 48),

                        SupaSocialsAuth(
                          socialProviders: const [OAuthProvider.google],
                          colored: true,
                          redirectUrl: AppConfig.authRedirect,
                          onSuccess: (Session response) async {
                            final user = response.user;
                            final profileResponse = await Supabase
                                .instance
                                .client
                                .from('users')
                                .select('onboarding_complete')
                                .eq('id', user.id)
                                .maybeSingle();

                            if (!context.mounted) return;

                            if (profileResponse != null &&
                                profileResponse['onboarding_complete'] ==
                                    true) {
                              context.go('/dashboard');
                            } else {
                              context.go('/onboarding');
                            }
                          },
                          onError: (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Auth failed: $error')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
