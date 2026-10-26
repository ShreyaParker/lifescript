import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/api_client.dart';

class TaskItem {
  final String id, title, description;
  final String? objectiveId;
  final int xpValue;
  final bool isCompleted;
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.xpValue,
    this.objectiveId,
    this.isCompleted = false,
  });
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('Task ID is required');
    }
    return TaskItem(
      id: id,
      objectiveId: json['objective_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      xpValue: json['xp_value'] as int? ?? 20,
      isCompleted: json['status'] == 'completed',
    );
  }
  TaskItem withCompleted(bool value) => TaskItem(
    id: id,
    objectiveId: objectiveId,
    title: title,
    description: description,
    xpValue: xpValue,
    isCompleted: value,
  );
}

final taskErrorProvider = StateProvider<String?>((ref) => null);
final taskLoadingProvider = StateProvider<bool>((ref) => false);

class TaskNotifier extends StateNotifier<List<TaskItem>> {
  final Dio _dio;
  final Ref _ref;
  final Set<String> _pending = {};
  int _requestVersion = 0;
  TaskNotifier(this._dio, this._ref) : super([]);
  Future<void> fetchDailyTasks() => _fetch('/tasks');
  Future<void> fetchArchivedTasks(DateTime date) =>
      _fetch('/tasks/archive?date=${DateFormat('yyyy-MM-dd').format(date)}');
  Future<void> _fetch(String path) async {
    if (!mounted) return;
    final version = ++_requestVersion;
    _ref.read(taskLoadingProvider.notifier).state = true;
    try {
      final response = await _dio.get(path);
      if (!mounted || version != _requestVersion) return;
      state = (response.data as List)
          .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      _ref.read(taskErrorProvider.notifier).state = null;
    } catch (e) {
      if (mounted) _ref.read(taskErrorProvider.notifier).state = apiError(e);
    } finally {
      if (mounted) _ref.read(taskLoadingProvider.notifier).state = false;
    }
  }

  Future<void> toggleTaskStatus(int index) async {
    if (index < 0 || index >= state.length) return;
    final task = state[index];
    if (!_pending.add(task.id)) return;
    _requestVersion++;
    try {
      await _dio.patch(
        '/tasks/${task.id}/toggle',
        data: {'is_completed': !task.isCompleted},
      );
      if (!mounted) return;
      state = [
        for (final item in state)
          item.id == task.id ? item.withCompleted(!task.isCompleted) : item,
      ];
      _ref.read(taskErrorProvider.notifier).state = null;
    } catch (e) {
      if (mounted) _ref.read(taskErrorProvider.notifier).state = apiError(e);
    } finally {
      _pending.remove(task.id);
    }
  }

  void populateGeneratedTasks(List<dynamic> tasks) {
    state = tasks
        .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, List<TaskItem>>((ref) {
  final notifier = TaskNotifier(ref.watch(apiClientProvider).dio, ref);
  Future.microtask(notifier.fetchDailyTasks);
  return notifier;
});
