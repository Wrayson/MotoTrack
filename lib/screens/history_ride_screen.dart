import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ridesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rides')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Fahrthistorie')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ridesCol.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Noch keine Fahrten angelegt.'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final title = (data['title'] as String?) ?? 'Unbenannte Fahrt';
              final createdAt = (data['createdAt'] as int?) ?? 0;
              final ts = createdAt > 0
                  ? DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal()
                  : null;

              return Dismissible(
                key: ValueKey(d.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async => await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Löschen?'),
                    content: Text('„$title“ endgültig löschen?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Abbrechen')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Löschen')),
                    ],
                  ),
                ) ??
                    false,
                onDismissed: (_) async {
                  await d.reference.delete();
                },
                child: ListTile(
                  leading: const Icon(Icons.route),
                  title: Text(title),
                  subtitle: Text(ts != null ? ts.toString() : 'Kein Datum'),
                  onTap: () {
                    // TODO: Hier später Detailansicht mit Map/Overlay öffnen
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
