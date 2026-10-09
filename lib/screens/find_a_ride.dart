import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/ride_details.dart';

class FindARide extends StatefulWidget {
  const FindARide({super.key});

  @override
  State<FindARide> createState() => _FindARideState();
}

class _FindARideState extends State<FindARide> {
  String? fullName;
  String? defaultRoute;
  List<Map<String, dynamic>> allRides = [];
  List<Map<String, dynamic>> searchedRides = [];
  Map<String, Map<String, dynamic>> driverProfiles = {};
  bool isLoading = true;

  String selectedFilter = "All"; // All, Today, This Week, Morning, Afternoon, Evening
  final _pickUpController = TextEditingController();
  final _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserProfile();
    _fetchRides();
  }

  @override
  void dispose() {
    _pickUpController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && mounted) {
          setState(() {
            fullName = data['fullName'] ?? user.displayName ?? 'Student';
            defaultRoute = data['defaultRoute'] ?? 'Bahawalpur';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<void> _fetchRides() async {
    setState(() => isLoading = true);
    try {
      final now = DateTime.now();
      // Allow rides that started up to 30 mins ago, or future rides
      final marginTime = now.subtract(const Duration(minutes: 30));

      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .get();

      final fetchedList = snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'rideId': doc.id,
        };
      }).where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        final status = ride['status'] ?? 'active';
        final seats = ride['availableSeats'] ?? 0;
        // Show active rides with available seats and future date/time
        return dt != null &&
            dt.isAfter(marginTime) &&
            status != 'completed' &&
            status != 'cancelled' &&
            seats > 0;
      }).toList();

      // Sort ascending by departure time
      fetchedList.sort((a, b) {
        final tA = (a['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2100);
        final tB = (b['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2100);
        return tA.compareTo(tB);
      });

      // Fetch driver profiles for these rides
      final driverIds = fetchedList
          .map((r) => r['driverId'] as String?)
          .whereType<String>()
          .toSet();

      final profiles = <String, Map<String, dynamic>>{};

      await Future.wait(
        driverIds.map((driverId) async {
          try {
            final uSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(driverId)
                .get();
            if (uSnap.exists) {
              profiles[driverId] = uSnap.data() ?? {};
            }
          } catch (e) {
            debugPrint("Error fetching driver profile: $e");
          }
        }),
      );

      if (mounted) {
        setState(() {
          allRides = fetchedList;
          driverProfiles = profiles;
          isLoading = false;
        });
        _applySearchAndFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load rides: $e")),
        );
      }
    }
  }

  void _applySearchAndFilter() {
    final pickupQuery = _pickUpController.text.trim().toLowerCase();
    final destQuery = _destinationController.text.trim().toLowerCase();

    setState(() {
      searchedRides = allRides.where((ride) {
        final pickup = (ride['pickupLocation'] ?? '').toString().toLowerCase();
        final dest = (ride['destination'] ?? '').toString().toLowerCase();

        final matchesPickup = pickupQuery.isEmpty || pickup.contains(pickupQuery);
        final matchesDest = destQuery.isEmpty || dest.contains(destQuery);

        return matchesPickup && matchesDest;
      }).toList();
    });
  }

  List<Map<String, dynamic>> getFilteredRides() {
    if (selectedFilter == "All") return searchedRides;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (selectedFilter == "Today") {
      return searchedRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        if (dt == null) return false;
        final rDay = DateTime(dt.year, dt.month, dt.day);
        return rDay == today;
      }).toList();
    }

    if (selectedFilter == "This Week") {
      final weekEnd = today.add(const Duration(days: 7));
      return searchedRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        if (dt == null) return false;
        return dt.isBefore(weekEnd) || dt.isAtSameMomentAs(weekEnd);
      }).toList();
    }

    if (selectedFilter == "Morning") {
      return searchedRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        if (dt == null) return false;
        return dt.hour < 12;
      }).toList();
    }

    if (selectedFilter == "Afternoon") {
      return searchedRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        if (dt == null) return false;
        return dt.hour >= 12 && dt.hour < 17;
      }).toList();
    }

    if (selectedFilter == "Evening") {
      return searchedRides.where((ride) {
        final dt = (ride['dateTime'] as Timestamp?)?.toDate();
        if (dt == null) return false;
        return dt.hour >= 17;
      }).toList();
    }

    return searchedRides;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return "Time N/A";
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return "$displayHour:$minute $period";
  }

  String _formatRideDate(DateTime? dateTime) {
    if (dateTime == null) return "Date N/A";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rideDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (rideDay == today) return "Today";
    final tomorrow = today.add(const Duration(days: 1));
    if (rideDay == tomorrow) return "Tomorrow";

    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  String _getInitials(String name) {
    final words = name.trim().split(" ");
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return "${words[0][0]}${words[1][0]}".toUpperCase();
    }
    if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return "D";
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = getFilteredRides();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchRides,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. GREETING & ROUTE CONTEXT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hi, ${fullName ?? 'Student'}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${defaultRoute ?? 'Bahawalpur'} · Today",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mintWhisper,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${allRides.length} active rides",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. SEARCH CONTAINER (Pickup & Destination)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _pickUpController,
                        onChanged: (val) => _applySearchAndFilter(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.my_location, color: Colors.green, size: 20),
                          hintText: "Starting pickup (e.g. City Chowk)",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: _pickUpController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _pickUpController.clear();
                                    _applySearchAndFilter();
                                  },
                                )
                              : null,
                        ),
                      ),
                      Divider(height: 12, color: Colors.grey.shade200),
                      TextField(
                        controller: _destinationController,
                        onChanged: (val) => _applySearchAndFilter(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                          hintText: "Destination (e.g. Campus)",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: _destinationController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _destinationController.clear();
                                    _applySearchAndFilter();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. HORIZONTAL TIME FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    "All",
                    "Today",
                    "This Week",
                    "Morning",
                    "Afternoon",
                    "Evening"
                  ].map((filter) {
                    final isSelected = selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selectedColor: AppColors.darkNavy,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppColors.darkNavy : Colors.grey.shade300,
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          setState(() {
                            selectedFilter = filter;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // 4. RIDES FEED LIST
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredList.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          "No Rides Found",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "No drivers are currently travelling this route for the selected filter.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ride = filteredList[index];
                    final driverId = ride['driverId'] as String?;
                    final dProfile = driverId != null ? driverProfiles[driverId] : null;
                    final driverName = dProfile?['fullName'] ?? 'Driver';
                    final driverRating = dProfile?['rating']?.toString() ?? '4.9';

                    final Timestamp? rideTimestamp = ride['dateTime'] as Timestamp?;
                    final DateTime? rideDateTime = rideTimestamp?.toDate();
                    final availSeats = ride['availableSeats'] ?? 0;
                    final price = ride['price'] ?? 0;

                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    final isMyRide = currentUserId != null && driverId != null && currentUserId == driverId;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideDetails(ride: ride),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isMyRide ? const Color(0xFFFBFDFF) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMyRide ? AppColors.coralRed.withValues(alpha: 0.5) : Colors.grey.shade300,
                            width: isMyRide ? 1.5 : 1,
                          ),
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
                            if (isMyRide) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.coralRed.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.coralRed.withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.directions_car_filled_rounded, size: 13, color: AppColors.coralRed),
                                        SizedBox(width: 4),
                                        Text(
                                          "My Ride",
                                          style: TextStyle(
                                            color: AppColors.coralRed,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "You are the driver",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            // ROUTE ROW
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
                                    ride['pickupLocation'] ?? "Unknown pickup",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
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
                                    ride['destination'] ?? "Campus",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // TIME, DRIVER & FARE
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.emeraldGreen,
                                  child: Text(
                                    _getInitials(driverName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${_formatRideDate(rideDateTime)} · ${_formatTime(rideDateTime)}",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      Text(
                                        "$driverName · ★ $driverRating",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.mintWhisper,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Rs $price",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // AVAILABLE SEATS TAG
                            Text(
                              "$availSeats seat${availSeats > 1 ? 's' : ''} available",
                              style: TextStyle(
                                fontSize: 12,
                                color: availSeats == 1 ? Colors.orange.shade800 : Colors.grey.shade600,
                                fontWeight: availSeats == 1 ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
