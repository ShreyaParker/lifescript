import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/services/api_client.dart';

class ProfileState {
  final bool isLoading;
  final Map<String, dynamic> profile;
  final List<dynamic> media;
  final String? error;
  const ProfileState({
    this.isLoading = false,
    this.profile = const {},
    this.media = const [],
    this.error,
  });
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Dio _dio;
  ProfileNotifier(this._dio) : super(const ProfileState());
  Future<void> fetchProfile() async {
    if (!mounted) return;
    state = ProfileState(
      isLoading: true,
      profile: state.profile,
      media: state.media,
    );
    try {
      final response = await _dio.get('/profile/');
      if (!mounted) return;
      state = ProfileState(
        profile: Map<String, dynamic>.from(response.data['profile'] ?? {}),
        media: response.data['media'] ?? [],
      );
    } catch (e) {
      if (mounted) {
        state = ProfileState(
          profile: state.profile,
          media: state.media,
          error: apiError(e),
        );
      }
    }
  }

  Future<void> addMacroGoal(String goal) async {
    try {
      final goals = <String>{
        ...List<String>.from(state.profile['macro_goals'] ?? []),
        goal.trim(),
      }.toList();
      await _dio.post('/profile/goals', data: {'goals': goals});
      if (mounted) await fetchProfile();
    } catch (e) {
      if (mounted) {
        state = ProfileState(
          profile: state.profile,
          media: state.media,
          error: apiError(e),
        );
      }
    }
  }

  Future<void> logMedia(String type, String title) async {
    try {
      await _dio.post(
        '/profile/media',
        data: {
          'media_type': type,
          'title': title.trim(),
          'current_status': 'completed',
        },
      );
      if (mounted) await fetchProfile();
    } catch (e) {
      if (mounted) {
        state = ProfileState(
          profile: state.profile,
          media: state.media,
          error: apiError(e),
        );
      }
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((
  ref,
) {
  final notifier = ProfileNotifier(ref.watch(apiClientProvider).dio);
  Future.microtask(notifier.fetchProfile);
  return notifier;
});
