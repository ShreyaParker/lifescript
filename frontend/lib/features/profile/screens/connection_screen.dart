import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';

final connectionChecksProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  return Future.wait([
    for (final check in [
      ('API connection', '/health/live'),
      ('Data storage', '/health/ready'),
    ])
      (() async {
        try {
          await api.dio.get(check.$2);
          return '${check.$1}: connected';
        } catch (error) {
          return '${check.$1}: ${apiError(error)}';
        }
      })(),
  ]);
});

class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Connection status')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'If saving or loading is unavailable, check your connection here. AI processing can still be unavailable when data storage is connected.',
        ),
        const SizedBox(height: 20),
        ref
            .watch(connectionChecksProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(apiError(e)),
              data: (checks) => Column(
                children: [
                  for (final check in checks)
                    Card(child: ListTile(title: Text(check))),
                ],
              ),
            ),
        TextButton(
          onPressed: () => ref.invalidate(connectionChecksProvider),
          child: const Text('Check again'),
        ),
      ],
    ),
  );
}
