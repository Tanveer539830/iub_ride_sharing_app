import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/driver_all_rides.dart';
import 'package:iub_ride_sharing_app/screens/driver_ride_requests.dart';
import 'package:iub_ride_sharing_app/screens/post_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/live_tracking.dart';
import 'package:iub_ride_sharing_app/screens/rate_ride.dart';
import 'package:iub_ride_sharing_app/screens/ride_chat.dart';

class MyRides extends StatefulWidget {
  final int initialTab;
  const MyRides({super.key, this.initialTab = 0});

  @override
  State<MyRides> createState() => _MyRidesState();
}

class _MyRidesState extends State<MyRides> {
  late int selectedRoleIndex; // 0 = As driver, 1 = As passenger
  bool isLoading = true;

  // Driver Data
  Map<String, dynamic>? currentRide;
  int allDriverRidesCount = 0;
  List<Map<String, dynamic>> currentRideRequests = [];

  // Passenger Data
  List<Map<String, dynamic>> passengerRequests = [];
  String passengerFilter = 'All'; // All, Pending, Confirmed, Completed, Declined

  @override
  void initState() {
    super.initState();
    selectedRoleIndex = widget.initialTab;
    _loadData();
  }

  Future<void> _loadData() async {
    if (selectedRoleIndex == 0) {
      await _fetchDriverCurrentRideAndRequests();
    } else {
      await _fetchPassengerBookings();
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return "Time N/A";
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return "$displayHour:$minute $period";
  }

  String _formatDate(DateTime? dateTime) {
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
    return "P";
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver phone number not available")),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch phone dialer: $e")),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // DRIVER FLOW: Fetch Nearest Upcoming Ride & Its Requests
  // -------------------------------------------------------------
  Future<void> _fetchDriverCurrentRideAndRequests() async {
    setState(() => isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final allRidesSnap = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .get();

      allDriverRidesCount = allRidesSnap.docs.length;

      final now = DateTime.now();
      final marginPast = now.subtract(const Duration(hours: 1));

      final driverRides = allRidesSnap.docs.map((d) {
        return {
          'rideId': d.id,
          ...d.data(),
        };
      }).toList();

      Map<String, dynamic>? nearestRide;
      Duration minDifference = const Duration(days: 9999);

      for (final ride in driverRides) {
        final status = ride['status'] as String? ?? 'active';
        if (status == 'completed' || status == 'cancelled') continue;

        final t = ride['dateTime'] as Timestamp?;
        if (t != null) {
          final dt = t.toDate();
          if (dt.isAfter(marginPast)) {
            final diff = dt.difference(now).abs();
            if (diff < minDifference) {
              minDifference = diff;
              nearestRide = ride;
            }
          }
        }
      }

      if (nearestRide == null) {
        for (final ride in driverRides) {
          final status = ride['status'] as String? ?? 'active';
          if (status != 'completed' && status != 'cancelled') {
            nearestRide = ride;
            break;
          }
        }
      }

      final requestsList = <Map<String, dynamic>>[];
      if (nearestRide != null) {
        final rideId = nearestRide['rideId'] as String;
        final reqSnap = await FirebaseFirestore.instance
            .collection('ride_requests')
            .where('rideId', isEqualTo: rideId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (final reqDoc in reqSnap.docs) {
          final rData = reqDoc.data();
          final passengerId = rData['passengerId'] as String?;
          String passengerName = rData['passengerName'] ?? 'Student';
          String department = rData['passengerDepartment'] ?? 'IUB';

          if (passengerId != null && (rData['passengerName'] == null || rData['passengerDepartment'] == null)) {
            final uSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(passengerId)
                .get();
            if (uSnap.exists) {
              final uData = uSnap.data();
              passengerName = uData?['fullName'] ?? 'Student';
              department = uData?['department'] ?? 'IUB';
            }
          }

          requestsList.add({
            ...rData,
            'requestId': reqDoc.id,
            'passengerName': passengerName,
            'department': department,
          });
        }
      }

      if (mounted) {
        setState(() {
          currentRide = nearestRide;
          currentRideRequests = requestsList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching driver rides: $e")),
        );
      }
    }
  }

  Future<void> _acceptDriverRequest(Map<String, dynamic> request) async {
    if (currentRide == null) return;
    final rideId = currentRide!['rideId'] as String;
    final requestId = request['requestId'] as String;
    final seatsRequested = (request['seats'] is int)
        ? request['seats'] as int
        : int.tryParse(request['seats'].toString()) ?? 1;

    final currentAvailable = (currentRide!['availableSeats'] is int)
        ? currentRide!['availableSeats'] as int
        : int.tryParse(currentRide!['availableSeats']?.toString() ?? '0') ?? 0;

    if (currentAvailable < seatsRequested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Not enough available seats left!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final newSeats = currentAvailable - seatsRequested;

      await FirebaseFirestore.instance.collection('rides').doc(rideId).update({
        'availableSeats': newSeats,
        'status': newSeats == 0 ? 'full' : 'active',
      });

      await FirebaseFirestore.instance.collection('ride_requests').doc(requestId).update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request accepted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }

      _fetchDriverCurrentRideAndRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error accepting request: $e")),
        );
      }
    }
  }

  Future<void> _declineDriverRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('ride_requests').doc(requestId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request declined")),
        );
      }

      _fetchDriverCurrentRideAndRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error declining request: $e")),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // PASSENGER FLOW: Fetch Rides Requested/Booked by Passenger
  // -------------------------------------------------------------
  Future<void> _fetchPassengerBookings() async {
    setState(() => isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final reqSnap = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('passengerId', isEqualTo: currentUser.uid)
          .get();

      final list = <Map<String, dynamic>>[];

      for (final doc in reqSnap.docs) {
        final rData = doc.data();
        final rideId = rData['rideId'] as String?;

        Map<String, dynamic>? rideInfo;
        Map<String, dynamic>? driverInfo;

        if (rideId != null && rideId.isNotEmpty) {
          final rideDoc = await FirebaseFirestore.instance
              .collection('rides')
              .doc(rideId)
              .get();
          if (rideDoc.exists) {
            rideInfo = {'rideId': rideDoc.id, ...rideDoc.data()!};
            final driverId = rideInfo['driverId'] as String?;
            if (driverId != null && driverId.isNotEmpty) {
              final dUser = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(driverId)
                  .get();
              if (dUser.exists) {
                driverInfo = dUser.data();
              }
            }
          }
        }

        list.add({
          ...rData,
          'requestId': doc.id,
          'rideInfo': rideInfo,
          'driverInfo': driverInfo,
        });
      }

      // Sort by requestedAt descending
      list.sort((a, b) {
        final tA = a['requestedAt'] as Timestamp?;
        final tB = b['requestedAt'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          passengerRequests = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching bookings: $e")),
        );
      }
    }
  }

  Future<void> _cancelPassengerRequest(Map<String, dynamic> request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Request?"),
        content: const Text("Are you sure you want to cancel your seat request for this ride?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No, Keep it"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final requestId = request['requestId'] as String;
      await FirebaseFirestore.instance.collection('ride_requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request cancelled successfully")),
        );
      }
      _fetchPassengerBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel request: $e")),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredPassengerRequests() {
    if (passengerFilter == 'All') return passengerRequests;
    return passengerRequests.where((item) {
      final status = (item['status'] ?? 'pending').toString().toLowerCase();
      final rideStatus = (item['rideInfo']?['status'] ?? '').toString().toLowerCase();

      if (passengerFilter == 'Pending') return status == 'pending';
      if (passengerFilter == 'Confirmed') return status == 'accepted' && rideStatus != 'completed';
      if (passengerFilter == 'Completed') return rideStatus == 'completed' || status == 'completed';
      if (passengerFilter == 'Declined') return status == 'declined' || status == 'cancelled';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FC),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Manage rides you offer and join",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // SEGMENTED TAB SWITCHER (As Driver / As Passenger)
                Container(
                  height: 48,
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      // AS DRIVER TAB
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (selectedRoleIndex != 0) {
                              setState(() => selectedRoleIndex = 0);
                              _loadData();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selectedRoleIndex == 0
                                  ? AppColors.darkNavy
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "As driver",
                              style: TextStyle(
                                color: selectedRoleIndex == 0
                                    ? Colors.white
                                    : AppColors.coolGray,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // AS PASSENGER TAB
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (selectedRoleIndex != 1) {
                              setState(() => selectedRoleIndex = 1);
                              _loadData();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selectedRoleIndex == 1
                                  ? AppColors.darkNavy
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "As passenger",
                              style: TextStyle(
                                color: selectedRoleIndex == 1
                                    ? Colors.white
                                    : AppColors.coolGray,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // CONTENT DEPENDING ON SELECTED ROLE
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.emeraldGreen),
                    ),
                  )
                else if (selectedRoleIndex == 0)
                  _buildDriverView()
                else
                  _buildPassengerView(),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // DRIVER VIEW BUILDER
  // =============================================================
  Widget _buildDriverView() {
    final rideDateTime = (currentRide?['dateTime'] as Timestamp?)?.toDate();
    final pendingCount = currentRideRequests.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CURRENT / UPCOMING RIDE CARD
        if (currentRide != null) ...[
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverRideRequestsScreen(
                    rideId: currentRide!['rideId'],
                  ),
                ),
              );
              _loadData();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ROUTE WITH ARROW
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
                          currentRide?['pickupLocation'] ?? "Pickup",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
                          currentRide?['destination'] ?? "Campus",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // TIME & REQUESTS BADGE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_formatDate(rideDateTime)} · ${_formatTime(rideDateTime)}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? AppColors.warmCoralTint : AppColors.mintWhisper,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$pendingCount request${pendingCount == 1 ? '' : 's'}",
                          style: TextStyle(
                            color: pendingCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // VIEW ALL RIDES DRILL-DOWN LINK
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverAllRidesScreen(),
                  ),
                );
                _loadData();
              },
              icon: const Text(
                "View all rides",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              label: const Icon(Icons.arrow_forward_ios, size: 12),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkNavy,
              ),
            ),
          ),
        ] else ...[
          // NO ACTIVE RIDE EMPTY CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text(
                  "No Upcoming Active Rides",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Post a ride to start offering seats to students",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PostARide()),
                    );
                    if (res == 1) _loadData();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Post a Ride"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (allDriverRidesCount > 0) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverAllRidesScreen(),
                        ),
                      );
                      _loadData();
                    },
                    child: Text("View past rides ($allDriverRidesCount)"),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 2. REQUESTS FOR THIS CURRENT RIDE SECTION
        if (currentRide != null) ...[
          Text(
            "REQUESTS FOR THIS RIDE",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          if (currentRideRequests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    "No pending requests for this ride yet",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentRideRequests.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final req = currentRideRequests[index];
                  final name = req['passengerName'] ?? 'Student';
                  final seats = req['seats'] ?? 1;
                  final dept = req['department'] ?? 'IUB';

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: AppColors.emeraldGreen,
                          child: Text(
                            _getInitials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                "$dept · Wants $seats seat${seats > 1 ? 's' : ''}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ACCEPT BUTTON
                        InkWell(
                          onTap: () => _acceptDriverRequest(req),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.mintWhisper,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Accept",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // DECLINE BUTTON
                        InkWell(
                          onTap: () => _declineDriverRequest(req['requestId']),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warmCoralTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Decline",
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  // =============================================================
  // PASSENGER VIEW BUILDER (Booked/Requested Rides)
  // =============================================================
  Widget _buildPassengerView() {
    final filteredList = _getFilteredPassengerRequests();
    final filterOptions = ['All', 'Pending', 'Confirmed', 'Completed', 'Declined'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FILTER CHIPS ROW
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filterOptions.map((f) {
              final isSelected = passengerFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.emeraldGreen,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.emeraldGreen : Colors.grey.shade300,
                    ),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => passengerFilter = f);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        if (filteredList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.directions_walk_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  passengerFilter == 'All'
                      ? "No Bookings Found"
                      : "No $passengerFilter Bookings",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Use 'Find a Ride' to explore available routes and request seats",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = filteredList[index];
              final rideInfo = item['rideInfo'] as Map<String, dynamic>?;
              final driverInfo = item['driverInfo'] as Map<String, dynamic>?;

              final driverName = driverInfo?['fullName'] ?? 'IUB Driver';
              final driverPhone = driverInfo?['phone'] ?? '';
              final driverDept = driverInfo?['department'] ?? 'Islamia University';
              final driverRating = (driverInfo?['rating'] ?? 4.8).toString();
              final driverPhoto = driverInfo?['photoURL'] as String?;

              final status = (item['status'] ?? 'pending').toString().toLowerCase();
              final rideStatus = (rideInfo?['status'] ?? 'active').toString().toLowerCase();
              final seats = item['seats'] ?? 1;

              final Timestamp? rideTimestamp = rideInfo?['dateTime'] as Timestamp?;
              final DateTime? rideDateTime = rideTimestamp?.toDate();
              final rideId = item['rideId'] as String? ?? '';
              final pricePerSeat = rideInfo?['price'] ?? 0;
              final totalPrice = item['totalPrice'] ?? (pricePerSeat is num ? pricePerSeat * (seats as num) : 0);

              final isCompleted = rideStatus == 'completed' || status == 'completed';
              final isAccepted = status == 'accepted' && !isCompleted;
              final isPending = status == 'pending';
              final isDeclined = status == 'declined' || status == 'cancelled';

              Color statusColor = Colors.orange.shade800;
              Color statusBg = Colors.orange.shade50;
              String statusLabel = "PENDING APPROVAL";

              if (isCompleted) {
                statusColor = Colors.blue.shade800;
                statusBg = Colors.blue.shade50;
                statusLabel = "COMPLETED";
              } else if (isAccepted) {
                statusColor = Colors.green.shade800;
                statusBg = AppColors.mintWhisper;
                statusLabel = "CONFIRMED";
              } else if (isDeclined) {
                statusColor = Colors.red.shade800;
                statusBg = AppColors.warmCoralTint;
                statusLabel = status == 'cancelled' ? "CANCELLED" : "DECLINED";
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAccepted ? AppColors.emeraldGreen.withValues(alpha: 0.3) : Colors.grey.shade300,
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
                    // 1. ROUTE & STATUS BADGE
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                                      rideInfo?['pickupLocation'] ?? "Unknown Pickup",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
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
                                      rideInfo?['destination'] ?? "Campus",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 20, thickness: 0.7),

                    // 2. DRIVER & SCHEDULE DETAILS
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.emeraldGreen,
                          backgroundImage: (driverPhoto != null && driverPhoto.isNotEmpty)
                              ? NetworkImage(driverPhoto)
                              : null,
                          child: (driverPhoto == null || driverPhoto.isEmpty)
                              ? Text(
                                  _getInitials(driverName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "$driverDept · ★ $driverRating",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // FARE & SEATS
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Rs $totalPrice",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.emeraldGreen,
                              ),
                            ),
                            Text(
                              "$seats seat${seats > 1 ? 's' : ''}",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // SCHEDULE BADGE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            "${_formatDate(rideDateTime)} at ${_formatTime(rideDateTime)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. ACTION BUTTONS ROW
                    if (isAccepted) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // TRACK RIDE BUTTON
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LiveTracking(rideId: rideId),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.navigation_rounded, size: 16),
                              label: const Text("Track Ride"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // CHAT BUTTON
                          IconButton.filledTonal(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RideChat(
                                    rideId: rideId,
                                    otherUserName: driverName,
                                    otherUserPhoto: driverPhoto,
                                    pickupLocation: rideInfo?['pickupLocation'] ?? 'Pickup',
                                    destination: rideInfo?['destination'] ?? 'Campus',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.mintIce,
                              foregroundColor: AppColors.emeraldGreen,
                            ),
                            tooltip: "Chat with Driver",
                          ),
                          if (driverPhone.toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            // CALL DRIVER BUTTON
                            IconButton.filledTonal(
                              onPressed: () => _makePhoneCall(driverPhone.toString()),
                              icon: const Icon(Icons.phone, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade700,
                              ),
                              tooltip: "Call Driver",
                            ),
                          ],
                        ],
                      ),
                    ] else if (isPending) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _cancelPassengerRequest(item),
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                          label: const Text("Cancel Request", style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ),
                    ] else if (isCompleted) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RateRide(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        label: const Text("Rate Driver & Trip"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
