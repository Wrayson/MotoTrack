import 'dart:math' as math;
import 'package:flutter/material.dart';

class GForceGauge extends StatelessWidget {
  final double g;
  final double maxG;
  const GForceGauge({super.key, required this.g, this.maxG = 2.0});

  @override
  Widget build(BuildContext context) {
    final val = g.isFinite ? g.clamp(0, maxG).toDouble() : 0.0;
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
                value: val / maxG,
                strokeWidth: size * 0.08,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('G-Force'),
                Text(
                  val.toStringAsFixed(2),
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
