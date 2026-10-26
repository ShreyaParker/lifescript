import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signOutAndClearLocalData() async {
  await Supabase.instance.client.auth.signOut();
  for (final name in ['user_profile', 'cached_journals', 'cached_tasks']) {
    if (Hive.isBoxOpen(name)) await Hive.box(name).clear();
  }
}
