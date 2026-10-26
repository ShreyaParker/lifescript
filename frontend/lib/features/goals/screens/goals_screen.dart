import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/widgets/design.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/state/objectives_provider.dart';
import 'package:frontend/state/task_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(objectivesProvider);
    final tasks = ref.watch(taskProvider);
    final taskError = ref.watch(taskErrorProvider);
    final taskLoading = ref.watch(taskLoadingProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(objectivesProvider);
        await ref.read(taskProvider.notifier).fetchDailyTasks();
        await ref.read(objectivesProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding(context),
        children: [
          const PageIntro(
            eyebrow: 'Direction, not pressure',
            title: 'Big dreams. Small steps.',
            description:
                'Make room for what matters. One goal, one project, one next step at a time.',
          ),
          goals.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => LiftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(apiError(e)),
                  TextButton(
                    onPressed: () => ref.invalidate(objectivesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            const _CreateObjective(kind: 'goal', goals: []),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('New goal'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _CreateObjective(
                          kind: 'project',
                          goals: items
                              .where(
                                (i) =>
                                    i['kind'] == 'goal' &&
                                    i['status'] == 'active',
                              )
                              .toList(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 19,
                      ),
                      label: const Text('New project'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your goals & projects',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.lavender,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const LiftCard(
                    child: EmptyState(
                      icon: Icons.flag_outlined,
                      title: 'What would you love to work toward?',
                      description:
                          'Start with one goal that feels meaningful. You can break it into projects as you go.',
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 18,
                    runSpacing: 4,
                    children: [
                      for (final item in items)
                        SizedBox(
                          width: constraints.maxWidth >= 740
                              ? (constraints.maxWidth - 18) / 2
                              : constraints.maxWidth,
                          child: Builder(
                            builder: (context) {
                              final ids = {
                                item['id'],
                                if (item['kind'] == 'goal')
                                  ...items
                                      .where(
                                        (i) => i['parent_id'] == item['id'],
                                      )
                                      .map((i) => i['id']),
                              };
                              final linked = tasks
                                  .where((t) => ids.contains(t.objectiveId))
                                  .toList();
                              final completed = linked
                                  .where((t) => t.isCompleted)
                                  .length;
                              final parent = items
                                  .where((i) => i['id'] == item['parent_id'])
                                  .firstOrNull;
                              final done = item['status'] == 'completed';
                              final isGoal = item['kind'] == 'goal';
                              return Reveal(
                                child: LiftCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isGoal
                                                  ? AppPalette.lavender
                                                  : AppPalette.mint,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              isGoal
                                                  ? Icons.flag_outlined
                                                  : Icons.folder_open_outlined,
                                              color: isGoal
                                                  ? AppPalette.primary
                                                  : const Color(0xFF568A76),
                                              size: 24,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: done
                                                  ? AppPalette.mint
                                                  : const Color(0xFFFFF4E8),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              done
                                                  ? 'Completed'
                                                  : 'In progress',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: done
                                                    ? const Color(0xFF40745F)
                                                    : const Color(0xFF936731),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 22),
                                      Eyebrow(
                                        isGoal ? 'Personal goal' : 'Project',
                                        color: AppPalette.muted,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['title'] as String,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      if (parent != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            'Part of ${parent['title']}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      const SizedBox(height: 24),
                                      if (taskError != null)
                                        Text(taskError)
                                      else if (taskLoading)
                                        const LinearProgressIndicator()
                                      else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                linked.isEmpty
                                                    ? 'Ready for your first step'
                                                    : '$completed of ${linked.length} linked tasks complete',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                            if (linked.isNotEmpty)
                                              Text(
                                                '${(completed / linked.length * 100).round()}%',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppPalette.primary,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (linked.isNotEmpty)
                                          LinearProgressIndicator(
                                            value: completed / linked.length,
                                            minHeight: 5,
                                          )
                                        else
                                          const Text(
                                            'Link an approved task from Today to start.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppPalette.muted,
                                            ),
                                          ),
                                      ],
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          top: 22,
                                          bottom: 8,
                                        ),
                                        child: Divider(height: 1),
                                      ),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => showDialog<void>(
                                              context: context,
                                              builder: (_) => _CreateObjective(
                                                kind: item['kind'] as String,
                                                goals: const [],
                                                existing: item,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 15,
                                            ),
                                            label: const Text('Rename'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () async {
                                              try {
                                                await ref
                                                    .read(apiClientProvider)
                                                    .dio
                                                    .patch(
                                                      '/v1/objectives/${item['id']}',
                                                      data: {
                                                        'status': done
                                                            ? 'active'
                                                            : 'completed',
                                                      },
                                                    );
                                                ref.invalidate(
                                                  objectivesProvider,
                                                );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        apiError(e),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            icon: Icon(
                                              done
                                                  ? Icons.refresh
                                                  : Icons.check_circle_outline,
                                              size: 15,
                                            ),
                                            label: Text(
                                              done ? 'Reopen' : 'Mark complete',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppPalette.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Progress uses your latest loaded tasks. You decide when a goal is complete.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateObjective extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final String kind;
  final List<Map<String, dynamic>> goals;
  const _CreateObjective({
    required this.kind,
    required this.goals,
    this.existing,
  });
  @override
  ConsumerState<_CreateObjective> createState() => _CreateObjectiveState();
}

class _CreateObjectiveState extends ConsumerState<_CreateObjective> {
  late final _title = TextEditingController(
    text: widget.existing?['title'] as String? ?? '',
  );
  String _operation = newOperationId();
  String? _parent, _error;
  bool _busy = false;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        '${widget.existing == null ? 'New' : 'Rename'} ${widget.kind}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              enabled: !_busy,
              maxLength: 255,
              autofocus: true,
              onChanged: (_) => _operation = newOperationId(),
              decoration: const InputDecoration(
                labelText: 'What do you want to achieve?',
              ),
            ),
            if (widget.kind == 'project' && widget.existing == null)
              DropdownButtonFormField<String>(
                initialValue: _parent,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Goal (optional)'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Standalone project'),
                  ),
                  for (final goal in widget.goals)
                    DropdownMenuItem(
                      value: goal['id'] as String,
                      child: Text(
                        goal['title'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _parent = value;
                        _operation = newOperationId();
                      }),
              ),
            if (_error != null) Text(_error!),
            if (_busy) const LinearProgressIndicator(),
          ],
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
                    setState(() => _error = 'Add a title first.');
                    return;
                  }
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    if (widget.existing != null) {
                      await ref
                          .read(apiClientProvider)
                          .dio
                          .patch(
                            '/v1/objectives/${widget.existing!['id']}',
                            data: {'title': _title.text.trim()},
                          );
                    } else {
                      await ref
                          .read(apiClientProvider)
                          .dio
                          .post(
                            '/v1/objectives',
                            data: {
                              'id': _operation,
                              'title': _title.text.trim(),
                              'kind': widget.kind,
                              'parent_id': _parent,
                            },
                          );
                    }
                    ref.invalidate(objectivesProvider);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) setState(() => _error = apiError(e));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(widget.existing == null ? 'Create' : 'Save changes'),
        ),
      ],
    ),
  );
}
