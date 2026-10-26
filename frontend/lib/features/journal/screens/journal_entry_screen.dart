import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/colors.dart';
import 'package:frontend/shared/widgets/glass_container.dart';
import 'package:frontend/state/journal_provider.dart';

class JournalEntryScreen extends ConsumerStatefulWidget {
  const JournalEntryScreen({super.key});

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final TextEditingController _journalController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalProvider);

    // Listen for completion hooks to automatically clean up the inputs
    ref.listen(journalProvider, (previous, next) {
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Script updated! Memory vectorized successfully.'),
          ),
        );
        _journalController.clear();
        ref.read(journalProvider.notifier).resetStatus();
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Write Your Script',
          style: TextStyle(
            color: LifeScriptColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "What did you work toward today? Mention any books, movies, habits, or bottlenecks you encountered.",
              style: TextStyle(color: LifeScriptColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GlassContainer(
                baseColor: LifeScriptColors.pastelLavender,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _journalController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: "Start typing today's reflection...",
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      color: LifeScriptColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                key: const ValueKey('error_msg'),
                child: Text(
                  state.error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (_journalController.text.trim().length >= 10) {
                        ref
                            .read(journalProvider.notifier)
                            .submitJournal(_journalController.text.trim());
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: LifeScriptColors.pastelMint,
                foregroundColor: LifeScriptColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          LifeScriptColors.textPrimary,
                        ),
                      ),
                    )
                  : const Text(
                      'Commit to Memory',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
