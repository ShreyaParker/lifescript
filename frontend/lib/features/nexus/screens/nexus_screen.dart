import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/widgets/design.dart';
import 'package:frontend/features/nexus/screens/task_editor.dart';
import 'package:frontend/state/task_provider.dart';
import 'package:frontend/state/objectives_provider.dart';

class NexusScreen extends ConsumerStatefulWidget {
  final VoidCallback? onWriteJournal;
  const NexusScreen({super.key, this.onWriteJournal});
  @override
  ConsumerState<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends ConsumerState<NexusScreen> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final objectives = ref.watch(objectivesProvider);
    final goals = (objectives.valueOrNull ?? [])
        .where((goal) => goal['kind'] == 'goal' && goal['status'] == 'active')
        .toList();
    final error = ref.watch(taskErrorProvider);
    final loading = ref.watch(taskLoadingProvider);
    final completed = tasks.where((task) => task.isCompleted).length;
    final visible = [
      for (var i = 0; i < tasks.length; i++)
        if (_filter == 'all' ||
            tasks[i].isCompleted == (_filter == 'completed'))
          i,
    ];
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(objectivesProvider);
        await ref.read(taskProvider.notifier).fetchDailyTasks();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding(context),
        children: [
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEEE9FF),
                    Color(0xFFF4F0FF),
                    Color(0xFFEAF3EF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE3DDF6)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('A little space for you'),
                          const SizedBox(height: 14),
                          Text(
                            'A little clarity.\nA meaningful next step.',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: constraints.maxWidth < 400
                                      ? 26
                                      : 32,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Let your thoughts breathe. We will help you find a place to start.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF6B6284)),
                          ),
                          if (widget.onWriteJournal != null) ...[
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: widget.onWriteJournal,
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 20,
                              ),
                              label: const Text('Write a journal entry'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (constraints.maxWidth >= 540)
                      const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: FocusArt(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stat in [
                  (
                    Icons.checklist_rounded,
                    'To do',
                    loading || error != null
                        ? '\u2014'
                        : '${tasks.length - completed}',
                    const Color(0xFFEFEBFF),
                  ),
                  (
                    Icons.check_circle_outline_rounded,
                    'Completed',
                    loading || error != null ? '\u2014' : '$completed',
                    AppPalette.mint,
                  ),
                  (
                    Icons.flag_outlined,
                    'Active goals',
                    objectives.hasValue ? '${goals.length}' : '\u2014',
                    const Color(0xFFFFF0E4),
                  ),
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: stat.$2 == 'Active goals' ? 0 : 10,
                      ),
                      child: LiftCard(
                        padding: EdgeInsets.all(
                          constraints.maxWidth < 430 ? 14 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(stat.$1, size: 20, color: AppPalette.primary),
                            const SizedBox(height: 14),
                            Text(
                              stat.$3,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              stat.$2,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your next steps',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(taskProvider.notifier).fetchDailyTasks(),
                tooltip: 'Reload tasks',
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          Text(
            'Small actions, chosen by you.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              style: ButtonStyle(
                side: const WidgetStatePropertyAll(BorderSide.none),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppPalette.lavender
                      : Colors.white,
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'pending', label: Text('To do')),
                ButtonSegment(value: 'completed', label: Text('Done')),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
          const SizedBox(height: 8),
          LiftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (tasks.isEmpty && !loading && error == null)
                  const EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'A clear page. A fresh start.',
                    description:
                        'Write a journal entry, then review the suggested tasks you want to make room for.',
                  ),
                if (tasks.isNotEmpty && visible.isEmpty)
                  const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Nothing here for now',
                    description: 'Try another filter to see your other tasks.',
                  ),
                for (final i in visible)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    value: tasks[i].isCompleted,
                    title: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: tasks[i].isCompleted
                            ? AppPalette.muted
                            : AppPalette.ink,
                        decoration: tasks[i].isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      child: Text(tasks[i].title),
                    ),
                    subtitle: tasks[i].description.isEmpty
                        ? null
                        : Text(
                            tasks[i].description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                    secondary: IconButton(
                      tooltip: 'Edit task or link a goal',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => TaskEditor(task: tasks[i]),
                      ),
                    ),
                    onChanged: (_) =>
                        ref.read(taskProvider.notifier).toggleTaskStatus(i),
                  ),
                if (tasks.isNotEmpty && !loading && error == null) ...[
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: completed / tasks.length),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    builder: (_, value, _) =>
                        LinearProgressIndicator(value: value, minHeight: 5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$completed of ${tasks.length} tasks complete',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Your bigger picture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'A reminder of what matters to you.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (final goal in goals.take(3))
              LiftCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.mint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        color: Color(0xFF568A76),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow(
                            'Active goal',
                            color: Color(0xFF568A76),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            goal['title'] as String,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            'Progress reflects your latest loaded tasks, across all dates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
