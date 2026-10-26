import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/widgets/design.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Map<String, dynamic>>[];
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _input.text.trim();
    if (_busy || question.isEmpty) return;
    final api = ref.read(apiClientProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await api.dio.post(
        '/v1/assistant',
        data: {
          'question': question,
          'history': _messages
              .skip(_messages.length > 4 ? _messages.length - 4 : 0)
              .map((m) => {'question': m['question'], 'answer': m['answer']})
              .toList(),
        },
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
      if (!mounted || ref.read(apiClientProvider) != api) return;
      setState(() {
        _messages.add({
          'question': question,
          ...Map<String, dynamic>.from(response.data),
        });
        _input.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: pagePadding(context),
          children: [
            if (_messages.isEmpty) ...[
              Reveal(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0ECFF), Color(0xFFF8F7FC)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 126,
                        child: FittedBox(child: FocusArt()),
                      ),
                      const SizedBox(height: 12),
                      const Eyebrow('A little perspective'),
                      const SizedBox(height: 12),
                      Text(
                        "Let's think it through.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          'A place to untangle your thoughts, revisit your reflections, and find your next step.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Grounded in your journal, tasks and goals.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final prompt in [
                      (
                        Icons.wb_sunny_outlined,
                        'Find my focus',
                        'What should I focus on next?',
                      ),
                      (
                        Icons.auto_stories_outlined,
                        'Look back',
                        'What have I written about my goals?',
                      ),
                      (
                        Icons.route_outlined,
                        'Break it down',
                        'Help me break down my current project.',
                      ),
                    ])
                      SizedBox(
                        width: constraints.maxWidth >= 650
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _input.text = prompt.$3,
                            child: LiftCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    prompt.$1,
                                    color: AppPalette.primary,
                                    size: 21,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    prompt.$2,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    prompt.$3,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const Eyebrow('Your conversation'),
              const SizedBox(height: 8),
              Text(
                'One thought at a time.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
            ],
            for (final message in _messages)
              Reveal(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: AppPalette.lavender,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(22),
                                topRight: Radius.circular(22),
                                bottomLeft: Radius.circular(22),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            child: SelectableText(
                              message['question'] as String,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppPalette.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'LifeScript',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      LiftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              message['answer'] as String,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            for (final source
                                in message['citations'] as List? ?? [])
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.format_quote_rounded,
                                  color: AppPalette.primary,
                                  size: 18,
                                ),
                                title: Text(
                                  'Source: ${source['kind']}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppPalette.primary),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SelectableText(
                                      source['quote'] as String,
                                    ),
                                  ),
                                ],
                              ),
                            if (message['retrieval'] == 'keyword')
                              Text(
                                'Keyword retrieval used; semantic search was unavailable.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      Container(
        margin: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
          8,
          MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
          20,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDED7F2)),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: .06),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_busy,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => currentLength > 1800
                        ? Text('$currentLength / $maxLength')
                        : null,
                    decoration: const InputDecoration(
                      hintText: 'What would you like to explore?',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _input,
                  builder: (context, value, _) => IconButton.filled(
                    tooltip: 'Ask assistant',
                    onPressed: _busy || value.text.trim().isEmpty ? null : _ask,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 12,
                    color: AppPalette.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your context. Thoughtful suggestions.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  const Tooltip(
                    message:
                        'Answers include source quotes and cannot change your data. Uses the last four replies plus saved context. Conversation is screen-local and clears on account change or app reload.',
                    child: Icon(
                      Icons.info_outline,
                      color: AppPalette.muted,
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
