import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/config.dart';

final authUserProvider = StreamProvider<String?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();
});

class ApiClient {
  final Dio dio;
  ApiClient({required String baseUrl, Dio? transport, String? expectedOwner})
    : dio =
          transport ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 45),
            ),
          ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null || session.user.id != expectedOwner) {
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Please sign in again.',
              ),
            );
            return;
          }
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          handler.next(options);
        },
      ),
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final owner = ref.watch(
    authUserProvider.select((state) => state.valueOrNull),
  );
  final client = ApiClient(baseUrl: AppConfig.apiUrl, expectedOwner: owner);
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});

String apiError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Your session expired. Please sign in again.';
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (status == 409) return 'This item changed. Refresh and review it again.';
    return 'Could not complete the request. Your draft is preserved; please retry.';
  }
  return 'Could not complete the operation. Please retry.';
}
