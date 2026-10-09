import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/live_tracking.dart';
import 'package:iub_ride_sharing_app/screens/ride_chat.dart';

class DriverRideRequestsScreen extends StatefulWidget {
  final String rideId;

  const DriverRideRequestsScreen({super.key, required this.rideId});

  @override
  State<DriverRideRequestsScreen> createState() => _DriverRideRequestsScreenState();
}

class _DriverRideRequestsScreenState extends State<DriverRideRequestsScreen> {
  bool isLoading = true;
  Map<String, dynamic>? rideData;
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> acceptedPassengers = [];

  @override
  void initState() {
    super.initState();
    _fetchRideAndRequests();
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

  Future<void> _fetchRideAndRequests() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch Ride Document
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (!rideDoc.exists) {
        if (mounted) {
          setState(() {
            isLoading = false;
            rideData = null;
          });
        }
        return;
      }

      final rData = {
        ...rideDoc.data()!,
        'rideId': rideDoc.id,
      };

      // 2. Fetch all requests for this specific ride
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('rideId', isEqualTo: widget.rideId)
          .get();

      final pendingList = <Map<String, dynamic>>[];
      final acceptedList = <Map<String, dynamic>>[];

      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        final passengerId = data['passengerId'] as String?;
        String passengerName = "Student";
        String department = "IUB";
        String phone = "";

        if (passengerId != null && passengerId.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(passengerId)
              .get();
          if (userDoc.exists) {
            final uData = userDoc.data();
            passengerName = uData?['fullName'] ?? 'Student';
            department = uData?['department'] ?? 'IUB';
            phone = uData?['phone'] ?? '';
          }
        }

        final item = {
          ...data,
          'requestId': doc.id,
          'passengerName': passengerName,
          'department': department,
          'phone': phone,
        };

        final status = data['status'] ?? 'pending';
        if (status == 'pending') {
          pendingList.add(item);
        } else if (status == 'accepted') {
          acceptedList.add(item);
        }
      }

      if (mounted) {
        setState(() {
          rideData = rData;
          pendingRequests = pendingList;
          acceptedPassengers = acceptedList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching requests: $e")),
        );
      }
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final requestId = request['requestId'] as String;
    final seatsRequested = (request['seats'] is int)
        ? request['seats'] as int
        : int.tryParse(request['seats'].toString()) ?? 1;

    final currentAvailable = (rideData?['availableSeats'] is int)
        ? rideData!['availableSeats'] as int
        : int.tryParse(rideData?['availableSeats']?.toString() ?? '0') ?? 0;

    if (currentAvailable < seatsRequested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Not enough available seats to accept this request"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final newSeats = currentAvailable - seatsRequested;

      // 1. Update Ride Document Available Seats
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'availableSeats': newSeats,
        'status': newSeats == 0 ? 'full' : 'active',
      });

      // 2. Update Request Document Status
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request accepted! Seat reserved."),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh list
      _fetchRideAndRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to accept request: $e")),
        );
      }
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(requestId)
          .update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request declined")),
        );
      }

      _fetchRideAndRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to decline request: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideDateTime = (rideData?['dateTime'] as Timestamp?)?.toDate();

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
          "Ride Requests",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchRideAndRequests,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rideData == null
              ? const Center(child: Text("Ride not found or removed"))
              : RefreshIndicator(
                  onRefresh: _fetchRideAndRequests,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // RIDE SUMMARY CARD
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
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
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rideData?['pickupLocation'] ?? 'Pickup',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rideData?['destination'] ?? 'Campus',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${_formatDate(rideDateTime)} · ${_formatTime(rideDateTime)}",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.mintWhisper,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Rs ${rideData?['price'] ?? 0} / seat",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Available: ${rideData?['availableSeats'] ?? 0} of ${rideData?['totalSeats'] ?? (rideData?['availableSeats'] ?? 1)} seats",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (rideData?['availableSeats'] == 0)
                                          ? Colors.red.shade100
                                          : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      (rideData?['availableSeats'] == 0)
                                          ? "FULL"
                                          : "ACTIVE",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: (rideData?['availableSeats'] == 0)
                                            ? Colors.red.shade700
                                            : Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION 1: PENDING REQUESTS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "PENDING REQUESTS (${pendingRequests.length})",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (pendingRequests.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.mark_email_read_outlined,
                                    size: 36, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  "No pending requests for this ride",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
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
                              itemCount: pendingRequests.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                final req = pendingRequests[index];
                                final name = req['passengerName'] ?? 'Student';
                                final dept = req['department'] ?? 'IUB';
                                final seats = req['seats'] ?? 1;

                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.emeraldGreen,
                                        child: Text(
                                          _getInitials(name),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
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
                                      // ACTION BUTTONS
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => _acceptRequest(req),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.mintWhisper,
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                          InkWell(
                                            onTap: () => _declineRequest(
                                                req['requestId']),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.warmCoralTint,
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // SECTION 2: CONFIRMED / ACCEPTED PASSENGERS
                        Text(
                          "CONFIRMED PASSENGERS (${acceptedPassengers.length})",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (acceptedPassengers.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                "No accepted passengers yet",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
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
                              itemCount: acceptedPassengers.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                final pass = acceptedPassengers[index];
                                final name = pass['passengerName'] ?? 'Student';
                                final dept = pass['department'] ?? 'IUB';
                                final seats = pass['seats'] ?? 1;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade600,
                                    child: Text(
                                      _getInitials(name),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "$dept · Reserved $seats seat${seats > 1 ? 's' : ''}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.emeraldGreen),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RideChat(
                                                rideId: widget.rideId,
                                                otherUserName: name,
                                                pickupLocation: rideData?['pickupLocation'] ?? 'Pickup',
                                                destination: rideData?['destination'] ?? 'Campus',
                                              ),
                                            ),
                                          );
                                        },
                                        tooltip: "Chat with Passenger",
                                      ),
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 32),

                        // START TRIP ACTION BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveTracking(
                                    rideId: widget.rideId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.navigation_outlined),
                            label: const Text(
                              "Start Trip / Live Tracking",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }
}
