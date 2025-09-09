import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'history_ride_screen.dart';
import 'start_ride_screen.dart';

class HomeMenuScreen extends StatelessWidget {
  const HomeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MotoTrack'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _bigAction(
              context,
              icon: Icons.play_circle_fill,
              label: 'Fahrt starten',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StartRideScreen()));
              },
            ),
            const SizedBox(height: 16),
            _bigAction(
              context,
              icon: Icons.history,
              label: 'Fahrthistorie anzeigen',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HistoryRideScreen()));
              },
            ),
            const Spacer(),
            Text('Ready to ride?', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }

  Widget _bigAction(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
        onPressed: onTap,
      ),
    );
  }
}
