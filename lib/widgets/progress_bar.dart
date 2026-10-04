import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Chiziqli progress (6–8 px, to'liq yumaloq).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 6, this.color, this.track});

  final double value;
  final double height;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track ?? c.line)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                child: ColoredBox(color: color ?? c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ustunli diagramma (haftalik / kunlik). Bugungi ustun asosiy rangda.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 70,
    this.highlight,
    this.radius = 5,
    this.gap = 7,
    this.showValues = false,
  });

  final List<int> values;
  final List<String> labels;
  final double height;
  final int? highlight;
  final double radius;
  final double gap;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxV = max(1, values.fold<int>(0, max));
    return Semantics(
      label: [for (var i = 0; i < values.length; i++) '${labels[i]}: ${values[i]}'].join(', '),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showValues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(values[i] == 0 ? '' : '${values[i]}',
                            style: T.text(9, color: c.sec, w: FontWeight.w600)),
                      ),
                    SizedBox(
                      height: height,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: values[i] == 0 ? 0.06 : max(0.1, values[i] / maxV)),
                          duration: Duration(milliseconds: 350 + i * 40),
                          curve: Curves.easeOutCubic,
                          builder: (_, f, _) => Container(
                            height: height * f,
                            decoration: BoxDecoration(
                              color: i == highlight ? c.accent : c.line,
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(labels[i], style: T.text(10, color: i == highlight ? c.ink : c.sec,
                        w: i == highlight ? FontWeight.w600 : FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gorizontal taqsimot qatori: "Yangi ▬▬▬ 148".
class DistributionRow extends StatelessWidget {
  const DistributionRow({super.key, required this.label, required this.value, required this.total, required this.color});

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(width: 62, child: Text(label, style: T.text(11, color: c.sec))),
        const SizedBox(width: 10),
        Expanded(child: ProgressBar(value: total == 0 ? 0 : value / total, height: 8, color: color)),
        const SizedBox(width: 10),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right, style: T.text(11, color: c.sec))),
      ],
    );
  }
}

/// Doiraviy qolgan vaqt indikatori ("Ortga qaytarish" tugmasi atrofida).
class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.until, required this.total, required this.child, this.size = 42});

  final DateTime until;
  final Duration total;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final left = until.difference(DateTime.now());
    final start = (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      key: ValueKey(until),
      tween: Tween(begin: start, end: 0),
      duration: left.isNegative ? Duration.zero : left,
      builder: (_, v, child) => CustomPaint(
        foregroundPainter: _RingPainter(v, c.accent),
        child: child,
      ),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color);

  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (v <= 0) return;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)).deflate(1);
    final path = Path()..addRRect(r);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(metric.extractPath(0, metric.length * v), paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}
