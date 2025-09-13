// Aus der Vorlage vom Unterricht bezogen (Files.zip)!

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mototrack/screens/home_menu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller for Email and Password
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isLogin =
      true;

  // Show Error Message as SnackBar
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Navigate after Login/Register
  void _navigateOnSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeMenuScreen()),
    );
  }

  // Check Login/Registration on Button click
  Future<void> _submit() async {
    // Validate Email Format and Password Length
    if (!_formKey.currentState!.validate()) return;

    // Activate "loading" State for Animation
    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance; // Firebase Auth Instanz holen

      if (_isLogin) {
        // Login with Email + Passwort
        await auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), // remove unneeded spaces
          password: _passwordCtrl.text.trim(), // remove unneeded spaces
        );
      } else {
        // Registrierung with Email + Passwort
        await auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), // remove unneeded spaces
          password: _passwordCtrl.text.trim(), // remove unneeded spaces
        );
      }

      // Navigate to HomeScreen on Success
      _navigateOnSuccess();
    } on FirebaseAuthException catch (e) {
      // Return Error on Known Error
      _showError(e.message ?? 'Authentifizierung fehlgeschlagen.');
    } catch (e) {
      // Return Error on unknown Error
      _showError('Ein unerwarteter Fehler ist aufgetreten: $e');
    } finally {
      // deactivate Loading state
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey, // Connect key to Email/Password Fields
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title based on Login or Register Screen
                    Text(
                      _isLogin ? 'Anmelden' : 'Registrieren',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Email-Field
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
                        // Simple Validation (check if '@' included)
                        if (value == null || !value.contains('@')) {
                          return 'E-Mail-Adresse ist ungültig.';
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
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Passwort muss mindestens 6 Zeichen lang sein.';
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
                        // Disable Button when _isLoading = true
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
                                _isLogin ? 'Anmelden' : 'Registrieren',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Button to switch between Login and Register
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? "Noch kein Konto? Registrieren"
                            : "Du hast ein Konto? Anmelden",
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
