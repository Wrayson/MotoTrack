import 'package:flutter/material.dart';
import 'metric_card.dart';
import 'gforce_gauge.dart';
import 'lean_gauge_bidir.dart';

class RightQuad extends StatelessWidget {
  final double leanDeg;
  final double gForce;
  final Duration cornerDur;
  final Duration elapsed;

  const RightQuad({
    super.key,
    required this.leanDeg,
    required this.gForce,
    required this.cornerDur,
    required this.elapsed,
  });

  String _fmtDur(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: LeanGaugeBidirectionalArc(deg: leanDeg, maxLeanDeg: 60)),
              const SizedBox(width: 12),
              Expanded(child: GForceGauge(g: gForce)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Kurve (≥25°)',
                  value: '${(cornerDur.inMilliseconds / 1000.0).toStringAsFixed(1)} s',
                  icon: Icons.timeline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Fahrzeit',
                  value: _fmtDur(elapsed),
                  icon: Icons.timer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
