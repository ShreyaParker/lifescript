import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/assistant/screens/assistant_screen.dart';
import 'package:frontend/features/canvas/screens/journal_composer.dart';
import 'package:frontend/features/goals/screens/goals_screen.dart';
import 'package:frontend/features/nexus/screens/nexus_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/shared/widgets/design.dart';
import 'package:frontend/shared/widgets/workspace_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in ['Inter', 'Manrope']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });

  final goals = [
    {
      'id': 'goal-1',
      'title': 'Become a confident backend engineer',
      'kind': 'goal',
      'status': 'active',
    },
    {
      'id': 'project-1',
      'title': 'Build a personal knowledge assistant',
      'kind': 'project',
      'parent_id': 'goal-1',
      'status': 'active',
    },
  ];
  ApiClient api() {
    final client = ApiClient(baseUrl: 'http://unused.test');
    client.dio.interceptors.clear();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: request.path == '/v1/objectives'
                ? goals
                : [
                    {
                      'id': 'task-1',
                      'title': 'Review the retrieval pipeline',
                      'description': 'Spend twenty minutes with your notes.',
                      'status': 'pending',
                      'objective_id': 'project-1',
                    },
                    {
                      'id': 'task-2',
                      'title': 'Write one useful integration test',
                      'description': '',
                      'status': 'pending',
                      'objective_id': 'project-1',
                    },
                    {
                      'id': 'task-3',
                      'title': 'Finish a small prototype',
                      'description': '',
                      'status': 'completed',
                      'objective_id': 'goal-1',
                    },
                  ],
          ),
        ),
      ),
    );
    return client;
  }

  for (final size in [
    const Size(320, 800),
    const Size(390, 900),
    const Size(960, 1000),
    const Size(1440, 1050),
  ]) {
    for (var page = 0; page < 4; page++) {
      testWidgets('Responsive page $page at ${size.width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController();
        final capture = GlobalKey();
        var selected = page;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(api())],
            child: MaterialApp(
              theme: lifeScriptTheme(),
              home: RepaintBoundary(
                key: capture,
                child: StatefulBuilder(
                  builder: (context, setState) => WorkspaceFrame(
                    index: selected,
                    onSelect: (value) => setState(() => selected = value),
                    actions: [
                      IconButton(
                        onPressed: () {},
                        tooltip: 'Search your memory',
                        icon: const Icon(Icons.manage_search),
                      ),
                      IconButton(
                        onPressed: () {},
                        tooltip: 'Account and tools',
                        icon: const Icon(Icons.account_circle_outlined),
                      ),
                    ],
                    pages: [
                      NexusScreen(
                        onWriteJournal: () => setState(() => selected = 1),
                      ),
                      ListView(
                        padding: pagePadding(context),
                        children: [
                          const PageIntro(
                            eyebrow: 'Pause. Reflect. Begin again.',
                            title: 'Make space for your thoughts.',
                            description:
                                'No perfect words needed. Write it out, and find a gentle next step.',
                          ),
                          JournalComposer(
                            controller: controller,
                            busy: false,
                            recording: false,
                            audioAvailable: false,
                            onAttach: () {},
                            onRecord: () {},
                            onSubmit: () {},
                            attachments: const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 24),
                          const LiftCard(
                            child: EmptyState(
                              icon: Icons.auto_stories_outlined,
                              title: 'Your story starts here',
                              description:
                                  'Saved reflections will appear here.',
                            ),
                          ),
                        ],
                      ),
                      const GoalsScreen(),
                      const AssistantScreen(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            ValueKey(
              size.width >= 880 ? 'desktop-sidebar' : 'mobile-navigation',
            ),
          ),
          findsOneWidget,
        );
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('.local/ui-previews')
              ..createSync(recursive: true);
            File(
              '${directory.path}/page-$page-${size.width.toInt()}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Navigation transitions keep mounted page state and finish without a loop.
        if (page == 0) {
          await tester.tap(find.text('Journal').first);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).first,
            'A draft that stays with me.',
          );
          await tester.tap(find.text('Today').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Journal').first);
          await tester.pumpAndSettle();
          expect(find.text('A draft that stays with me.'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
    }
  }

  testWidgets('Large text and reduced motion remain usable', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api())],
        child: MaterialApp(
          theme: lifeScriptTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 900),
              textScaler: TextScaler.linear(1.5),
              disableAnimations: true,
            ),
            child: Scaffold(body: NexusScreen(onWriteJournal: () {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
