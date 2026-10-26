import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class Reveal extends StatelessWidget {
  final Widget child;
  const Reveal({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class LiftCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const LiftCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  State<LiftCard> createState() => _LiftCardState();
}

class _LiftCardState extends State<LiftCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: widget.padding,
      transform: Matrix4.translationValues(
        0,
        _hover && !MediaQuery.disableAnimationsOf(context) ? -3 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _hover ? const Color(0xFFD2C9F6) : AppPalette.line,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.ink.withValues(alpha: _hover ? .06 : .025),
            blurRadius: _hover ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: widget.child,
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = AppPalette.primary});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      color: color,
    ),
  );
}

class PageIntro extends StatelessWidget {
  final String eyebrow, title, description;
  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) => Reveal(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.lavender,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 28, color: AppPalette.primary),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class FocusArt extends StatelessWidget {
  const FocusArt({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(painter: _FocusPainter()),
    ),
  );
}

class _FocusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppPalette.primary.withValues(alpha: .18);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 160, height: 75),
      p,
    );
    canvas.rotate(1.1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 160, height: 75),
      p,
    );
    canvas.restore();
    p
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: .8);
    canvas.drawCircle(center, 48, p);
    p.color = AppPalette.primary;
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? 30.0 : 10.0;
      final point =
          center +
          Offset(math.cos(i * math.pi / 4) * r, math.sin(i * math.pi / 4) * r);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, p);
    p.color = const Color(0xFF9AC7B9);
    canvas.drawCircle(center + const Offset(57, -50), 12, p);
    p.color = const Color(0xFFE6B58A);
    canvas.drawCircle(center + const Offset(-62, 42), 7, p);
    p.color = AppPalette.primary.withValues(alpha: .4);
    canvas.drawCircle(center + const Offset(-65, -50), 4, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

EdgeInsets pagePadding(BuildContext context) =>
    EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 32);
