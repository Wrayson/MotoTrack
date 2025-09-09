import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Halbkreis-Gauge ohne Nadel:
///  - Wertebereich: [-maxLeanDeg, +maxLeanDeg]
///  - 0° ist UNTEN in der Mitte (fahrerfreundliche Darstellung)
///  - positiver Lean (rechts) füllt den Bogen von unten nach rechts,
///    negativer Lean (links) füllt den Bogen von unten nach links.
class LeanGaugeBidirectionalArc extends StatelessWidget {
  final double deg;            // signed: z. B. -32.4 .. +32.4
  final double maxLeanDeg;     // Skalenmaximum, z. B. 60°
  const LeanGaugeBidirectionalArc({
    super.key,
    required this.deg,
    this.maxLeanDeg = 60,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = deg.isFinite ? deg.clamp(-maxLeanDeg, maxLeanDeg).toDouble() : 0.0;

    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight);
      final stroke = size * 0.08;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: CustomPaint(
          size: Size.square(size),
          painter: _LeanArcPainter(
            valueDeg: clamped,
            maxDeg: maxLeanDeg,
            stroke: stroke,
            colorTrack: theme.colorScheme.outlineVariant,
            colorPos: theme.colorScheme.primary,   // > 0° (rechts)
            colorNeg: theme.colorScheme.tertiary,  // < 0° (links)
            colorText: theme.colorScheme.onSurface,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Lean'),
                Text(
                  '${clamped.toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _LeanArcPainter extends CustomPainter {
  final double valueDeg;   // signed
  final double maxDeg;
  final double stroke;
  final Color colorTrack;
  final Color colorPos;    // positive Seite (rechts)
  final Color colorNeg;    // negative Seite (links)
  final Color colorText;

  _LeanArcPainter({
    required this.valueDeg,
    required this.maxDeg,
    required this.stroke,
    required this.colorTrack,
    required this.colorPos,
    required this.colorNeg,
    required this.colorText,
  });

  // Mapping für UNTEREN Halbkreis:
  // -max -> π (links), 0 -> π/2 (unten), +max -> 0 (rechts)
  double _angleForDeg(double d) {
    final t = (d / maxDeg).clamp(-1.0, 1.0); // -1..1
    return math.pi - (math.pi / 2) * (t + 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1) Hintergrund-Track = UNTERER Halbkreis (0..π)
    final track = Paint()
      ..color = colorTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, math.pi, false, track); // 0..π = unterer Halbkreis

    // 2) Füllbogen startet Unten (π/2) und läuft je nach Vorzeichen
    final startAtBottom = math.pi / 2; // unten
    final aVal = _angleForDeg(valueDeg);
    final sweep = aVal - startAtBottom; // >0: im Uhrzeigersinn (nach links), <0: gegen Uhrzeigersinn (nach rechts)

    if (sweep != 0) {
      final paintFill = Paint()
        ..color = (valueDeg >= 0) ? colorPos : colorNeg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAtBottom, sweep, false, paintFill);
    }

    // (Optional) Ticks/Labels – bei Bedarf entfernen
    final tickPaint = Paint()
      ..color = colorText.withOpacity(0.6)
      ..strokeWidth = 2;
    void drawTick(double d) {
      final a = _angleForDeg(d);
      final dir = Offset(math.cos(a), math.sin(a));
      final inner = center + dir * (radius - stroke * 0.6);
      final outer = center + dir * (radius + stroke * 0.1);
      canvas.drawLine(inner, outer, tickPaint);
    }
    drawTick(-maxDeg);
    drawTick(0);
    drawTick(maxDeg);

    final labelStyle = TextStyle(color: colorText, fontSize: stroke * 0.35);
    void drawLabel(String text, Offset pos) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    drawLabel('-${maxDeg.toStringAsFixed(0)}°', center + Offset(-radius, 0));
    drawLabel('0°', center + Offset(0, radius + stroke * 0.2));
    drawLabel('+${maxDeg.toStringAsFixed(0)}°', center + Offset(radius, 0));
  }

  @override
  bool shouldRepaint(covariant _LeanArcPainter old) =>
      old.valueDeg != valueDeg ||
          old.maxDeg != maxDeg ||
          old.stroke != stroke ||
          old.colorTrack != colorTrack ||
          old.colorPos != colorPos ||
          old.colorNeg != colorNeg ||
          old.colorText != colorText;
}
