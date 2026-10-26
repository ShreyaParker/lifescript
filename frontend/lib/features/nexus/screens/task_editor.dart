import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/state/objectives_provider.dart';
import 'package:frontend/state/task_provider.dart';

class TaskEditor extends ConsumerStatefulWidget {
  final TaskItem task;
  const TaskEditor({super.key, required this.task});
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _description = TextEditingController(
    text: widget.task.description,
  );
  late String? _objective = widget.task.objectiveId;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final objectives = ref.watch(objectivesProvider);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Edit task'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 255,
                  decoration: const InputDecoration(labelText: 'Task'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  enabled: !_busy,
                  maxLength: 4000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Details'),
                ),
                const SizedBox(height: 12),
                objectives.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Column(
                    children: [
                      Text(apiError(e)),
                      TextButton(
                        onPressed: () => ref.invalidate(objectivesProvider),
                        child: const Text('Reload goals'),
                      ),
                    ],
                  ),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: items.any((i) => i['id'] == _objective)
                        ? _objective
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Goal or project',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No link'),
                      ),
                      for (final item in items)
                        DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(
                            item['title'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _objective = value),
                  ),
                ),
                if (_error != null) Text(_error!),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    if (_title.text.trim().isEmpty) {
                      setState(() => _error = 'Add a task title.');
                      return;
                    }
                    setState(() {
                      _busy = true;
                      _error = null;
                    });
                    try {
                      await ref
                          .read(apiClientProvider)
                          .dio
                          .patch(
                            '/tasks/${widget.task.id}',
                            data: {
                              'title': _title.text.trim(),
                              'description': _description.text.trim(),
                              'objective_id': _objective,
                            },
                          );
                      await ref.read(taskProvider.notifier).fetchDailyTasks();
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) setState(() => _error = apiError(e));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
