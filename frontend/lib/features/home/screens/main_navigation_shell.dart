import 'package:flutter/material.dart';
import 'package:frontend/shared/widgets/workspace_frame.dart';
import 'package:frontend/features/goals/screens/goals_screen.dart';
import 'package:frontend/features/assistant/screens/assistant_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/services/session_service.dart';
import 'package:frontend/features/canvas/screens/canvas_screen.dart';
import 'package:frontend/features/nexus/screens/nexus_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});
  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => WorkspaceFrame(
    index: _index,
    onSelect: (index) => setState(() => _index = index),
    actions: [
      IconButton(
        tooltip: 'Search your memory',
        onPressed: () => context.push('/memory'),
        icon: const Icon(Icons.manage_search),
      ),
      PopupMenuButton<String>(
        tooltip: 'Account and tools',
        icon: const Icon(Icons.account_circle_outlined),
        onSelected: (value) async {
          if (value != 'signout') {
            context.push(value);
            return;
          }
          try {
            await signOutAndClearLocalData();
            if (context.mounted) context.go('/login');
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not sign out. Please retry.'),
                ),
              );
            }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: '/profile', child: Text('Profile')),
          PopupMenuItem(value: '/attachments', child: Text('Saved media')),
          PopupMenuItem(
            value: '/automation',
            child: Text('Automation and calendar'),
          ),
          PopupMenuItem(value: '/review', child: Text('Weekly review')),
          PopupMenuItem(value: '/connection', child: Text('Connection status')),
          PopupMenuItem(value: 'signout', child: Text('Sign out')),
        ],
      ),
    ],
    pages: [
      NexusScreen(onWriteJournal: () => setState(() => _index = 1)),
      const CanvasScreen(),
      const GoalsScreen(),
      const AssistantScreen(),
    ],
  );
}
