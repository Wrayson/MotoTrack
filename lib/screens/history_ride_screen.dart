import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/main_provider.dart';
import 'ride_detail_screen.dart';

class HistoryRideScreen extends StatelessWidget {
  const HistoryRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use provider's stream instead of building the query here
    final ridesStream = context.watch<MainProvider>().ridesStream;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrthistorie'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ridesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final title = (data['title'] as String?)?.trim();
              final dateStr = (data['date'] as String?) ?? '';
              final duration = (data['duration'] as String?) ?? '';
              final createdAt = (data['createdAt'] as num?)?.toInt();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                title: Text(title?.isNotEmpty == true ? title! : 'Fahrt'),
                subtitle: Text(
                  [
                    if (dateStr.isNotEmpty) 'Datum: $dateStr',
                    if (duration.isNotEmpty) 'Dauer: $duration',
                    if (createdAt != null) '• ${_fmtDateTime(createdAt)}'
                  ].join('  '),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideDetailScreen(rideId: d.id),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Löschen',
                  onPressed: () => _confirmDelete(context, d.id, title ?? 'Fahrt'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Ask user to confirm deletion, then call provider.deleteRide(...)
  static Future<void> _confirmDelete(
      BuildContext context,
      String rideId,
      String title,
      ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fahrt löschen?'),
        content: Text('„$title“ wird dauerhaft entfernt. Fortfahren?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // delegate actual deletion to provider
      await context.read<MainProvider>().deleteRide(rideId);

      if (context.mounted) {
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

  // Build formatted datetime from milliseconds
  static String _fmtDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final da = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$da $hh:$mm';
    // Optional: lokale Formatierung mit intl, wenn gewünscht.
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text(
              'Keine Fahrten gefunden',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Starte eine Fahrt, um sie hier anzuzeigen.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
