import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class WorkspaceFrame extends StatefulWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<Widget> pages, actions;
  const WorkspaceFrame({
    super.key,
    required this.index,
    required this.onSelect,
    required this.pages,
    required this.actions,
  });
  @override
  State<WorkspaceFrame> createState() => _WorkspaceFrameState();
}

class _WorkspaceFrameState extends State<WorkspaceFrame>
    with SingleTickerProviderStateMixin {
  late final _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final _animation = CurvedAnimation(
    parent: _transition,
    curve: Curves.easeOutCubic,
  );
  static const labels = ['Today', 'Journal', 'Goals', 'Assistant'];
  static const icons = [
    Icons.wb_sunny_outlined,
    Icons.auto_stories_outlined,
    Icons.flag_outlined,
    Icons.auto_awesome_outlined,
  ];
  @override
  void didUpdateWidget(covariant WorkspaceFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _transition.value = 1;
      } else {
        _transition.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _transition.dispose();
    super.dispose();
  }

  Widget brand() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8C77EC), AppPalette.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      const Flexible(
        child: Text(
          'LifeScript',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
            fontVariations: [FontVariation('wght', 700)],
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 880;
      final animation = _animation;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                Container(
                  key: const ValueKey('desktop-sidebar'),
                  width: 224,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: AppPalette.line)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              brand(),
                              const SizedBox(height: 36),
                              const Padding(
                                padding: EdgeInsets.only(left: 14, bottom: 14),
                                child: Text(
                                  'YOUR WORKSPACE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.muted,
                                  ),
                                ),
                              ),
                              for (var i = 0; i < labels.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Semantics(
                                    selected: widget.index == i,
                                    button: true,
                                    child: AnimatedContainer(
                                      duration:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 180),
                                      decoration: BoxDecoration(
                                        color: widget.index == i
                                            ? AppPalette.lavender
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 5,
                                            ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        leading: Icon(
                                          icons[i],
                                          size: 21,
                                          color: widget.index == i
                                              ? AppPalette.primary
                                              : AppPalette.muted,
                                        ),
                                        title: Text(
                                          labels[i],
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: widget.index == i
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: widget.index == i
                                                ? AppPalette.primary
                                                : AppPalette.muted,
                                          ),
                                        ),
                                        trailing: widget.index == i
                                            ? const Icon(
                                                Icons.circle,
                                                size: 5,
                                                color: AppPalette.primary,
                                              )
                                            : null,
                                        onTap: () => widget.onSelect(i),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => widget.onSelect(1),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('New entry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F5FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.spa_outlined,
                                color: AppPalette.primary,
                                size: 24,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Small steps.\nReal progress.',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'A little space to think,\nand a clear next step.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.6,
                                  color: AppPalette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 32 : 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppPalette.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (!wide)
                            brand()
                          else
                            Expanded(
                              child: Row(
                                children: [
                                  const Text(
                                    'Your space',
                                    style: TextStyle(
                                      color: AppPalette.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: AppPalette.muted,
                                      size: 14,
                                    ),
                                  ),
                                  Text(
                                    labels[widget.index],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ...widget.actions,
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, .018),
                                end: Offset.zero,
                              ).animate(animation),
                              child: IndexedStack(
                                index: widget.index,
                                children: [
                                  for (var i = 0; i < widget.pages.length; i++)
                                    TickerMode(
                                      enabled: widget.index == i,
                                      child: widget.pages[i],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : Container(
                key: const ValueKey('mobile-navigation'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: AppPalette.line)),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: .04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: widget.index,
                  onDestinationSelected: widget.onSelect,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(
                        icon: Icon(icons[i], size: 22),
                        label: labels[i],
                      ),
                  ],
                ),
              ),
      );
    },
  );
}
