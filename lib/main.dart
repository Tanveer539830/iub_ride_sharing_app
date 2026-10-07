import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:iub_ride_sharing_app/screens/Home.dart';
import 'package:iub_ride_sharing_app/screens/complete_profile.dart';
import 'package:iub_ride_sharing_app/screens/create_account.dart';
import 'package:iub_ride_sharing_app/screens/find_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/forget_password_screens/forget_password.dart';
import 'package:iub_ride_sharing_app/screens/forget_password_screens/verify_account.dart';
import 'package:iub_ride_sharing_app/screens/live_tracking.dart';
import 'package:iub_ride_sharing_app/screens/my_rides.dart';
import 'package:iub_ride_sharing_app/screens/post_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/profile.dart';
import 'package:iub_ride_sharing_app/screens/rate_ride.dart';
import 'package:iub_ride_sharing_app/screens/ride_details.dart';
import 'package:iub_ride_sharing_app/screens/signing_screen.dart';
import 'package:iub_ride_sharing_app/screens/splash_screen.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

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
      home:Home(),
      title: "Ride Sharing App",
      theme: ThemeData(),
      debugShowCheckedModeBanner: false,
    );
  }
}
