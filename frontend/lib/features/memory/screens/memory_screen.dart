import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/state/workflow_provider.dart';

final entriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await ref.watch(apiClientProvider).dio.get('/v1/entries');
  return (response.data as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

final ownedAssetsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final response = await ref.watch(apiClientProvider).dio.get('/v1/assets');
  return response.data as List;
});

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});
  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _query = TextEditingController();
  List<dynamic>? _results;
  String? _error;
  Future<void> _downloadAsset(Map row) async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<List<int>>(
            '/v1/assets/${row['id']}',
            options: Options(responseType: ResponseType.bytes),
          );
      if (!mounted) return;
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save attachment',
        fileName: row['filename'] as String,
        bytes: Uint8List.fromList(response.data!),
      );
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  Future<void> _removeAsset(String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete unused attachment?'),
        content: const Text(
          'Attachments used by saved reflections must be removed with their reflection. If this attachment is in an unsent draft, you will need to reattach it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).dio.delete('/v1/assets/$id');
      ref.invalidate(ownedAssetsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  Future<void> _export() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get('/v1/export');
      final text = const JsonEncoder.withIndent('  ').convert(response.data);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your data export'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
              },
              child: const Text('Copy export'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/v1/memory', queryParameters: {'q': _query.text.trim()});
      if (mounted) {
        setState(() {
          _results = response.data as List;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  Future<void> _delete(String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this reflection?'),
        content: const Text(
          'Its active processing runs and searchable memory will be removed. Already approved tasks remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).dio.delete('/v1/entries/$id');
      ref.invalidate(entriesProvider);
      ref.invalidate(runsProvider);
      if (mounted) setState(() => _results = null);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider);
    final assets = ref.watch(ownedAssetsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reflections and memory'),
        actions: [
          IconButton(
            tooltip: 'Export up to 1,000 records per category',
            onPressed: _export,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _query,
            decoration: InputDecoration(
              labelText: 'Search processed reflections',
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_results != null) ...[
            const Text('Search excerpts'),
            if (_results!.isEmpty) const Text('No matching excerpts.'),
            ..._results!.map(
              (row) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(row['content'] as String),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Saved reflections',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          entries.when(
            data: (items) => Column(
              children: items
                  .map(
                    (entry) => Card(
                      child: ListTile(
                        title: Text(entry['content'] as String),
                        subtitle: Text(entry['created_at'] as String),
                        trailing: IconButton(
                          tooltip: 'Delete reflection',
                          onPressed: () => _delete(entry['id'] as String),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(apiError(e)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your attachments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Unused attachments are removed automatically after seven days.',
          ),
          assets.when(
            data: (items) => Column(
              children: items
                  .map(
                    (row) => ListTile(
                      title: Text(row['filename'] as String),
                      subtitle: Text(
                        '${row['size_bytes']} bytes${row['status'] == 'pending' ? ' | Upload incomplete' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Download attachment',
                            onPressed: row['status'] == 'pending'
                                ? null
                                : () => _downloadAsset(row as Map),
                            icon: const Icon(Icons.download),
                          ),
                          IconButton(
                            tooltip: 'Delete unused attachment',
                            onPressed: () => _removeAsset(row['id'] as String),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(apiError(e)),
          ),
        ],
      ),
    );
  }
}
