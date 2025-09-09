import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MainProvider extends ChangeNotifier {
  // ----------- Status / Zeiten -----------
  bool _recording = false;
  DateTime? _startTime;
  DateTime? _endTime;
  Duration _elapsed = Duration.zero;
  Timer? _uiTimer;

  // ----------- Live-Metriken -----------
  double _speedKmh = 0;
  double _gForce = 0;

  /// Lean (signed): <0 = LINKS, >0 = RECHTS
  double _leanDeg = 0;

  Duration _cornerDur = Duration.zero;

  // ----------- Maxima -----------
  double _maxSpeed = 0;
  double _maxG = 0;
  /// Max Lean als Betrag (|lean|)
  double _maxLean = 0;
  Duration _longestCorner = Duration.zero;

  // ----------- Streams / Timer -----------
  StreamSubscription<Position>? _posSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  Timer? _sampler;
  Position? _lastPos;

  static const Duration _sampleEvery = Duration(milliseconds: 250); // 4 Hz

  /// Falls deine Halterung die Richtung spiegelt, setze das auf true.
  bool _invertLean = false;

  // ----------- Public Getter -----------
  bool get recording => _recording;
  Duration get elapsed => _elapsed;

  double get speedKmh => _speedKmh;
  double get gForce => _gForce;
  double get leanDeg => _leanDeg; // signed
  Duration get cornerDur => _cornerDur;

  double get maxSpeed => _maxSpeed;
  double get maxG => _maxG;
  double get maxLean => _maxLean;
  Duration get longestCorner => _longestCorner;

  bool get invertLean => _invertLean;

  // ----------- Lifecycle -----------
  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }

  // ----------- API: Start/Stop -----------
  Future<bool> startRecording() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return false;

    _recording = true;
    _startTime = DateTime.now();
    _endTime = null;
    _elapsed = Duration.zero;
    _cornerDur = Duration.zero;
    _maxSpeed = 0;
    _maxG = 0;
    _maxLean = 0;
    _longestCorner = Duration.zero;

    // UI-Timer (Stoppuhr)
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_recording || _startTime == null) return;
      _elapsed = DateTime.now().difference(_startTime!);
      notifyListeners();
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
            vMs = 0.7 * vMs + 0.3 * vCalc; // leichte Glättung
          }
        }
      }
      prev = pos;
      prevTs = ts;

      _speedKmh = (vMs.isFinite ? vMs : 0.0) * 3.6;
      if (_speedKmh > _maxSpeed) _maxSpeed = _speedKmh;

      notifyListeners();
    });

    // Accelerometer-Stream (signed Lean, deterministisch über X/Z)
    _accSub?.cancel();
    _accSub = accelerometerEventStream().listen((acc) {
      // g-Force (Betrag)
      final g = math.sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z) / 9.81;
      _gForce = g;
      if (g > _maxG) _maxG = g;

      // ---- Lean-Bestimmung: NUR X vs Z, mit definierter Richtung ----
      // Landscape-Mount: Roll ist primär die X-Achse (links/rechts).
      // Wir definieren: Rechts kippen => positiver Lean.
      // Dafür funktioniert in der Praxis: lean = -atan2(x, z).
      double leanRad = -math.atan2(acc.x, acc.z);

      // Optional Vorzeichen invertieren, falls Halterung spiegelverkehrt
      if (_invertLean) leanRad = -leanRad;

      // In Grad
      _leanDeg = leanRad * 180.0 / math.pi;

      // Maxima als Betrag
      final absLean = _leanDeg.abs();
      if (absLean > _maxLean) _maxLean = absLean;

      notifyListeners();
    });

    // Sampler: Corner-Dauer (Schwelle 25°; Betrag vergleichen)
    _sampler?.cancel();
    _sampler = Timer.periodic(_sampleEvery, (_) {
      final inCorner = _leanDeg.abs() >= 25.0;
      if (inCorner) {
        _cornerDur += _sampleEvery;
      } else {
        if (_cornerDur > _longestCorner) _longestCorner = _cornerDur;
        _cornerDur = Duration.zero;
      }
      notifyListeners();
    });

    notifyListeners();
    return true;
  }

  /// Stoppt die Aufnahme. Wenn [save] true ist, wird an Firestore gespeichert.
  /// [customTitle] kann vom UI übergeben werden (Dialog).
  Future<void> stopRecording({required bool save, String? customTitle}) async {
    if (!_recording) return;

    _recording = false;
    _uiTimer?.cancel();
    _sampler?.cancel();
    await _posSub?.cancel();
    await _accSub?.cancel();

    if (_cornerDur > _longestCorner) _longestCorner = _cornerDur;
    _endTime = DateTime.now();

    if (save && _startTime != null && _endTime != null) {
      final title = (customTitle == null || customTitle.trim().isEmpty)
          ? 'Fahrt ${DateTime.now().toLocal()}'
          : customTitle.trim();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ridesCol = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('rides');

      final durationMs = _endTime!.millisecondsSinceEpoch - _startTime!.millisecondsSinceEpoch;

      await ridesCol.add({
        'title': title,
        'date': _fmtDate(_startTime!),
        'startedAt': _startTime!.millisecondsSinceEpoch,
        'endedAt': _endTime!.millisecondsSinceEpoch,
        'duration': _fmtDur(Duration(milliseconds: durationMs)),
        'highestSpeedKmh': _round(_maxSpeed, 2),
        'highestLeanDeg': _round(_maxLean, 1), // Betrag
        'highestG': _round(_maxG, 3),
        'longestCornerSec': (_longestCorner.inMilliseconds / 1000.0).toStringAsFixed(1),
        'createdAt': _endTime!.millisecondsSinceEpoch,
      });
    }

    notifyListeners();
  }

  Future<void> discardRecording() async {
    if (!_recording) return;
    await stopRecording(save: false);
  }

  void _stopStreams() {
    _uiTimer?.cancel();
    _sampler?.cancel();
    _posSub?.cancel();
    _accSub?.cancel();
  }

  // ----------- Utils -----------
  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

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

  // ----------- Optional: Richtung umschalten (falls nötig) -----------
  void toggleInvertLean() {
    _invertLean = !_invertLean;
    notifyListeners();
  }
}
