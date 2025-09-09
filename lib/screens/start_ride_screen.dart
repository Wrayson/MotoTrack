import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/main_provider.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/right_quad.dart';

class StartRideScreen extends StatefulWidget {
  const StartRideScreen({super.key});

  @override
  State<StartRideScreen> createState() => _StartRideScreenState();
}

class _StartRideScreenState extends State<StartRideScreen> {
  @override
  void initState() {
    super.initState();
    // Querformat einrasten, UI-Ränder freigeben
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    // Orientierung zurücksetzen (Provider kümmert sich um Streams)
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
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
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Speichern')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, mp, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Live Performance Tracker'),
            automaticallyImplyLeading: !mp.recording,
          ),

          body: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: SpeedGauge(speedKmh: mp.speedKmh, maxKmh: 140),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FittedBox(
                      alignment: Alignment.topLeft,
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 560,
                        height: 340,
                        child: RightQuad(
                          leanDeg: mp.leanDeg,
                          gForce: mp.gForce,
                          cornerDur: mp.cornerDur,
                          elapsed: mp.elapsed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                        icon: Icon(mp.recording ? Icons.stop : Icons.play_arrow),
                        label: Text(mp.recording ? 'Fahrt beenden' : 'Fahrt starten'),
                        onPressed: () async {
                          if (mp.recording) {
                            final name = await _askForName(context);
                            await mp.stopRecording(save: true, customTitle: name);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fahrt gespeichert.')),
                              );
                            }
                          } else {
                            final ok = await mp.startRecording();
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Standortberechtigung erforderlich.'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (mp.recording)
                      OutlinedButton(
                        onPressed: () => mp.discardRecording(),
                        child: const Text('Verwerfen'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
