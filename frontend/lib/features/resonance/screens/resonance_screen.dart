import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';

final progressProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final response = await ref.watch(apiClientProvider).dio.get('/journal/audit');
  return Map<String, dynamic>.from(response.data);
});

class ResonanceScreen extends ConsumerWidget {
  const ResonanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your weekly review',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Refresh review',
              onPressed: () => ref.invalidate(progressProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Based on saved reflections and the current status of tasks created in the last seven days.',
        ),
        const SizedBox(height: 20),
        progress.when(
          data: (data) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(data['coaching_message'] as String),
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(apiError(e)),
        ),
      ],
    );
  }
}
