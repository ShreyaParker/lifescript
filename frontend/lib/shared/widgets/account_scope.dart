import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';

/// Recreate all protected screen state when the authenticated owner changes.
class AccountScope extends ConsumerWidget {
  final Widget child;
  const AccountScope({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authUserProvider).valueOrNull;
    if (owner == null) return const Center(child: CircularProgressIndicator());
    return KeyedSubtree(key: ValueKey(owner), child: child);
  }
}
