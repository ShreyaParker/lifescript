import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/assistant/screens/assistant_screen.dart';
import 'package:frontend/features/goals/screens/goals_screen.dart';
import 'package:frontend/features/nexus/screens/task_editor.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/shared/widgets/account_scope.dart';
import 'package:frontend/state/task_provider.dart';

ApiClient fakeApi(
  dynamic Function(RequestOptions) reply,
  List<RequestOptions> requests,
) {
  final api = ApiClient(baseUrl: 'http://unused.test');
  api.dio.interceptors.clear();
  api.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        final data = reply(options);
        if (data is DioException) {
          handler.reject(data);
          return;
        }
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data),
        );
      },
    ),
  );
  return api;
}

void main() {
  testWidgets('Goal creation and task linking use persisted IDs', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final rows = <Map<String, dynamic>>[];
    final api = fakeApi((r) {
      if (r.path == '/v1/objectives' && r.method == 'POST') {
        rows.add(Map<String, dynamic>.from(r.data)..['status'] = 'active');
        return rows.last;
      }
      if (r.path == '/v1/objectives') return rows;
      return [];
    }, requests);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: GoalsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Become an AI engineer');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Become an AI engineer'), findsOneWidget);
    final goal = requests.singleWhere((r) => r.method == 'POST').data;
    expect(goal['kind'], 'goal');
    expect(goal['id'], matches(RegExp(r'^[a-f0-9-]{36}$')));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskEditor(
              task: TaskItem(
                id: 'task-1',
                title: 'Learn chunking',
                description: '',
                xpValue: 20,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Become an AI engineer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/tasks/task-1');
    expect(patch.data['objective_id'], goal['id']);
  });

  testWidgets(
    'Assistant cites evidence, sends follow-up context and clears on owner change',
    (tester) async {
      final owners = StreamController<String?>();
      final requests = <RequestOptions>[];
      final api = fakeApi(
        (r) => {
          'answer': 'Review your RAG notes.',
          'retrieval': 'keyword',
          'citations': [
            {
              'source_id': 'memory:0',
              'kind': 'journal',
              'quote': 'Review RAG notes',
            },
          ],
        },
        requests,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authUserProvider.overrideWith((ref) => owners.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AccountScope(child: AssistantScreen())),
          ),
        ),
      );
      owners.add('owner-a');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'What next?');
      await tester.pump();
      await tester.tap(find.byTooltip('Ask assistant'));
      await tester.pumpAndSettle();
      expect(find.text('Review your RAG notes.'), findsOneWidget);
      await tester.tap(find.text('Source: journal'));
      await tester.pumpAndSettle();
      expect(find.text('Review RAG notes'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Break that down');
      await tester.pump();
      await tester.tap(find.byTooltip('Ask assistant'));
      await tester.pumpAndSettle();
      expect(requests.last.data['history'], [
        {'question': 'What next?', 'answer': 'Review your RAG notes.'},
      ]);
      owners.add('owner-b');
      await tester.pumpAndSettle();
      expect(find.text('Review your RAG notes.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(owners.close());
    },
  );

  testWidgets('Assistant failure preserves question for retry', (tester) async {
    final requests = <RequestOptions>[];
    final api = fakeApi(
      (r) => DioException(
        requestOptions: r,
        response: Response(
          requestOptions: r,
          statusCode: 503,
          data: {'detail': 'Assistant temporarily unavailable'},
        ),
      ),
      requests,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: AssistantScreen())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'My question');
    await tester.pump();
    await tester.tap(find.byTooltip('Ask assistant'));
    await tester.pumpAndSettle();
    expect(find.text('My question'), findsOneWidget);
    expect(find.text('Assistant temporarily unavailable'), findsOneWidget);
    expect(find.byTooltip('Ask assistant'), findsOneWidget);
  });
}
