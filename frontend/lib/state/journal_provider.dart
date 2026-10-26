import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/services/api_client.dart';

class JournalState {
  final bool isLoading, isSuccess;
  final String? error, coachingInsight, runId;
  const JournalState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.coachingInsight,
    this.runId,
  });
}

class JournalNotifier extends StateNotifier<JournalState> {
  final Dio _dio;
  String? _pendingContent, _pendingKey;
  JournalNotifier(this._dio) : super(const JournalState());
  Future<void> submitJournal(String text) async {
    if (state.isLoading) return;
    if (_pendingContent != text) {
      _pendingContent = text;
      _pendingKey =
          'journal-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    state = const JournalState(isLoading: true);
    try {
      final response = await _dio.post(
        '/journal/submit',
        data: {'content': text},
        options: Options(headers: {'Idempotency-Key': _pendingKey}),
      );
      if (!mounted) return;
      _pendingContent = null;
      state = JournalState(
        isSuccess: true,
        runId: response.data['run_id'],
        coachingInsight: response.data['coaching_insight'],
      );
    } catch (e) {
      if (mounted) state = JournalState(error: apiError(e));
    }
  }

  void resetStatus() => state = const JournalState();
}

final journalProvider = StateNotifierProvider<JournalNotifier, JournalState>(
  (ref) => JournalNotifier(ref.watch(apiClientProvider).dio),
);
