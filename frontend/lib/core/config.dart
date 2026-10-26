import 'package:flutter/foundation.dart';

class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bimjjeyprywffqjezyhy.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_9GP17lEhAMEBrmKA-livMg_GWdItaMU',
  );
  static String get authRedirect =>
      const String.fromEnvironment('AUTH_REDIRECT_URL').isNotEmpty
      ? const String.fromEnvironment('AUTH_REDIRECT_URL')
      : kIsWeb
      ? '${Uri.base.origin}/'
      : 'com.lifescript.frontend://login-callback/';
}
