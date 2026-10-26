import 'package:flutter/material.dart';
import 'package:frontend/core/theme/colors.dart';
import 'package:frontend/shared/widgets/glass_container.dart';
import 'package:frontend/state/audit_provider.dart';

class ScriptCorrectionAlert extends StatelessWidget {
  final AuditState audit;

  const ScriptCorrectionAlert({super.key, required this.audit});

  @override
  Widget build(BuildContext context) {
    if (!audit.patternDetected) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GlassContainer(
        baseColor: LifeScriptColors.pastelLavender,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('✨', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Script Optimization Detected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: LifeScriptColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                audit.coachingMessage,
                style: const TextStyle(
                  color: LifeScriptColors.textPrimary,
                  height: 1.4,
                ),
              ),
              if (audit.suggestedAdjustment != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: LifeScriptColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${audit.suggestedAdjustment!['action']}: ${audit.suggestedAdjustment!['detail']}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: LifeScriptColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
