import 'package:firebase_auth/firebase_auth.dart';
// Firebase Auth wird genutzt, um Login / Registrierung zu ermöglichen

import 'package:flutter/material.dart';
// Material Design Widgets (Scaffold, AppBar, Buttons, TextFields, etc.)

import 'package:mototrack/screens/home_menu_screen.dart';
// Screen, zu dem navigiert wird, wenn Login/Registrierung erfolgreich ist

// LoginScreen ist ein StatefulWidget, da wir dynamische Zustände haben:
// - Login oder Register Ansicht
// - Ladezustand (Spinner)
// - Eingaben in Textfeldern
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Schlüssel für das Formular, damit wir Form-Validation nutzen können
  final _formKey = GlobalKey<FormState>();

  // Controller für die Eingabefelder (TextEditingController speichert und liest den Wert der Textfelder)
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Zustände für das UI
  bool _isLoading = false; // zeigt Ladeindikator an, während Firebase arbeitet
  bool _isLogin =
      true; // steuert, ob Login- oder Registrierungsmodus angezeigt wird

  // Hilfsfunktion: Zeigt eine Fehlermeldung unten im Screen als SnackBar
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Hilfsfunktion: Navigation nach erfolgreichem Login/Registrierung
  void _navigateOnSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeMenuScreen()),
    );
  }

  // Kernfunktion: Wird ausgeführt, wenn User auf Login/Register klickt
  Future<void> _submit() async {
    // 1. Validierung prüfen (z.B. Email Format, Passwortlänge)
    if (!_formKey.currentState!.validate()) return;

    // Ladezustand aktivieren (Button deaktivieren und Spinner anzeigen)
    // setState() → build() wird erneut aufgerufen.
    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance; // Firebase Auth Instanz holen

      if (_isLogin) {
        // Login mit Email + Passwort
        await auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), // trim entfernt unnötige Leerzeichen
          password: _passwordCtrl.text.trim(),
        );
      } else {
        // Registrierung mit Email + Passwort
        await auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }

      // Wenn erfolgreich -> Navigation zum NotesScreen
      _navigateOnSuccess();
    } on FirebaseAuthException catch (e) {
      // Bekannte Fehler (z.B. falsches Passwort, User existiert nicht)
      _showError(e.message ?? 'Authentication failed.');
    } catch (e) {
      // Unbekannte Fehler (z.B. Netzwerkprobleme)
      _showError('An unexpected error occurred.');
    } finally {
      // Ladezustand wieder deaktivieren
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          // ScrollView: verhindert Überlauf bei kleinen Bildschirmen / Tastatur offen
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Card(
            elevation: 8, // Schatteneffekt
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey, // verbindet die Eingabefelder mit der Validation
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titel abhängig von Modus: Login oder Register
                    Text(
                      _isLogin ? 'Login' : 'Register',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Email-Feld
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        // Validierung: einfache Prüfung auf '@'
                        if (value == null || !value.contains('@')) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Passwort-Feld
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      obscureText: true, // Passwort wird mit Punkten angezeigt
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Button Login/Register
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        // Wenn _isLoading true ist -> Button deaktiviert
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Login' : 'Register',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Umschalter: zwischen Login und Registrieren wechseln
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Register"
                            : "Already registered? Login",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
