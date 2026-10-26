import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/services/api_client.dart';

class AuditState {
  final bool patternDetected;
  final String coachingMessage;
  final Map<String, dynamic>? suggestedAdjustment;
  final bool isLoading;

  AuditState({
    required this.patternDetected,
    required this.coachingMessage,
    this.suggestedAdjustment,
    this.isLoading = false,
  });

  factory AuditState.initial() =>
      AuditState(patternDetected: false, coachingMessage: '');

  AuditState copyWith({
    bool? patternDetected,
    String? coachingMessage,
    Map<String, dynamic>? suggestedAdjustment,
    bool? isLoading,
  }) {
    return AuditState(
      patternDetected: patternDetected ?? this.patternDetected,
      coachingMessage: coachingMessage ?? this.coachingMessage,
      suggestedAdjustment: suggestedAdjustment ?? this.suggestedAdjustment,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuditNotifier extends StateNotifier<AuditState> {
  final Dio _dio;

  AuditNotifier(this._dio) : super(AuditState.initial());

  Future<void> checkWeeklyAudit() async {
    state = state.copyWith(isLoading: true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw 'Not authenticated';

      final response = await _dio.get(
        '/journal/audit', // Route updated to not need user UUID in path
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );

      if (response.data != null) {
        final data = response.data;
        state = AuditState(
          patternDetected: data['pattern_detected'] ?? false,
          coachingMessage: data['coaching_message'] ?? '',
          suggestedAdjustment: data['suggested_adjustment'],
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final auditProvider = StateNotifierProvider<AuditNotifier, AuditState>((ref) {
  return AuditNotifier(ref.watch(apiClientProvider).dio);
});
