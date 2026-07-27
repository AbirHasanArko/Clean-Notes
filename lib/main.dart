import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/subscription_gate.dart';
import 'services/auth_service.dart';
import 'services/notes_service.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase with the platform-specific config produced by the
  // FlutterFire CLI. See FIREBASE_SETUP.md for the one-time setup steps.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Sign in anonymously so every device has a stable uid that can own
  // notes in Firestore. `ensureSignedIn` returns immediately if a
  // previous session is still valid. If Anonymous auth isn't enabled
  // in the Firebase Console (statusCode=DEVELOPER_ERROR from GMS), we
  // still want the app to launch so the user can read the error in the
  // UI rather than seeing a blank crash.
  final authService = AuthService();
  try {
    await authService.ensureSignedIn();
  } catch (e, st) {
    debugPrint('Anonymous sign-in failed: $e\n$st');
  }

  runApp(NotesApp(authService: authService));
}

class NotesApp extends StatelessWidget {
  const NotesApp({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Clean Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: SubscriptionGate(
        subscriptionService: SubscriptionService(),
        notesService: NotesService(auth: authService),
      ),
    );
  }
}
