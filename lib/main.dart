import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:iub_ride_sharing_app/firebase_options.dart';
import 'package:iub_ride_sharing_app/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
      title: "IUB Ride Sharing App",
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
