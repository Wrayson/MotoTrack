import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Halbkreis-Gauge ohne Nadel:
///  - Wertebereich: [-maxLeanDeg, +maxLeanDeg]
///  - 0° ist oben in der Mitte
///  - positiver Lean (rechts) füllt den Bogen von oben nach rechts,
///    negativer Lean (links) füllt den Bogen von oben nach links.
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

  // Mappt -max..0..+max auf Winkel:
  // links = π, oben = π/2, rechts = 0   (Canvas-Winkelrichtung im Uhrzeigersinn)
  double _angleForDeg(double d) {
    final t = (d / maxDeg).clamp(-1.0, 1.0); // -1..1
    return math.pi - (math.pi / 2) * (t + 1); // -1 -> π, 0 -> π/2, +1 -> 0
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1) Hintergrund-Track (oberer Halbkreis)
    final track = Paint()
      ..color = colorTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Halbkreis von links (π) nach rechts (0) über oben
    canvas.drawArc(rect, math.pi, -math.pi, false, track); // -π = gegen 0 im Uhrzeigersinn

    // 2) Füllbogen je nach Vorzeichen (Start ist immer 0°-Punkt = oben -> π/2)
    final startAtTop = math.pi / 2; // oben
    final aVal = _angleForDeg(valueDeg); // Zielwinkel

    // Sweep berechnen relativ zu oben
    // positiver Wert: aVal ∈ [0, π/2) => sweep negativ (im Uhrzeigersinn nach rechts)
    // negativer Wert: aVal ∈ (π/2, π] => sweep positiv (gegen Uhrzeigersinn nach links)
    final sweep = aVal - startAtTop;

    if (sweep != 0) {
      final paintFill = Paint()
        ..color = (valueDeg >= 0) ? colorPos : colorNeg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAtTop, sweep, false, paintFill);
    }

    void drawLabel(String text, Offset pos) {
      final span = TextSpan(
        text: text,
        style: TextStyle(color: colorText, fontSize: stroke * 0.35),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

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
