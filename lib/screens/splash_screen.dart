import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/Home.dart';
import 'package:iub_ride_sharing_app/screens/create_account.dart';
import 'package:iub_ride_sharing_app/screens/find_a_ride.dart';
import 'dart:async';

import 'package:iub_ride_sharing_app/screens/practice_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignIn()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  color: AppColors.mediumTeal,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),

                child: const Icon(
                  CupertinoIcons.car_detailed,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              SizedBox(height: 28),
              Text(
                "IUB Rides",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),

              Text(
                "Share the ride, split the cost",
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
