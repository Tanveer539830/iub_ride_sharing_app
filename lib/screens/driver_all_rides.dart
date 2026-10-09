import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/driver_ride_requests.dart';
import 'package:iub_ride_sharing_app/screens/post_a_ride.dart';

class DriverAllRidesScreen extends StatefulWidget {
  const DriverAllRidesScreen({super.key});

  @override
  State<DriverAllRidesScreen> createState() => _DriverAllRidesScreenState();
}

class _DriverAllRidesScreenState extends State<DriverAllRidesScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> allRides = [];
  Map<String, int> pendingCounts = {};
  String selectedFilter = "All"; // All, Upcoming, Full, Completed

  @override
  void initState() {
    super.initState();
    _fetchDriverRides();
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return "N/A";
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return "$displayHour:$minute $period";
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return "N/A";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rideDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (rideDay == today) return "Today";
    final tomorrow = today.add(const Duration(days: 1));
    if (rideDay == tomorrow) return "Tomorrow";

    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  Future<void> _fetchDriverRides() async {
    setState(() => isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .get();

      final ridesList = snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'rideId': doc.id,
        };
      }).toList();

      // Sort by dateTime descending (most recent first)
      ridesList.sort((a, b) {
        final tA = (a['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tB = (b['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tB.compareTo(tA);
      });

      // Fetch pending requests counts for each ride
      final counts = <String, int>{};
      for (final ride in ridesList) {
        final rId = ride['rideId'] as String;
        final reqSnap = await FirebaseFirestore.instance
            .collection('ride_requests')
            .where('rideId', isEqualTo: rId)
            .where('status', isEqualTo: 'pending')
            .get();
        counts[rId] = reqSnap.docs.length;
      }

      if (mounted) {
        setState(() {
          allRides = ridesList;
          pendingCounts = counts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading rides: $e")),
        );
      }
    }
  }

  List<Map<String, dynamic>> getFilteredRides() {
    final now = DateTime.now();
    if (selectedFilter == "Upcoming") {
      return allRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        return dt != null && !dt.isBefore(now);
      }).toList();
    }
    if (selectedFilter == "Completed") {
      return allRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        return (dt != null && dt.isBefore(now)) || ride['status'] == 'completed';
      }).toList();
    }
    if (selectedFilter == "Full") {
      return allRides.where((ride) {
        final avail = ride['availableSeats'] ?? 0;
        return avail == 0 || ride['status'] == 'full';
      }).toList();
    }
    return allRides;
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = getFilteredRides();

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "All My Posted Rides",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchDriverRides,
          ),
        ],
      ),
      body: Column(
        children: [
          // FILTER CHIPS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["All", "Upcoming", "Full", "Completed"].map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      selectedColor: AppColors.darkNavy,
                      backgroundColor: Colors.grey.shade100,
                      checkmarkColor: Colors.white,
                      onSelected: (val) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // RIDES LIST
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _fetchDriverRides,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 60),
                                Icon(Icons.directions_car_outlined,
                                    size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  "No rides found in this category",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const PostARide()),
                                    );
                                    if (res == 1) _fetchDriverRides();
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text("Post a Ride"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emeraldGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchDriverRides,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final ride = filteredList[index];
                            final rId = ride['rideId'] as String;
                            final rideDateTime =
                                (ride['dateTime'] as Timestamp?)?.toDate();
                            final pendingCount = pendingCounts[rId] ?? 0;
                            final availSeats = ride['availableSeats'] ?? 0;

                            return InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DriverRideRequestsScreen(
                                      rideId: rId,
                                    ),
                                  ),
                                );
                                _fetchDriverRides();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ROUTE HEADER
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
                                            ride['pickupLocation'] ?? 'Pickup',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
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
                                            ride['destination'] ?? 'Campus',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // TIME & REQUESTS BADGE
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "${_formatDate(rideDateTime)} · ${_formatTime(rideDateTime)}",
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (pendingCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.warmCoralTint,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "$pendingCount pending request${pendingCount > 1 ? 's' : ''}",
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.mintWhisper,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              "0 requests",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // FARE & SEATS
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Rs ${ride['price'] ?? 0} / seat",
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          "$availSeats seats available",
                                          style: TextStyle(
                                            color: availSeats == 0
                                                ? Colors.red.shade600
                                                : Colors.grey.shade600,
                                            fontSize: 12,
                                            fontWeight: availSeats == 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
