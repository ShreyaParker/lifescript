import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/state/profile_provider.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your media journal',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Refresh media',
              onPressed: () =>
                  ref.read(profileProvider.notifier).fetchProfile(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Books, movies and activities you have logged. Add items from your profile.',
        ),
        if (state.isLoading) const LinearProgressIndicator(),
        if (state.error != null)
          Text(state.error!, style: const TextStyle(color: Colors.red)),
        if (state.media.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No media logged yet.'),
          ),
        ...state.media.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(
                item['media_type'] == 'book'
                    ? Icons.book_outlined
                    : Icons.movie_outlined,
              ),
              title: Text(item['title'] as String),
              subtitle: Text(item['current_status'] as String? ?? ''),
            ),
          ),
        ),
      ],
    );
  }
}
