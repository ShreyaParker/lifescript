import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/state/workflow_provider.dart';
import 'package:frontend/features/automation/screens/calendar_panel.dart';

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});
  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  final _name = TextEditingController(), _instruction = TextEditingController();
  String _kind = 'daily_plan';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/v1/automations',
            data: {
              'name': _name.text.trim(),
              'instruction': _instruction.text.trim(),
              'kind': _kind,
              'interval_hours': _kind == 'weekly_review' ? 168 : 24,
            },
          );
      _name.clear();
      _instruction.clear();
      ref.invalidate(automationsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> rule, bool enabled) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .patch('/v1/automations/${rule['id']}', data: {'enabled': enabled});
      ref.invalidate(automationsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(automationsProvider),
        events = ref.watch(automationEventsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Your automations',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Opt in to recurring drafts or in-app reminders. Generated plans still need your approval. New rules run on the next scheduler tick.',
        ),
        TextField(
          controller: _name,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Rule name'),
        ),
        DropdownButton<String>(
          value: _kind,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'daily_plan',
              child: Text('Daily plan draft'),
            ),
            DropdownMenuItem(
              value: 'weekly_review',
              child: Text('Weekly review draft'),
            ),
            DropdownMenuItem(
              value: 'reminder',
              child: Text('Daily in-app reminder'),
            ),
          ],
          onChanged: (value) => setState(() => _kind = value!),
        ),
        TextField(
          controller: _instruction,
          maxLines: 3,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'What should LifeScript help you with?',
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: const Text('Enable automation'),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Active and paused rules',
                style: TextStyle(fontSize: 20),
              ),
            ),
            IconButton(
              tooltip: 'Refresh automations',
              onPressed: () {
                ref.invalidate(automationsProvider);
                ref.invalidate(automationEventsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        rules.when(
          data: (items) => Column(
            children: [
              if (items.isEmpty) const Text('No automation rules yet.'),
              ...items.map(
                (rule) => SwitchListTile(
                  value: rule['enabled'] as bool,
                  title: Text(rule['name'] as String),
                  subtitle: Text(
                    '${rule['instruction']}\nEvery ${rule['interval_hours']} hours ? next: ${rule['next_run_at']}',
                  ),
                  onChanged: (value) => _toggle(rule, value),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(apiError(e)),
        ),
        const SizedBox(height: 20),
        const Text('Execution history', style: TextStyle(fontSize: 20)),
        events.when(
          data: (items) => Column(
            children: items
                .map(
                  (event) => ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(event['message'] as String),
                    subtitle: Text(event['created_at'] as String),
                  ),
                )
                .toList(),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(apiError(e)),
        ),
        const SizedBox(height: 28),
        const CalendarPanel(),
      ],
    );
  }
}
