import 'dart:async';
import 'package:frontend/features/nexus/screens/nexus_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/canvas/screens/canvas_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/state/task_provider.dart';
import 'package:frontend/shared/widgets/account_scope.dart';

void main() {
  testWidgets('Today shows persisted progress and opens journal', (
    tester,
  ) async {
    var openedJournal = false;
    final requests = <RequestOptions>[];
    final api = ApiClient(baseUrl: 'http://unused.test');
    api.dio.interceptors.clear();
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: options.path == '/tasks'
                  ? [
                      {
                        'id': 'task-a',
                        'title': 'Review RAG notes',
                        'description': '',
                        'status': 'pending',
                      },
                    ]
                  : options.path == '/profile/'
                  ? {'profile': {}, 'media': []}
                  : {},
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: NexusScreen(onWriteJournal: () => openedJournal = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a journal entry'));
    expect(openedJournal, isTrue);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 200);
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 tasks complete'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 tasks complete'), findsOneWidget);
    final update = requests.singleWhere((r) => r.method == 'PATCH');
    expect(update.path, '/tasks/task-a/toggle');
    expect(update.data, {'is_completed': true});
  });

  testWidgets('Account changes destroy private screen state', (tester) async {
    final owners = StreamController<String?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authUserProvider.overrideWith((ref) => owners.stream)],
        child: const MaterialApp(
          home: Scaffold(body: AccountScope(child: TextField())),
        ),
      ),
    );
    owners.add('owner-a');
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Private draft from A');
    expect(find.text('Private draft from A'), findsOneWidget);
    owners.add('owner-b');
    await tester.pump();
    await tester.pump();
    expect(find.text('Private draft from A'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    owners.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(owners.close());
  });
  test('Tasks require persisted identity and are immutable', () {
    expect(() => TaskItem.fromJson({'title': 'Study'}), throwsFormatException);
    final task = TaskItem.fromJson({
      'id': 'task-1',
      'title': 'Study',
      'status': 'pending',
    });
    final completed = task.withCompleted(true);
    expect(task.isCompleted, isFalse);
    expect(completed.isCompleted, isTrue);
    expect(completed.id, task.id);
  });

  testWidgets(
    'Proposal shows evidence and sends only explicit selected approval',
    (tester) async {
      final requests = <RequestOptions>[];
      final api = ApiClient(baseUrl: 'http://unused.test');
      api.dio.interceptors.clear();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.method == 'GET' ? [] : {},
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RunCard(
                  run: {
                    'id': 'run-1',
                    'status': 'awaiting_review',
                    'version': 1,
                    'sources': <dynamic>[],
                    'proposal': {
                      'coaching_insight': 'Start small.',
                      'tasks': [
                        {
                          'title': 'Review notes',
                          'description': 'Study',
                          'duration_minutes': 20,
                          'evidence': 'I want to review notes',
                        },
                      ],
                    },
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Review notes'), findsOneWidget);
      expect(find.textContaining('Evidence:'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.tap(find.text('Approve selected'));
      await tester.pumpAndSettle();
      expect(requests.first.path, '/v1/runs/run-1/decision');
      expect(requests.first.data, {
        'decision': 'approve',
        'version': 1,
        'selected_indices': [0],
      });
    },
  );

  testWidgets('Rejected proposal reports no task creation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RunCard(
              run: {
                'id': 'run-2',
                'status': 'rejected',
                'version': 1,
                'sources': <dynamic>[],
              },
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Proposal rejected. No tasks were created.'),
      findsOneWidget,
    );
    expect(find.text('Approve selected'), findsNothing);
  });
}
