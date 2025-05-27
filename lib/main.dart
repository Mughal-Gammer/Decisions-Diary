import 'package:desicionsdiarynew/widgets/ThemeNotifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Screen/dashboard.dart';
import 'Screen/login page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Initialize with the generated options
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),

  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If the user is authenticated, show the Dashboard
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData) {
              return DashboardScreen(); // Navigate to Dashboard if the user is logged in
            } else {
              return LoginPage(); // Navigate to Login if the user is not logged in
            }
          }
          // Loading screen while checking the authentication state
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}