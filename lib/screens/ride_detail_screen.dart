import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RideDetailScreen extends StatelessWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('rides').doc(rideId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrtdetails'),
        actions: [
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Fahrt löschen?'),
                  content: const Text('Diese Fahrt wird dauerhaft entfernt. Fortfahren?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                    FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await docRef.delete();
                  if (context.mounted) {
                    Navigator.pop(context); // zurück zur Liste
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fahrt gelöscht.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: docRef.get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Fahrt nicht gefunden.'));
          }

          final data = snap.data!.data()!;
          final title = (data['title'] as String?) ?? 'Fahrt';
          final dateStr = (data['date'] as String?) ?? '';
          final startedAt = (data['startedAt'] as num?)?.toInt();
          final endedAt = (data['endedAt'] as num?)?.toInt();
          final duration = (data['duration'] as String?) ?? '';

          final maxSpeed = (data['highestSpeedKmh'] as num?)?.toDouble() ?? 0.0;
          final maxLean = (data['highestLeanDeg'] as num?)?.toDouble() ?? 0.0;
          final maxG = (data['highestG'] as num?)?.toDouble() ?? 0.0;
          final longestCornerSec = (data['longestCornerSec'] as String?) ?? '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dateStr.isNotEmpty) Chip(label: Text('Datum: $dateStr')),
                    if (duration.isNotEmpty) Chip(label: Text('Dauer: $duration')),
                    if (startedAt != null) Chip(label: Text('Start: ${_fmtDateTime(startedAt)}')),
                    if (endedAt != null) Chip(label: Text('Ende: ${_fmtDateTime(endedAt)}')),
                  ],
                ),
                const SizedBox(height: 16),
                _StatGrid(
                  items: [
                    _StatTileData(label: 'Highest Speed', value: '${maxSpeed.toStringAsFixed(1)} km/h', icon: Icons.speed),
                    _StatTileData(label: 'Highest Lean',  value: '${maxLean.toStringAsFixed(1)}°',     icon: Icons.rotate_90_degrees_ccw),
                    _StatTileData(label: 'Highest G',     value: maxG.toStringAsFixed(3),               icon: Icons.blur_circular),
                    _StatTileData(label: 'Longest Corner',value: '$longestCornerSec s',                 icon: Icons.timeline),
                  ],
                ),
                const SizedBox(height: 24),

                // Platzhalter für eine spätere Karten-/Overlay-Ansicht:
                _PlaceholderCard(
                  title: 'Route & Overlay (Coming Soon)',
                  subtitle: 'Hier könnte nach der Fahrt die Strecke mit Overlay (Speed/Lean/G) angezeigt werden.',
                  icon: Icons.map_outlined,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmtDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final da = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$da $hh:$mm';
  }
}

class _StatGrid extends StatelessWidget {
  final List<_StatTileData> items;
  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth > 700;
        final crossCount = isWide ? 4 : 2;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.9,
          ),
          itemBuilder: (_, i) => _StatTile(data: items[i]),
        );
      },
    );
  }
}

class _StatTileData {
  final String label;
  final String value;
  final IconData icon;
  _StatTileData({required this.label, required this.value, required this.icon});
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(data.icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _PlaceholderCard({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
