import 'dart:async';
import 'package:frontend/shared/widgets/design.dart';
import 'package:frontend/features/canvas/screens/journal_composer.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:frontend/services/api_client.dart';
import 'package:frontend/state/workflow_provider.dart';
import 'package:frontend/state/task_provider.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key});
  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  final List<Map<String, dynamic>> _assets = [];
  final List<int> _audio = [];
  StreamSubscription<Uint8List>? _audioStream;
  Timer? _poll, _recordLimit;
  bool _busy = false, _recording = false;
  String? _error, _requestKey;
  late final String _owner;
  bool get _isOwner =>
      mounted &&
      _owner.isNotEmpty &&
      Supabase.instance.client.auth.currentUser?.id == _owner;
  String get _draftKey => 'draft:$_owner';

  @override
  void initState() {
    super.initState();
    _owner = Supabase.instance.client.auth.currentUser?.id ?? '';
    final draft = _owner.isEmpty
        ? null
        : Hive.box('cached_journals').get(_draftKey);
    if (draft is Map) {
      _text.text = draft['text'] as String? ?? '';
      _requestKey = draft['key'] as String?;
      _assets.addAll(
        (draft['assets'] as List? ?? []).map(
          (a) => Map<String, dynamic>.from(a),
        ),
      );
    }
    _text.addListener(_saveDraft);
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted &&
          (ref.read(runsProvider).valueOrNull ?? []).any(
            (run) => run['status'] == 'queued' || run['status'] == 'running',
          )) {
        ref.invalidate(runsProvider);
      }
    });
  }

  void _saveDraft() {
    if (!_isOwner) return;
    // Stable key across retries/restarts; editing input creates a new operation.
    _requestKey = null;
    Hive.box(
      'cached_journals',
    ).put(_draftKey, {'text': _text.text, 'assets': _assets});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _recordLimit?.cancel();
    _audioStream?.cancel();
    _recorder.dispose();
    _text.removeListener(_saveDraft);
    _text.dispose();
    super.dispose();
  }

  Future<void> _upload(List<int> data, String name) async {
    if (!_isOwner) return;
    if (_assets.length >= 5) throw StateError('Five attachments maximum');
    if (data.length > 10485760) throw StateError('Attachment exceeds 10 MB');
    final response = await ref
        .read(apiClientProvider)
        .dio
        .post(
          '/v1/assets',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(data, filename: name),
          }),
        );
    if (!_isOwner) return;
    setState(() => _assets.add(Map<String, dynamic>.from(response.data)));
    _saveDraft();
  }

  Future<void> _attach() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'wav', 'mp3', 'webm'],
        withData: true,
      );
      if (picked != null && _isOwner) {
        final file = picked.files.single;
        if (file.bytes != null) await _upload(file.bytes!, file.name);
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _record() async {
    if (!_isOwner) return;
    if (_recording) {
      _recordLimit?.cancel();
      setState(() {
        _recording = false;
        _busy = true;
      });
      try {
        await _recorder.stop();
        if (!_isOwner) return;
        await _audioStream?.cancel();
        final bytes = Uint8List(44 + _audio.length);
        final header = ByteData.sublistView(bytes);
        void ascii(int offset, String value) =>
            bytes.setRange(offset, offset + value.length, value.codeUnits);
        ascii(0, 'RIFF');
        header.setUint32(4, 36 + _audio.length, Endian.little);
        ascii(8, 'WAVE');
        ascii(12, 'fmt ');
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 1, Endian.little);
        header.setUint16(22, 1, Endian.little);
        header.setUint32(24, 16000, Endian.little);
        header.setUint32(28, 32000, Endian.little);
        header.setUint16(32, 2, Endian.little);
        header.setUint16(34, 16, Endian.little);
        ascii(36, 'data');
        header.setUint32(40, _audio.length, Endian.little);
        bytes.setRange(44, bytes.length, _audio);
        await _upload(bytes, 'voice-note.wav');
      } catch (e) {
        if (mounted) setState(() => _error = apiError(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(
            () => _error =
                'Microphone permission is required to record a voice note.',
          );
        }
        return;
      }
      if (!_isOwner) return;
      _audio.clear();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      if (!_isOwner) {
        await _recorder.cancel();
        return;
      }
      _audioStream = stream.listen((data) {
        if (_audio.length < 3840000) _audio.addAll(data);
      });
      if (mounted) setState(() => _recording = true);
      _recordLimit = Timer(const Duration(seconds: 120), () {
        if (mounted && _recording) _record();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Recording is unavailable on this device.');
      }
    }
  }

  Future<void> _submit() async {
    if (!_isOwner || _text.text.trim().isEmpty || _busy || _recording) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _requestKey ??=
        'entry-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    try {
      await Hive.box('cached_journals').put(_draftKey, {
        'text': _text.text,
        'assets': _assets,
        'key': _requestKey,
      });
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/v1/entries',
            data: {
              'content': _text.text.trim(),
              'asset_ids': _assets.map((a) => a['id']).toList(),
            },
            options: Options(headers: {'Idempotency-Key': _requestKey}),
          );
      if (!_isOwner) return;
      _text.clear();
      setState(() {
        _assets.clear();
        _requestKey = null;
      });
      await Hive.box('cached_journals').delete(_draftKey);
      ref.invalidate(runsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(runsProvider);
    final audioAvailable =
        ref.watch(capabilitiesProvider).valueOrNull?['audio'] == true;
    ref.listen(runsProvider, (previous, next) {
      final before =
          previous?.valueOrNull
              ?.where((r) => r['status'] == 'completed')
              .length ??
          0;
      final after =
          next.valueOrNull?.where((r) => r['status'] == 'completed').length ??
          0;
      if (after > before) {
        Future.microtask(
          () => ref.read(taskProvider.notifier).fetchDailyTasks(),
        );
      }
    });
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageIntro(
          eyebrow: 'Pause. Reflect. Begin again.',
          title: 'Make space for your thoughts.',
          description:
              'No perfect words needed. Write it out, and find a gentle next step.',
        ),
        JournalComposer(
          controller: _text,
          busy: _busy,
          recording: _recording,
          audioAvailable: audioAvailable,
          onAttach: _attach,
          onRecord: _record,
          onSubmit: _submit,
          attachments: Wrap(
            spacing: 8,
            children: _assets
                .map(
                  (a) => InputChip(
                    label: Text(a['filename'] as String),
                    onDeleted: _busy
                        ? null
                        : () {
                            setState(() => _assets.remove(a));
                            _saveDraft();
                          },
                  ),
                )
                .toList(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your reflections',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(runsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        runs.when(
          data: (items) => items.isEmpty
              ? const LiftCard(
                  child: EmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'Your story starts here',
                    description:
                        'Saved entries and suggestions will appear here, ready for you to revisit and review.',
                  ),
                )
              : Column(
                  children: items
                      .map(
                        (run) => RunCard(
                          key: ValueKey('${run['id']}:${run['version']}'),
                          run: run,
                        ),
                      )
                      .toList(),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(apiError(error)),
        ),
      ],
    );
  }
}

class RunCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> run;
  const RunCard({super.key, required this.run});
  @override
  ConsumerState<RunCard> createState() => _RunCardState();
}

