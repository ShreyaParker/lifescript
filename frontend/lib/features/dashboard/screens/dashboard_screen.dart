import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/colors.dart';
import 'package:frontend/shared/widgets/glass_container.dart';
import 'package:frontend/state/task_provider.dart';
import 'package:frontend/state/audit_provider.dart';
import 'package:frontend/shared/widgets/script_correction_alert.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(auditProvider.notifier).checkWeeklyAudit());
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    ref.read(taskProvider.notifier).fetchArchivedTasks(date);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final auditState = ref.watch(auditProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Blob Layers
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: LifeScriptColors.pastelMint.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 150,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: LifeScriptColors.pastelPeach.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => context.push('/profile'),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: LifeScriptColors.pastelMint,
                          child: Text(
                            Supabase
                                    .instance
                                    .client
                                    .auth
                                    .currentSession
                                    ?.user
                                    .email
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                '?',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'lifescript.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: LifeScriptColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_note_rounded,
                          size: 30,
                          color: LifeScriptColors.textPrimary,
                        ),
                        onPressed: () => context.push('/journal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Script Correction Alert
                  ScriptCorrectionAlert(audit: auditState),

                  // Character Level & Progression Core Card
                  GlassContainer(
                    baseColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Level 01',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: LifeScriptColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Character Alignment: 88%',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: LifeScriptColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: const LinearProgressIndicator(
                              value: 0.45,
                              minHeight: 8,
                              backgroundColor:
                                  LifeScriptColors.canvasBackground,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                LifeScriptColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '340 / 500 XP to next level adjustment',
                            style: TextStyle(
                              fontSize: 12,
                              color: LifeScriptColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Core Character Attribute Pillars Rows
                  Row(
                    children: [
                      Expanded(
                        child: GlassContainer(
                          baseColor: LifeScriptColors.pastelMint,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                Text(
                                  '🧠 Focus',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text('Lv. 12'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassContainer(
                          baseColor: LifeScriptColors.pastelLavender,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                Text(
                                  '🌱 Vitality',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text('Lv. 08'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Strategic Generated Tasks Headline
                  const Text(
                    'Task Archive',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LifeScriptColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horizontal 7-Day Date Picker Calendar Ribbon
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().subtract(
                          Duration(days: 3 - index),
                        );
                        final isSelected =
                            date.day == _selectedDate.day &&
                            date.month == _selectedDate.month &&
                            date.year == _selectedDate.year;

                        return GestureDetector(
                          onTap: () => _onDateSelected(date),
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? LifeScriptColors.pastelLavender
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? LifeScriptColors.textPrimary.withValues(
                                        alpha: 0.2,
                                      )
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? LifeScriptColors.textPrimary
                                        : LifeScriptColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date.day.toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? LifeScriptColors.textPrimary
                                        : LifeScriptColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Conditional Layout Rendering for Scriptwriter Tasks
                  tasks.isEmpty
                      ? const GlassContainer(
                          baseColor: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Your script is unwritten for tomorrow. Complete today\'s journal to deploy the Scriptwriter Agent.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LifeScriptColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: GlassContainer(
                                baseColor: task.isCompleted
                                    ? LifeScriptColors.pastelMint.withValues(
                                        alpha: 0.2,
                                      )
                                    : Colors.white,
                                child: ListTile(
                                  leading: Checkbox(
                                    value: task.isCompleted,
                                    activeColor: LifeScriptColors.textPrimary,
                                    onChanged: (_) => ref
                                        .read(taskProvider.notifier)
                                        .toggleTaskStatus(index),
                                  ),
                                  title: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(task.description),
                                  trailing: Chip(
                                    backgroundColor: LifeScriptColors
                                        .pastelPeach
                                        .withValues(alpha: 0.5),
                                    side: BorderSide.none,
                                    label: Text(
                                      '+${task.xpValue} XP',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
