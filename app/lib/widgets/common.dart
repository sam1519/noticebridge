import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ------------------------------------------------------------------ helpers
Color urgencyColor(String u) {
  switch (u) {
    case 'high':
      return const Color(0xFFE5484D);
    case 'medium':
      return const Color(0xFFF5A524);
    default:
      return const Color(0xFF2FB67C);
  }
}

String urgencyShort(String u) => u == 'high' ? 'HIGH' : (u == 'medium' ? 'MID' : 'LESS');

String urgencyLabel(String u) => u == 'high' ? 'HIGH' : (u == 'medium' ? 'MID' : 'LESS');

IconData categoryIcon(String c) {
  switch (c) {
    case 'tax':
      return Icons.receipt_long;
    case 'bank':
      return Icons.account_balance;
    case 'college':
      return Icons.school;
    case 'legal':
      return Icons.gavel;
    case 'govt':
      return Icons.account_balance_outlined;
    case 'utility':
      return Icons.bolt;
    default:
      return Icons.description;
  }
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// --------------------------------------------------------------- background
/// Dark/light page background with soft accent glows in the corners.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(
      children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: p.bg))),
        Positioned(top: -140, right: -110, child: IgnorePointer(child: _Glow(color: p.accent, size: 360, opacity: p.dark ? 0.30 : 0.20))),
        Positioned(bottom: -160, left: -130, child: IgnorePointer(child: _Glow(color: p.accent, size: 320, opacity: p.dark ? 0.18 : 0.12))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [alpha(color, opacity), alpha(color, 0)]),
      ),
    );
  }
}

// -------------------------------------------------------------------- cards
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? p.card,
            borderRadius: r,
            border: Border.all(color: borderColor ?? p.line),
          ),
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Card with a coloured stripe on the left edge.
class StripeCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsets margin;
  const StripeCard({super.key, required this.color, required this.child, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: alpha(color, 0.10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: DefaultTextStyle.merge(style: TextStyle(color: p.text), child: child),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Titled card used for the sections inside a notice.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? accent;
  const SectionCard({super.key, required this.title, required this.icon, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = accent ?? p.accentText;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: alpha(c, 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: c),
            ),
            const SizedBox(width: 10),
            Text(title.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.1, color: p.muted)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ small widgets
class UrgencyBadge extends StatelessWidget {
  final String urgency;
  const UrgencyBadge(this.urgency, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = urgencyColor(urgency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: alpha(c, 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alpha(c, 0.55)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('${urgencyLabel(urgency)} URGENCY',
            style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      ]),
    );
  }
}

/// Fades and slides its child in. Higher index = slightly later.
class FadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlide({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final i = index < 0 ? 0 : (index > 8 ? 8 : index);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + i * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: ch),
      ),
      child: child,
    );
  }
}

/// Main call-to-action button with a soft glow.
class GlowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final enabled = onPressed != null && !loading;
    final r = BorderRadius.circular(18);
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.6,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(colors: [p.button, Color.lerp(p.button, p.accent, 0.5) ?? p.button]),
          boxShadow: [BoxShadow(color: alpha(p.accent, 0.38), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: r,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.onButton),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: p.onButton),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        style: TextStyle(color: p.onButton, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded selectable chip (languages etc).
class ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? alpha(p.accent, 0.20) : p.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? p.accent : p.line, width: selected ? 1.6 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[Icon(Icons.check_circle, size: 16, color: p.accentText), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

/// Sliding pill switch with 2-4 options.
class PillSelector<T> extends StatelessWidget {
  final List<MapEntry<T, String>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  const PillSelector({super.key, required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: options.map((o) {
          final sel = o.key == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(o.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? alpha(p.accent, 0.22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: sel ? alpha(p.accent, 0.7) : Colors.transparent),
                ),
                child: Center(
                  child: Text(o.value,
                      style: TextStyle(
                          fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w500, color: sel ? p.text : p.muted)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Big page title used at the top of each tab.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1)),
            ]),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.value, required this.label, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: alpha(color, 0.16), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.tooltip = ''});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.line)),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ custom paint
/// Circular gauge that fills according to urgency.
class UrgencyRing extends StatelessWidget {
  final String urgency;
  final double size;
  const UrgencyRing({super.key, required this.urgency, this.size = 90});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = urgencyColor(urgency);
    final target = urgency == 'high' ? 1.0 : (urgency == 'medium' ? 0.66 : 0.33);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, c, p.line),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(urgencyShort(urgency),
                  style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: size * 0.22)),
              Text('urgency', style: TextStyle(color: p.muted, fontSize: size * 0.12)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  _RingPainter(this.value, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// The NoticeBridge logo: an arch bridge that draws itself.
class BridgeLogo extends StatelessWidget {
  final double size;
  const BridgeLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(size, size * 0.62),
        painter: _BridgePainter(t, p.accentText, p.text),
      ),
    );
  }
}

class _BridgePainter extends CustomPainter {
  final double t;
  final Color accent;
  final Color ink;
  _BridgePainter(this.t, this.accent, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final deckY = h * 0.78;

    final deck = Paint()
      ..color = ink
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.0, deckY), Offset(w * t, deckY), deck);

    final arcPaint = Paint()
      ..color = accent
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arc = Path()
      ..moveTo(w * 0.08, deckY)
      ..quadraticBezierTo(w * 0.5, -h * 0.45, w * 0.92, deckY);
    for (final m in arc.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), arcPaint);
    }

    final thin = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 5; i++) {
      final u = i / 6;
      if (t < u) break;
      final x = w * (0.08 + 0.84 * u);
      final y = deckY * (1 - u) * (1 - u) + 2 * (1 - u) * u * (-h * 0.45) + deckY * u * u;
      canvas.drawLine(Offset(x, y), Offset(x, deckY), thin);
    }

    final dot = Paint()..color = accent;
    canvas.drawCircle(Offset(w * 0.08, deckY), 5, dot);
    if (t > 0.95) canvas.drawCircle(Offset(w * 0.92, deckY), 5, dot);
  }

  @override
  bool shouldRepaint(covariant _BridgePainter old) =>
      old.t != t || old.accent != accent || old.ink != ink;
}
