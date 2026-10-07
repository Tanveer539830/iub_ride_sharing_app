import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';

class RideDetails extends StatefulWidget {
  final Map<String, dynamic> ride;

  const RideDetails({super.key, required this.ride});

  @override
  State<RideDetails> createState() => _RideDetailsState();
}

class _RideDetailsState extends State<RideDetails> {
  /*widget.ride['rideId']
        ↓
jis ride ko passenger join karna chahta hai


passengerId
        ↓
jo user request bhej raha hai*/
  final passengerId = FirebaseAuth.instance.currentUser?.uid;
  late final driverId = widget.ride['driverId'];



  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return "Time not available";
    }
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? "PM" : "AM";
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return "$displayHour:$displayMinute $period";
  }

  String _formatRideDate(DateTime? dateTime) {
    if (dateTime == null) {
      return "Date not avaiable";
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rideDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (rideDay == today) {
      return "Today";
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (rideDay == tomorrow) {
      return "Tomorrow";
    }
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  @override
  Widget build(BuildContext context) {
    final Timestamp? rideTimestamp = widget.ride['dateTime'] as Timestamp?;
    final DateTime? rideDateTime = rideTimestamp?.toDate();
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.mintIce,
                  ),
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        Text("  - - - - - - - - - - - - - - "),
                        Icon(Icons.location_on, color: Colors.red),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsetsGeometry.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "AK",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ride['rideId'],
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                "★★★★★ 4.8 · 62 rides",
                                style: TextStyle(color: AppColors.emeraldGreen),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.ride['pickupLocation'] ??
                                        'Unknown pickup',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.coolGray,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_right_alt_outlined,
                                  color: AppColors.coolGray,
                                ),
                                Expanded(
                                  child: Text(
                                    widget.ride['destination'] ?? 'Campus',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.coolGray,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mintIce,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: EdgeInsetsGeometry.all(8),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "Rs  ",
                                        style: const TextStyle(
                                          color: AppColors.mintGreen,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: widget.ride['price'],
                                        style: const TextStyle(
                                          color: AppColors.mintGreen,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ".0",
                                        style: const TextStyle(
                                          color: AppColors.mintGreen,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Departure",
                          style: TextStyle(
                            color: AppColors.coolGray,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "${_formatRideDate(rideDateTime)} ."
                          "${_formatTime(rideDateTime)}",
                          // "8:00 AM, Today",
                          style: TextStyle(color: Colors.black, fontSize: 15),
                        ),
                      ],
                    ),
                    Divider(thickness: 1, color: AppColors.coolGray),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          // "Seats Lefts",
                          "Available seats",

                          style: TextStyle(
                            color: AppColors.coolGray,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          widget.ride['availableSeats'].toString(),
                          //  "Available Seats",
                          style: TextStyle(color: Colors.black, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(vertical: 190),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (passengerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Please Login Before Post A Ride"),
                          ),
                        );
                        return;
                      }

                      try {
                        final snapshot = await FirebaseFirestore.instance
                            .collection('ride_requests')
                            .where('rideId', isEqualTo: widget.ride['rideId'])
                            .where('passengerId', isEqualTo: passengerId)
                            .get();
                        if (snapshot.docs.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Already requested")),
                          );
                          return;
                        }
                        await FirebaseFirestore.instance
                            .collection('ride_requests')
                            .add({
                              'rideId': widget.ride['rideId'],
                              'passengerId': passengerId,
                              'driverId': driverId,
                              'status': 'pending',
                              // 'seats': "1",
                                'seats': 1,
                              'requestedAt': FieldValue.serverTimestamp(),
                            });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Request sent Sucessfully")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 56),
                      backgroundColor: AppColors.coralRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Request to join",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
