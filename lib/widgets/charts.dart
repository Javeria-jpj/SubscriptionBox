import 'dart:math';

import 'package:flutter/material.dart';

import 'package:subbox_app/theme.dart';

/// Simple charts drawn by hand (no chart package needed).

/// Ring chart: one colored arc per value, with a label in the middle.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.center,
    this.size = 170,
  });

  final List<double> values;
  final List<Color> colors;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(values, colors),
          child: Center(child: center),
        ),
      );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors);

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * pi, false, paint..color = AppColors.surfaceHigh);
      return;
    }
    // Small gap between segments when there is more than one.
    final gap = values.length > 1 ? 0.03 : 0.0;
    var start = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * pi;
      canvas.drawArc(rect, start + gap / 2, max(sweep - gap, 0.001), false,
          paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors;
}

/// Vertical bars with a label under each and the value on tap/hover.
/// [highlight] bars use the primary color, the rest are dimmed.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.highlight = const {},
    this.color = AppColors.primary,
    this.height = 160,
  });

  final List<double> values;
  final List<String> labels;
  final String Function(double) format;
  final Set<int> highlight;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = values.fold(0.0, max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Tooltip(
                message: '${labels[i]}: ${format(values[i])}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor:
                              top == 0 ? 0.02 : max(values[i] / top, 0.02),
                          widthFactor: 0.6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: highlight.isEmpty || highlight.contains(i)
                                  ? color
                                  : color.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i],
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal progress bar showing [value] out of [max].
class MeterBar extends StatelessWidget {
  const MeterBar(
      {super.key, required this.value, required this.max, required this.color});

  final double value, max;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: max == 0 ? 0 : value / max,
          minHeight: 6,
          color: color,
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
}
