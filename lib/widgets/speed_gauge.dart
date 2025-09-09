import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpeedGauge extends StatelessWidget {
  final double speedKmh;
  final double maxKmh;
  const SpeedGauge({super.key, required this.speedKmh, this.maxKmh = 140});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight) * 0.92;
      final v = speedKmh.clamp(0, maxKmh);
      final frac = v / maxKmh;

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: frac,
                strokeWidth: size * 0.07,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('km/h', style: TextStyle(fontSize: 16)),
                  Text(
                    v.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: size * 0.27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
