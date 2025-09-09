// Firebase Authentication
import 'package:firebase_auth/firebase_auth.dart';

// Firebase Core
import 'package:firebase_core/firebase_core.dart';

// Flutter UI Framework
import 'package:flutter/material.dart';

// Provider Paket for State Management
import 'package:provider/provider.dart';

// Main State Management
import 'package:mototrack/providers/main_provider.dart';

// Main Home Screen
import 'package:mototrack/screens/home_menu_screen.dart';

// Login and Registration Screen
import 'package:mototrack/screens/login_screen.dart';

void main() async {
  // Make sure Flutter-Engine is ready before starting Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Start Firebase and Google Services
  await Firebase.initializeApp();

  // Startet die Flutter-App mit dem Wurzel-Widget MyApp
  runApp(MyApp());
}

// Main Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Create all needed Providers
      providers: [
        ChangeNotifierProvider(
          create: (_) => MainProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false, // entfernt das Debug-Banner
        title: 'MotoTrack', // App-Name, seen in App-Switcher
        // Check if User is logged in and redirect to screen
        home: FirebaseAuth.instance.currentUser == null
            // If User logged out, go to Login
            ? LoginScreen()
            // If User logged in, go to HomeMenu
            : HomeMenuScreen(),
      ),
    );
  }
}
