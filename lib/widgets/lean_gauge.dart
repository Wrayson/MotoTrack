import 'dart:math' as math;
import 'package:flutter/material.dart';

class LeanGauge extends StatelessWidget {
  final double deg;            // aktueller Lean (0..~60+)
  final double maxLeanDeg;     // Skalenmaximum
  const LeanGauge({super.key, required this.deg, this.maxLeanDeg = 60.0});

  @override
  Widget build(BuildContext context) {
    final val = deg.isFinite ? deg.clamp(0, maxLeanDeg).toDouble() : 0.0;
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: val / maxLeanDeg,
                strokeWidth: size * 0.08,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Lean'),
                Text(
                  '${val.toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
