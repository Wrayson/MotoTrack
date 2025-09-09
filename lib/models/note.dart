// ---------------------------
// Datenmodell für eine Notiz
// ---------------------------
class Note {
  // Eindeutige ID der Notiz (z. B. von Firestore generiert)
  final String id;

  // Titel der Notiz
  final String title;

  // Inhalt der Notiz (Text)
  final String content;

  // Konstruktor der Klasse -> alle Felder müssen übergeben werden
  Note({required this.id, required this.title, required this.content});

  // Wandelt ein Note-Objekt in eine Map um (für Firestore Speicherung).
  // Firestore speichert Daten in Form von Schlüssel-Wert-Paaren (JSON-ähnlich).
  // -> die id speichern wir NICHT hier, weil Firestore die ID als Dokument-Key hat.
  Map<String, dynamic> toMap() => {'title': title, 'content': content};

  // Factory-Konstruktor: erstellt ein Note-Objekt aus einer Map (z. B. aus Firestore-Daten).
  // Parameter:
  // - id: die Dokument-ID von Firestore (z. B. auto-generiert oder gesetzt).
  // - data: die Felder aus Firestore (title + content).
  factory Note.fromMap(String id, Map<String, dynamic> data) {
    return Note(
      id: id, // Dokument-ID
      title: data['title'], // Feld "title" aus Firestore
      content: data['content'], // Feld "content" aus Firestore
    );
  }
}
