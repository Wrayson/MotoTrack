import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MainProvider extends ChangeNotifier {
  // Status/Time
  bool _recording = false;
  DateTime? _startTime;
  DateTime? _endTime;
  Duration _elapsed = Duration.zero;
  Timer? _uiTimer;

  // Live Metrics
  double _speedKmh = 0;
  double _gForce = 0;
  double _leanDeg = 0;
  Duration _cornerDur = Duration.zero;

  // Maxima/Highest Statistics
  double _maxSpeed = 0;
  double _maxG = 0;
  double _maxLean = 0;
  Duration _longestCorner = Duration.zero;

  // Streams/Timer
  StreamSubscription<Position>? _posSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  Timer? _sampler;
  Position? _lastPos;

  static const Duration _sampleEvery = Duration(milliseconds: 250); // 4 Hz

  // Public Getter
  bool get recording => _recording;
  Duration get elapsed => _elapsed;

  double get speedKmh => _speedKmh;
  double get gForce => _gForce;
  double get leanDeg => _leanDeg;
  Duration get cornerDur => _cornerDur;

  double get maxSpeed => _maxSpeed;
  double get maxG => _maxG;
  double get maxLean => _maxLean;
  Duration get longestCorner => _longestCorner;

  // Lifecycle
  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }

  // Start/Stop API
  Future<bool> startRecording() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return false;

    _recording = true;
    _startTime = DateTime.now();
    _endTime = null;
    _elapsed = Duration.zero;
    _cornerDur = Duration.zero;
    _maxSpeed = _maxG = _maxLean = 0;
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
      final ts = pos.timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;

      if (prev != null && prevTs != null) {
        final dt = (ts - prevTs!) / 1000.0;
        if (dt > 0) {
          final d = _haversineMeters(
              prev!.latitude, prev!.longitude, pos.latitude, pos.longitude);
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

    // Accelerometer-Stream
    _accSub?.cancel();
    _accSub = accelerometerEventStream().listen((acc) {
      final g =
          math.sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z) / 9.81;
      _gForce = g;
      if (g > _maxG) _maxG = g;

      // Calculate Lean-Angle in Rad
      // acc.y = seitliche Beschleunigung
      // acc.z = vertikale Beschleunigung (Schwerkraft)
      // atan2 gibt den Winkel zwischen -π und +π zurück.
      final leanRad = math.atan2(acc.y, acc.z);

      // +deg = Lean to the Right
      // -deg = Lean to the left
      final leanDegSigned = (leanRad * 180 / math.pi);
      _leanDeg = leanDegSigned;
      if (leanDegSigned.abs() > _maxLean) {
        _maxLean = leanDegSigned.abs();
      }

      notifyListeners();
    });

    // Sampler: Corner-Dauer
    _sampler?.cancel();
    _sampler = Timer.periodic(_sampleEvery, (_) {
      //final inCorner = _leanDeg >= 25.0;
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

  // Stops the recording when save = true. Recording will be sent to Firestore.
  Future<void> stopRecording({required bool save, String? customTitle}) async {
    if (!_recording) return;

    _recording = false;
    _uiTimer?.cancel();
    _sampler?.cancel();
    await _posSub?.cancel();
    await _accSub?.cancel();

    if (_cornerDur > _longestCorner) _longestCorner = _cornerDur;
    _endTime = DateTime.now();

    // Dialogue for Custom Title
    if (save && _startTime != null && _endTime != null) {
      //Check if a custom Title was set
      final title = (customTitle == null || customTitle.trim().isEmpty)
        // If no Custom Title, set 'default' naming scheme with Date
          ? 'Fahrt ${fmtDateTime(_startTime!.millisecondsSinceEpoch)}'
          : customTitle.trim();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ridesCol = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('rides');

      // Calculate Duration
      final durationMs =
          _endTime!.millisecondsSinceEpoch - _startTime!.millisecondsSinceEpoch;

      // Add Ride Details to Recording
      await ridesCol.add({
        'title': title,
        'date': _fmtDate(_startTime!),
        'startedAt': _startTime!.millisecondsSinceEpoch,
        'endedAt': _endTime!.millisecondsSinceEpoch,
        'duration': _fmtDur(Duration(milliseconds: durationMs)),
        'highestSpeedKmh': _round(_maxSpeed, 2),
        'highestLeanDeg': _round(_maxLean, 1),
        'highestG': _round(_maxG, 3),
        'longestCornerSec':
        (_longestCorner.inMilliseconds / 1000.0).toStringAsFixed(1),
        'createdAt': _endTime!.millisecondsSinceEpoch,
      });
    }

    notifyListeners();
  }

  // Discard Recording
  Future<void> discardRecording() async {
    if (!_recording) return;
    await stopRecording(save: false);
  }

  // Stop all Subscriptions when Stream ends
  void _stopStreams() {
    _uiTimer?.cancel();
    _sampler?.cancel();
    _posSub?.cancel();
    _accSub?.cancel();
  }

  // Ask for Location-Permissions
  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  // Build Duration String
  String _fmtDur(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // Build Date String
  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd.$mo.$y';
  }

  // Format unix timestamp into readable format
    String fmtDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mo.$y $hh:$mm'; // Return European format, dd.mo.YYYY hh:mm
  }

  // Rounds number (v) to a defined amount of digits (digits)
  double _round(double v, int digits) => double.parse(v.toStringAsFixed(digits));

  // Convert degrees (d) to rad using trigonometry
  // 180° = π rad
  double _deg2rad(double d) => d * (math.pi / 180.0);

  // Calculate distance between two GPS-Coordinates
  // Formula:
  //   a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)
  //   c = 2 * atan2(√a, √(1-a))
  //   d = R * c   (R = Earthradius in Meters)
  double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // Returns the rides collection for the currently signed-in user
  // NOTE: Assumes user is logged in (as in the rest of your code).
  CollectionReference<Map<String, dynamic>> _userRidesCol() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rides');
  }

  // Public stream for the ride list (ordered by 'createdAt' descending)
  // Used by HistoryRideScreen to render the list reactively.
  Stream<QuerySnapshot<Map<String, dynamic>>> get ridesStream {
    return _userRidesCol()
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Returns a single ride document (for a detail screen, if needed elsewhere)
  Future<DocumentSnapshot<Map<String, dynamic>>> getRide(String rideId) {
    return _userRidesCol().doc(rideId).get();
  }

  // Deletes a ride by id (used by HistoryRideScreen + RideDetailScreen)
  Future<void> deleteRide(String rideId) async {
    await _userRidesCol().doc(rideId).delete();
  }

  // (Optional) Update a ride title – handy if you add "rename" later
  Future<void> renameRide(String rideId, String newTitle) async {
    await _userRidesCol().doc(rideId).update({'title': newTitle.trim()});
  }

// Live stream of a single ride (detail screen can auto-update on changes)
  Stream<DocumentSnapshot<Map<String, dynamic>>> rideStream(String rideId) {
    return _userRidesCol().doc(rideId).snapshots();
  }


}
