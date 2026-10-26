import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/widgets/design.dart';

class JournalComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy, recording, audioAvailable;
  final VoidCallback onAttach, onRecord, onSubmit;
  final Widget attachments;
  const JournalComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.recording,
    required this.audioAvailable,
    required this.onAttach,
    required this.onRecord,
    required this.onSubmit,
    required this.attachments,
  });
  @override
  Widget build(BuildContext context) => Reveal(
    child: LiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.lavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppPalette.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Eyebrow('Your journal')),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Private draft',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF40745F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: controller,
            minLines: MediaQuery.sizeOf(context).width < 600 ? 4 : 6,
            maxLines: 12,
            maxLength: 20000,
            enabled: !busy,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.9),
            decoration: const InputDecoration(
              hintText:
                  'What is on your mind?\nA thought, a small win, or something you want to work toward...',
              filled: false,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              counterStyle: TextStyle(fontSize: 10, color: AppPalette.muted),
            ),
          ),
          attachments,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: busy || recording ? null : onAttach,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Attach'),
              ),
              Tooltip(
                message: audioAvailable
                    ? 'Record a voice note'
                    : 'Voice recording is not enabled on this server',
                child: OutlinedButton.icon(
                  onPressed: busy || !audioAvailable ? null : onRecord,
                  icon: Icon(
                    recording
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    size: 18,
                  ),
                  label: Text(recording ? 'Stop recording' : 'Voice note'),
                ),
              ),
              FilledButton.icon(
                onPressed: busy || recording ? null : onSubmit,
                icon: busy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  busy ? 'Saving your entry...' : 'Save and suggest tasks',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: AppPalette.muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'You choose which suggestions become tasks.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