class _RunCardState extends ConsumerState<RunCard> {
  final _answer = TextEditingController();
  final Set<int> _excluded = {};
  bool _busy = false;
  String? _error;

  Future<void> _correctSource(int index) async {
    final sources = (widget.run['sources'] as List)
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final text = TextEditingController(
      text: sources[index]['content'] as String,
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct extracted text'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: TextField(
              controller: text,
              minLines: 5,
              maxLines: 16,
              maxLength: 30000,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save and reprocess'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      sources[index]['content'] = text.text.trim();
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await ref
            .read(apiClientProvider)
            .dio
            .patch(
              '/v1/runs/${widget.run['id']}/sources',
              data: {'version': widget.run['version'], 'sources': sources},
            );
        ref.invalidate(runsProvider);
      } catch (e) {
        if (mounted) setState(() => _error = apiError(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 300), text.dispose);
  }

  Future<void> _edit(int index) async {
    final proposal = Map<String, dynamic>.from(widget.run['proposal'] as Map);
    final tasks = (proposal['tasks'] as List)
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final title = TextEditingController(text: tasks[index]['title'] as String);
    final description = TextEditingController(
      text: tasks[index]['description'] as String,
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit proposed task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: description,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const Text(
                'The original source evidence stays attached. Saving does not approve the task.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      tasks[index]['title'] = title.text.trim();
      tasks[index]['description'] = description.text.trim();
      proposal['tasks'] = tasks;
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await ref
            .read(apiClientProvider)
            .dio
            .patch(
              '/v1/runs/${widget.run['id']}/proposal',
              data: {'version': widget.run['version'], 'proposal': proposal},
            );
        ref.invalidate(runsProvider);
      } catch (e) {
        if (mounted) setState(() => _error = apiError(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    // Dialog route may animate out after the result; dispose controllers next frame.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      title.dispose();
      description.dispose();
    });
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _act(String action, Map<String, dynamic> data) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/v1/runs/${widget.run['id']}/$action', data: data);
      ref.invalidate(runsProvider);
      await ref.read(taskProvider.notifier).fetchDailyTasks();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final proposal = run['proposal'] as Map? ?? {};
    final tasks = proposal['tasks'] as List? ?? [];
    final status = run['status'] as String;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (status) {
              'queued' => 'Saved ? waiting to process',
              'running' => 'Finding your next steps',
              'awaiting_review' => 'Review your suggested tasks',
              'awaiting_clarification' => 'A quick question',
              'completed' => 'Review complete',
              'rejected' => 'Suggestions dismissed',
              'cancelled' => 'Processing cancelled',
              _ => 'Processing needs attention',
            }, style: Theme.of(context).textTheme.labelLarge),
            if (status == 'queued' || status == 'running') ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              Text(
                run['error_code'] == 'provider_quota_exceeded'
                    ? 'Reflection saved. Waiting for AI provider quota; processing will retry.'
                    : 'Reflection saved. Suggestions are being processed.',
              ),
            ],
            if (proposal['coaching_insight'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(proposal['coaching_insight'] as String),
              ),
            if (status == 'awaiting_clarification') ...[
              ...((run['questions'] as List?) ?? []).map(
                (q) => Text(q.toString()),
              ),
              TextField(
                controller: _answer,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Your clarification',
                ),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act('clarification', {
                        'answer': _answer.text.trim(),
                      }),
                child: const Text('Continue'),
              ),
            ],
            if (status == 'awaiting_review') ...[
              for (var i = 0; i < tasks.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: !_excluded.contains(i),
                  secondary: IconButton(
                    tooltip: 'Edit proposed task',
                    onPressed: _busy ? null : () => _edit(i),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  title: Text(tasks[i]['title'] as String),
                  subtitle: Text(
                    '${tasks[i]['duration_minutes']} min | ${tasks[i]['description']}\nEvidence: ${tasks[i]['evidence']}',
                  ),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          value == true
                              ? _excluded.remove(i)
                              : _excluded.add(i);
                        }),
                ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _act('decision', {
                            'decision': 'approve',
                            'version': run['version'],
                            'selected_indices': [
                              for (var i = 0; i < tasks.length; i++)
                                if (!_excluded.contains(i)) i,
                            ],
                          }),
                    child: const Text('Approve selected'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act('decision', {
                            'decision': 'reject',
                            'version': run['version'],
                            'selected_indices': <int>[],
                          }),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
            if (status == 'completed')
              Text(
                '${(run['result'] as List? ?? []).length} approved tasks saved. Open Today to track them.',
              ),
            if (status == 'rejected')
              const Text('Proposal rejected. No tasks were created.'),
            if (status == 'cancelled')
              const Text(
                'This processing run was cancelled when its automation was paused.',
              ),
            if (status == 'failed') ...[
              Text(switch (run['error_code']) {
                'provider_quota_exceeded' =>
                  'AI provider quota is reached. Your reflection is saved. Retry when quota is available.',
                'scanned_pdf_requires_ocr' =>
                  'This PDF needs OCR support. Try a text-based PDF or attach clear page images. Your reflection is saved.',
                'pdf_encrypted_or_page_limit' =>
                  'Use an unencrypted PDF with at most 30 pages. Your reflection is saved.',
                'audio_duration_limit' =>
                  'This recording is too long. Use an audio clip under five minutes.',
                'media_engine_unavailable' =>
                  'Processing support for this attachment is unavailable. Your reflection is saved.',
                _ =>
                  'Processing did not finish. Your reflection is saved. You can retry.',
              }),
              TextButton(
                onPressed: _busy ? null : () => _act('retry', {}),
                child: const Text('Retry processing'),
              ),
            ],
            if ((run['sources'] as List? ?? []).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Source excerpts'),
                children: [
                  for (
                    var sourceIndex = 0;
                    sourceIndex < (run['sources'] as List).length;
                    sourceIndex++
                  )
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '${run['sources'][sourceIndex]['source_id']}\n${run['sources'][sourceIndex]['content']}',
                          ),
                          if (status == 'awaiting_review' ||
                              status == 'awaiting_clarification')
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _correctSource(sourceIndex),
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Correct extracted text'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
