import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/state/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _media = TextEditingController();
  String _type = 'book';
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
  }

  @override
  void dispose() {
    _media.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.isLoading) const LinearProgressIndicator(),
          if (state.error != null)
            Text(state.error!, style: const TextStyle(color: Colors.red)),
          const Text(
            'Your starting direction',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (state.profile['primary_north_star'] != null)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(state.profile['primary_north_star'] as String),
            ),
          const Text('Manage goals and projects from the Goals tab.'),
          const SizedBox(height: 24),
          const Text(
            'Log media or an activity',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          DropdownButton<String>(
            value: _type,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'book', child: Text('Book')),
              DropdownMenuItem(value: 'movie', child: Text('Movie')),
              DropdownMenuItem(value: 'hobby', child: Text('Activity')),
            ],
            onChanged: (value) => setState(() => _type = value!),
          ),
          TextField(
            controller: _media,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          FilledButton(
            onPressed: state.isLoading
                ? null
                : () async {
                    if (_media.text.trim().isNotEmpty) {
                      await ref
                          .read(profileProvider.notifier)
                          .logMedia(_type, _media.text);
                      if (mounted && ref.read(profileProvider).error == null) {
                        _media.clear();
                      }
                    }
                  },
            child: const Text('Log item'),
          ),
        ],
      ),
    );
  }
}
