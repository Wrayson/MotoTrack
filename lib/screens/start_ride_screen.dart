// lib/screens/start_ride_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Widgets
import '../widgets/speed_gauge.dart';
import '../widgets/right_quad.dart';

class StartRideScreen extends StatefulWidget {
  const StartRideScreen({super.key});

  @override
  State<StartRideScreen> createState() => _StartRideScreenState();
}

class _StartRideScreenState extends State<StartRideScreen> {
  // Aufnahme-Status
  bool _recording = false;
  DateTime? _startTime;
  DateTime? _endTime;
  Duration _elapsed = Duration.zero;
  Timer? _uiTimer;

  // Live-Metriken
  double _speedKmh = 0;     // aus GPS (oder berechnet)
  double _gForce = 0;       // aus Accelerometer (Betrag in g)
  double _leanDeg = 0;      // vereinfachte Roll-Schätzung
  Duration _cornerDur = Duration.zero; // aktuelle Kurve (>=25°)

  // Maxima
  double _maxSpeed = 0;
  double _maxG = 0;
  double _maxLean = 0;
  Duration _longestCorner = Duration.zero;

  // Streams
  StreamSubscription<Position>? _posSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  Timer? _sampler;
  Position? _lastPos;

  static const Duration _sampleEvery = Duration(milliseconds: 250); // 4 Hz

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _stopRecording(save: false);
    _uiTimer?.cancel();
    _sampler?.cancel();
    _posSub?.cancel();
    _accSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // -------------------- Aufnahme-Logik --------------------

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

  Future<void> _startRecording() async {
    final ok = await _ensureLocationPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standortberechtigung erforderlich.')),
        );
      }
      return;
    }

    _recording = true;
    _startTime = DateTime.now();
    _endTime = null;
    _elapsed = Duration.zero;
    _cornerDur = Duration.zero;
    _maxSpeed = _maxG = _maxLean = 0;
    _longestCorner = Duration.zero;

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_recording || _startTime == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });

    // GPS-Stream
    _posSub?.cancel();
    Position? prev;
    int? prevTs;
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      _lastPos = pos;
      double vMs = (pos.speed.isFinite && pos.speed > 0) ? pos.speed : 0.0;
      final ts = pos.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
      if (prev != null && prevTs != null) {
        final dt = (ts - prevTs!) / 1000.0;
        if (dt > 0) {
          final d = _haversineMeters(prev!.latitude, prev!.longitude, pos.latitude, pos.longitude);
          final vCalc = d / dt;
          if (!(vMs > 0)) {
            vMs = 0.7 * vMs + 0.3 * vCalc;
          }
        }
      }
      prev = pos;
      prevTs = ts;

      _speedKmh = (vMs.isFinite ? vMs : 0.0) * 3.6;
      if (_speedKmh > _maxSpeed) _maxSpeed = _speedKmh;

      setState(() {});
    });

    // Accelerometer-Stream
    _accSub?.cancel();
    _accSub = accelerometerEventStream().listen((acc) {
      final g = math.sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z) / 9.81;
      _gForce = g;
      if (g > _maxG) _maxG = g;

      // Lean quer (links/rechts): ay vs az
      final leanRad = math.atan2(acc.y, acc.z);
      _leanDeg = (leanRad.abs() * 180 / math.pi);
      if (_leanDeg > _maxLean) _maxLean = _leanDeg;

      setState(() {});
    });

    // Sampler: nur Corner-Dauer
    _sampler?.cancel();
    _sampler = Timer.periodic(_sampleEvery, (_) {
      final inCorner = _leanDeg >= 25.0;
      if (inCorner) {
        _cornerDur += _sampleEvery;
      } else {
        if (_cornerDur > _longestCorner) _longestCorner = _cornerDur;
        _cornerDur = Duration.zero;
      }
      setState(() {});
    });

    setState(() {});
  }

  Future<void> _stopRecording({required bool save}) async {
    if (!_recording) return;

    _recording = false;
    _uiTimer?.cancel();
    _sampler?.cancel();
    await _posSub?.cancel();
    await _accSub?.cancel();

    if (_cornerDur > _longestCorner) _longestCorner = _cornerDur;
    _endTime = DateTime.now();

    if (save && _startTime != null && _endTime != null) {
      final String? name = await _askForName(context);
      final title = (name == null || name.trim().isEmpty)
          ? 'Fahrt ${DateTime.now().toLocal()}'
          : name.trim();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ridesCol =
      FirebaseFirestore.instance.collection('users').doc(uid).collection('rides');

      final durationMs = _endTime!.millisecondsSinceEpoch - _startTime!.millisecondsSinceEpoch;

      await ridesCol.add({
        'title': title,
        'date': _fmtDate(_startTime!),
        'startedAt': _startTime!.millisecondsSinceEpoch,
        'endedAt': _endTime!.millisecondsSinceEpoch,
        'duration': _fmtDur(Duration(milliseconds: durationMs)),
        'highestSpeedKmh': _round(_maxSpeed, 2),
        'highestLeanDeg': _round(_maxLean, 1),
        'highestG': _round(_maxG, 3),
        'longestCornerSec': (_longestCorner.inMilliseconds / 1000.0).toStringAsFixed(1),
        'createdAt': _endTime!.millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fahrt gespeichert.')),
        );
      }
    }

    setState(() {});
  }

  // -------------------- Helpers --------------------

  String _fmtDur(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final da = dt.day.toString().padLeft(2, '0');
    return '$y-$mo-$da';
  }

  double _round(double v, int digits) => double.parse(v.toStringAsFixed(digits));
  double _deg2rad(double d) => d * (math.pi / 180.0);

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Future<String?> _askForName(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fahrtnamen eingeben'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'z. B. Nachmittagsrunde über den Pass',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Speichern')),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Performance Tracker'),
        automaticallyImplyLeading: !_recording,
      ),

      // ⬇️ nur dein Inhalt, ohne Buttons/Stack
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SpeedGauge(speedKmh: _speedKmh, maxKmh: 140),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  alignment: Alignment.topLeft,
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 560,
                    height: 340,
                    child: RightQuad(
                      leanDeg: _leanDeg,
                      gForce: _gForce,
                      cornerDur: _cornerDur,
                      elapsed: _elapsed,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ⬇️ Buttons unten – haben immer Abstand, schneiden nie ins UI
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(_recording ? Icons.stop : Icons.play_arrow),
                    label: Text(_recording ? 'Fahrt beenden' : 'Fahrt starten'),
                    onPressed: () async {
                      if (_recording) {
                        await _stopRecording(save: true);
                      } else {
                        await _startRecording();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (_recording)
                  OutlinedButton(
                    onPressed: () => _stopRecording(save: false),
                    child: const Text('Verwerfen'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
