import 'package:flutter/material.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/screens/ride_details.dart';

class FindARide extends StatefulWidget {
  const FindARide({super.key});

  @override
  State<FindARide> createState() => _FindARideState();
}

class _FindARideState extends State<FindARide> {
  String? fullName;
  String? department;
  String? gender;
  String? defaultRoute;
  List<Map<String, dynamic>> rides = [];
  List<Map<String, dynamic>> searchedRides = [];
  bool isLoading = true;
  Map<String, String> driverNames = {};
  String selectedFilter = "All";
  final _pickUpController = TextEditingController();
  final _destinationController = TextEditingController();

  @override
  void dispose() {
    _pickUpController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _searchBtn() {
    final pickupLocation = _pickUpController.text.trim().toLowerCase();
    final destination = _destinationController.text.trim().toLowerCase();
    setState(() {
      if (pickupLocation.trim().isEmpty && destination.trim().isEmpty) {
        searchedRides = rides;
      }
      if (pickupLocation.trim().isNotEmpty && destination.trim().isEmpty) {
        searchedRides = rides.where((ride) {
          return ride["pickupLocation"].toString().toLowerCase().contains(
            pickupLocation.trim().toLowerCase(),
          );
        }).toList();
      }
      if (destination.trim().isNotEmpty && pickupLocation.trim().isEmpty) {
        searchedRides = rides.where((ride) {
          return ride["destination"].toString().toLowerCase().contains(
            destination.trim().toLowerCase(),
          );
        }).toList();
      }
      if (destination.trim().isNotEmpty && pickupLocation.trim().isNotEmpty) {
        searchedRides = rides.where((ride) {
          return ride["destination"].toString().toLowerCase().contains(
                destination.trim().toLowerCase(),
              ) &&
              ride['pickupLocation'].toString().toLowerCase().contains(
                pickupLocation.trim().toLowerCase(),
              );
        }).toList();
      }
    });
  }

  Future<void> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (snapshot.exists) {
      final data = snapshot.data();

      if (data != null) {
        setState(() {
          fullName = data['fullName'];
          department = data['department'];
          gender = data['gender'];
          defaultRoute = data['defaultRoute'];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserProfile();
    _getRides();
  }

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
      return "Date not available";
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

  Future<void> _getRides() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .get();
      final fetchedRides = snapshot.docs
          .map((doc) {
            return {
              ///3 dot ka matlab-->Exsisting Map ka saraa data ko new Map Main spread krna ya copy krna
              ...doc.data(),
              'rideId': doc.id,
            };

      })
          .where((ride) {
            final rideDate = ride['dateTime'].toDate();
            return !rideDate.isBefore(DateTime.now());
          })
          .toList();

      // Get unique driver IDs from all rides
      final driverIds = fetchedRides
          .map((ride) => ride['driverId'] as String?)
          .whereType<String>()
          .toSet();

      // Store driver names
      final fetchedDriverNames = <String, String>{};

      // Fetch each driver's profile
      await Future.wait(
        driverIds.map((driverId) async {
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(driverId)
              .get();

          final userData = userSnapshot.data();

          fetchedDriverNames[driverId] =
              userData?['fullName'] as String? ?? 'Unknown driver';
        }),
      );
      setState(() {
        rides = fetchedRides;
        searchedRides = fetchedRides;
        driverNames = fetchedDriverNames;
        isLoading = false;
      });
      print(fetchedRides.first);
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load rides: $e")));
    }
  }

  List<Map<String, dynamic>> getFilteredRides() {
    if (selectedFilter == "All") {
      return searchedRides;
    }
    if (selectedFilter == "Today") {
      return searchedRides.where((ride) {
        final rideDate = ride["dateTime"].toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final rideDay = DateTime(rideDate.year, rideDate.month, rideDate.day);
        return rideDay == today;
      }).toList();
    }
    if (selectedFilter == "This Week") {
      return searchedRides.where((ride) {
        final rideDate = ride["dateTime"].toDate();
        final now = DateTime.now();
        final weekStart = now;
        final weekEnd = now.add(const Duration(days: 7));
        return rideDate.isBefore(weekEnd) || rideDate.isAtSameMomentAs(weekEnd);
      }).toList();
    }
    if (selectedFilter == "Tomorrow") {
      return searchedRides.where((ride) {
        final rideDate = ride["dateTime"].toDate();
        final now = DateTime.now();
        final weekStart = now;
        final weekEnd = now.add(const Duration(days: 1));
        return rideDate.isBefore(weekEnd) || rideDate.isAtSameMomentAs(weekEnd);
      }).toList();
    }
    if (selectedFilter == "Morning") {
      return searchedRides.where((ride) {
        final rideDate = ride["dateTime"].toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final rideDay = DateTime(rideDate.year, rideDate.month, rideDate.day);

        return rideDay == today && rideDate.hour < 12;
      }).toList();
    }
    if (selectedFilter == "Afternoon") {
      return searchedRides.where((ride) {
        final rideDate = ride["dateTime"].toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final rideDay = DateTime(rideDate.year, rideDate.month, rideDate.day);
        return rideDay == today && rideDate.hour >= 12 && rideDate.hour < 17;
      }).toList();
    }
    if (selectedFilter == "Evening") {
      return searchedRides.where((ride) {
        final rideDate = ride['dateTime'].toDate();
        final now = DateTime.now();
        final toDay = DateTime(now.year, now.month, now.day);
        final rideDay = DateTime(rideDate.year, rideDate.month, rideDate.day);
        return toDay == rideDay && rideDate.hour >= 17;
      }).toList();
    }
    return searchedRides;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRides = getFilteredRides();
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi, ${fullName ?? 'Student '}",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "${defaultRoute ?? 'Bahawalpur'}.Today",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _pickUpController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                          labelText: "Pickup",
                          hintText: "Where are you starting from?",
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.emeraldGreen,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 1.5,
                            height: 22,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),

                      TextField(
                        controller: _destinationController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                          ),
                          labelText: "Destination",
                          hintText: "Where are you going?",
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.emeraldGreen,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 150,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  _searchBtn();
                },
                icon: const Icon(Icons.search),
                label: const Text("Search Rides"),
              ),
            ),

            SizedBox(height: 20),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = "All";
                          print("All");
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selectedFilter == "All"
                              ? Colors.green
                              : Colors.white,
                        ),
                        child: Text(
                          "All",
                          style: TextStyle(
                            color: selectedFilter == "All"
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 25),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = "Today";
                          print("Today Clicked");
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selectedFilter == "Today"
                              ? Colors.green
                              : Colors.white,
                        ),
                        child: Text(
                          "Today",
                          style: TextStyle(
                            color: selectedFilter == "Today"
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 25),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = "This Week";
                          print("This week clicked");
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selectedFilter == "This Week"
                              ? Colors.green
                              : Colors.white,
                        ),
                        child: Text(
                          "This Week",
                          style: TextStyle(
                            color: selectedFilter == "This Week"
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 25),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = "Morning";
                          print("Morning Clicked");
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selectedFilter == "Morning"
                              ? Colors.green
                              : Colors.white,
                        ),
                        child: Text(
                          "Morning",
                          style: TextStyle(
                            color: selectedFilter == "Morning"
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 25),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = "Afternoon";
                          print("Afternoon");
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selectedFilter == "Afternoon"
                              ? Colors.green
                              : Colors.white,
                        ),
                        child: Text(
                          "Afternoon",
                          style: TextStyle(
                            color: selectedFilter == "Afternoon"
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 25),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = "Evening";
                          print("Evening");
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selectedFilter == "Evening"
                              ? Colors.green
                              : Colors.white,
                        ),
                        child: Text(
                          "Evening",
                          style: TextStyle(
                            color: selectedFilter == "Evening"
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            ListView.builder(
              ///Ye Flutter ko batata hai:
              /// "Poori screen ki height mat lo —
              /// sirf utni height lo jitni tumhare andar ke items (rides cards) ki zaroorat hai."
              shrinkWrap: true,
              // Ye ListView ko bolta hai: "Tum khud scroll mat karo — apna scrolling gesture bilkul band kar do."
              physics: const NeverScrollableScrollPhysics(),
              // Ye sabse simple hai — Flutter ko batata hai ke list mein kitne items banane hain.
              itemCount: getFilteredRides().length,
              itemBuilder: (context, index) {
                final ride = filteredRides[index];

                final driverId = ride['driverId'] as String?;
                final driverName = driverId != null
                    ? driverNames[driverId] ?? 'Unknown driver'
                    : 'Unknown driver';
                final Timestamp? rideTimestamp = ride['dateTime'] as Timestamp?;
                final DateTime? rideDateTime = rideTimestamp?.toDate();
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, index == 0 ? 20 : 0, 20, 10),
                  child: GestureDetector(
                    onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>  RideDetails(ride:ride)),
                    );
                    },child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                // defaultRoute??"Loading route",
                                ride['pickupLocation'] ?? "Unknown pickup",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ride['destination'] ?? "Campus",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            // Date + Time + Driver
                            Expanded(
                              child: Text(
                                "${_formatRideDate(rideDateTime)} · "
                                "${_formatTime(rideDateTime)} · "
                                "${driverName ?? "loading"}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Price
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              constraints: const BoxConstraints(maxWidth: 100),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Rs ${ride['price'] ?? 0}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${ride['availableSeats'] ?? 0} seats available",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  )
                );
              },
            ),
            SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
