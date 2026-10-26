import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/services/api_client.dart';

final calendarConnectionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final response = await ref
          .watch(apiClientProvider)
          .dio
          .get('/v1/calendar/connection');
      return Map<String, dynamic>.from(response.data);
    });
final calendarActionsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get('/v1/calendar/actions');
  return response.data as List;
});

class CalendarPanel extends ConsumerStatefulWidget {
  const CalendarPanel({super.key});
  @override
  ConsumerState<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends ConsumerState<CalendarPanel> {
  final _summary = TextEditingController();
  DateTime? _start, _end;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _operation(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(calendarActionsProvider);
      ref.invalidate(calendarConnectionProvider);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool start) async {
    final current = (start ? _start : _end) ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (day == null || !mounted) return;
    final clock = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (clock == null || !mounted) return;
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      clock.hour,
      clock.minute,
    );
    setState(() {
      if (start) {
        _start = value;
        _end ??= value.add(const Duration(hours: 1));
      } else {
        _end = value;
      }
    });
  }

  String _display(DateTime? value) =>
      value == null ? 'Choose time' : DateFormat.yMMMd().add_jm().format(value);
  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(calendarConnectionProvider),
        actions = ref.watch(calendarActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Calendar actions',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Calendar access is separate from sign-in. An event is written only after you approve its draft.',
        ),
        connection.when(
          data: (data) => Wrap(
            spacing: 8,
            children: [
              Text(
                data['connected'] == true
                    ? 'Calendar connected'
                    : 'Calendar not connected',
              ),
              OutlinedButton(
                onPressed: _busy || data['configured'] != true
                    ? null
                    : () => _operation(() async {
                        if (data['connected'] == true) {
                          await ref
                              .read(apiClientProvider)
                              .dio
                              .delete('/v1/calendar/connection');
                        } else {
                          final response = await ref
                              .read(apiClientProvider)
                              .dio
                              .post('/v1/calendar/connect');
                          if (!mounted) return;
                          await launchUrl(
                            Uri.parse(
                              response.data['authorization_url'] as String,
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }),
                child: Text(
                  data['connected'] == true ? 'Disconnect' : 'Connect calendar',
                ),
              ),
              IconButton(
                tooltip: 'Refresh calendar status',
                onPressed: () {
                  ref.invalidate(calendarConnectionProvider);
                  ref.invalidate(calendarActionsProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
              if (data['configured'] != true)
                const Text(
                  'Calendar connections are not available on this server yet.',
                ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(apiError(e)),
        ),
        TextField(
          controller: _summary,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Event title'),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _pick(true),
              child: Text('Start: ${_display(_start)}'),
            ),
            OutlinedButton(
              onPressed: () => _pick(false),
              child: Text('End: ${_display(_end)}'),
            ),
          ],
        ),
        const Text('Times use this device\'s local timezone.'),
        FilledButton(
          onPressed: _busy || _start == null || _end == null
              ? null
              : () => _operation(() async {
                  await ref
                      .read(apiClientProvider)
                      .dio
                      .post(
                        '/v1/calendar/actions',
                        data: {
                          'summary': _summary.text.trim(),
                          'start': _start!.toUtc().toIso8601String(),
                          'end': _end!.toUtc().toIso8601String(),
                        },
                      );
                  _summary.clear();
                }),
          child: const Text('Draft calendar event'),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        actions.when(
          data: (items) => Column(
            children: items
                .map(
                  (row) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['payload']['summary'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${row['payload']['start']} to ${row['payload']['end']}',
                          ),
                          Text('Status: ${row['status']}'),
                          if (row['status'] == 'draft' ||
                              row['status'] == 'uncertain')
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _operation(() async {
                                          await ref
                                              .read(apiClientProvider)
                                              .dio
                                              .post(
                                                '/v1/calendar/actions/${row['id']}/decision',
                                                data: {'approve': true},
                                              );
                                        }),
                                  child: Text(
                                    row['status'] == 'uncertain'
                                        ? 'Reconcile and retry'
                                        : 'Approve event',
                                  ),
                                ),
                                if (row['status'] == 'draft')
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _operation(() async {
                                            await ref
                                                .read(apiClientProvider)
                                                .dio
                                                .post(
                                                  '/v1/calendar/actions/${row['id']}/decision',
                                                  data: {'approve': false},
                                                );
                                          }),
                                    child: const Text('Reject'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(apiError(e)),
        ),
      ],
    );
  }
}
