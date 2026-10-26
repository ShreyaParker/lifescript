import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/core/theme/colors.dart';
import 'package:frontend/shared/widgets/glass_container.dart';

class InteractiveOnboardingScreen extends ConsumerStatefulWidget {
  const InteractiveOnboardingScreen({super.key});

  @override
  ConsumerState<InteractiveOnboardingScreen> createState() =>
      _InteractiveOnboardingScreenState();
}

class _InteractiveOnboardingScreenState
    extends ConsumerState<InteractiveOnboardingScreen> {
  int _currentStep = 0;

  String _selectedLandscape = '';
  String _selectedRhythm = '';
  String _selectedFootprint = '';
  String _selectedNorthStar = '';

  // Rosebud-Inspired Deep Psychological Diagnostic Questions
  final List<String> _prompts = [
    "What secretly saps your cognitive energy or stalls your momentum the most?",
    "How would you honestly describe your current operational daily rhythm?",
    "When you consume books, movies, or media, what is your mind sub-consciously seeking?",
    "What core identity shift are we writing the new script for right now?",
  ];

  final List<List<String>> _optionsMatrix = [
    // Step 1: Inner Landscape (Shadow/Blocks)
    [
      'The Imposter Loop (Fear of failing out loud)',
      'Perfectionist Paralysis (Staring at blank project screens)',
      'Dopamine Exhaustion (Infinite scrolling & distraction swaps)',
      'Monastic Burnout (Working hard but feeling isolated)',
    ],
    // Step 2: Subconscious Rhythms (Routines)
    [
      'Scattered Late-Night Bursts (High friction morning starts)',
      'Hyper-Focused Spurt Cycles (Intense weeks followed by crashes)',
      'Rigid but Exhausting Routines (Going through motions mechanically)',
      'Completely Fluid (Zero calendar anchoring, reacting to fire drills)',
    ],
    // Step 3: Intellectual Footprint (Media/Logs Context)
    [
      'High-Fidelity Skill Ingestion (Documentation, code repos, deep tech)',
      'Escapist Worldbuilding (Sci-fi, high-concept cinema, fantasy fiction)',
      'Philosophical Reflection (Self-exploration, human psychology books)',
      'Strategic Case Studies (Biographies, business mechanics, operational systems)',
    ],
    // Step 4: Core North Star (The Shift Target)
    [
      'Radical Career Trajectory Shift (Transitioning to AI/Core Engineering)',
      'Reclaiming Deep Creative Autonomy (Building personal passion engines)',
      'Restoring Mental Space & Vitality (Overcoming persistent cognitive fatigue)',
      'Unlocking Unshakeable Execution (Mastering bulletproof consistency)',
    ],
  ];

  Future<void> _commitPsychologicalProfile() async {
    try {
      final dio = ref.read(apiClientProvider).dio;

      await dio.post(
        '/onboarding/setup',
        data: {
          "inner_landscape": _selectedLandscape,
          "subconscious_rhythm": _selectedRhythm,
          "intellectual_footprint": _selectedFootprint,
          "core_north_star": _selectedNorthStar,
        },
      );

      if (mounted) context.go('/dashboard');
    } catch (e) {
      final errorMsg = apiError(e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: $errorMsg')));
      }
    }
  }

  void _processDiagnosticChoice(String choice) {
    setState(() {
      switch (_currentStep) {
        case 0:
          _selectedLandscape = choice;
          _currentStep++;
          break;
        case 1:
          _selectedRhythm = choice;
          _currentStep++;
          break;
        case 2:
          _selectedFootprint = choice;
          _currentStep++;
          break;
        case 3:
          _selectedNorthStar = choice;
          _commitPsychologicalProfile();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> pastelTints = [
      LifeScriptColors.pastelLavender,
      LifeScriptColors.pastelMint,
      LifeScriptColors.pastelPeach,
      LifeScriptColors.pastelLavender,
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // High-level Progress Metrology
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diagnostic Vector ${_currentStep + 1} of 4',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: LifeScriptColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 4,
                        backgroundColor: Colors.grey[200],
                        color: pastelTints[_currentStep],
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Deep Prompt Text
              Text(
                _prompts[_currentStep],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: LifeScriptColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Choices Builder
              Expanded(
                child: ListView.builder(
                  itemCount: _optionsMatrix[_currentStep].length,
                  itemBuilder: (context, index) {
                    final optionText = _optionsMatrix[_currentStep][index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _processDiagnosticChoice(optionText),
                        child: GlassContainer(
                          baseColor: pastelTints[_currentStep].withValues(
                            alpha: 0.15,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    optionText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: LifeScriptColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.blur_on_rounded,
                                  size: 18,
                                  color: pastelTints[_currentStep],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
