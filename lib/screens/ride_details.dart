import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import 'Home.dart';
import 'live_tracking.dart';

class RideDetails extends StatefulWidget {
  final Map<String, dynamic> ride;

  const RideDetails({super.key, required this.ride});

  @override
  State<RideDetails> createState() => _RideDetailsState();
}

class _RideDetailsState extends State<RideDetails> {
  final String? passengerId = FirebaseAuth.instance.currentUser?.uid;
  late final String? driverId = widget.ride['driverId'] as String?;
  late final String rideId = widget.ride['rideId'] ?? '';

  Map<String, dynamic>? driverProfile;
  Map<String, dynamic>? existingRequest;
  bool isLoading = true;
  bool isSubmitting = false;
  int selectedSeats = 1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch driver profile
      if (driverId != null && driverId!.isNotEmpty) {
        final driverSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .get();
        if (driverSnap.exists) {
          driverProfile = driverSnap.data();
        }
      }

      // 2. Check if current passenger already has a request for this ride
      if (passengerId != null && rideId.isNotEmpty) {
        final reqSnap = await FirebaseFirestore.instance
            .collection('ride_requests')
            .where('rideId', isEqualTo: rideId)
            .where('passengerId', isEqualTo: passengerId)
            .get();

        if (reqSnap.docs.isNotEmpty) {
          existingRequest = {
            'id': reqSnap.docs.first.id,
            ...reqSnap.docs.first.data(),
          };
        }
      }
    } catch (e) {
      debugPrint("Error loading ride details data: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return "Time not available";
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? "PM" : "AM";
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return "$displayHour:$displayMinute $period";
  }

  String _formatRideDate(DateTime? dateTime) {
    if (dateTime == null) return "Date not available";
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

  int _getAvailableSeats() {
    final raw = widget.ride['availableSeats'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  num _getPricePerSeat() {
    final raw = widget.ride['price'];
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw) ?? 0;
    return 0;
  }

  bool _isDriverSelf() {
    return passengerId != null && driverId != null && passengerId == driverId;
  }

  Future<void> _handleJoinRequest() async {
    if (passengerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in before requesting a ride.")),
      );
      return;
    }

    if (_isDriverSelf()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot book your own ride!")),
      );
      return;
    }

    final available = _getAvailableSeats();
    if (available < selectedSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only $available seat(s) available.")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // 1. Fetch passenger profile details for rich notifications
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(passengerId)
          .get();
      final userData = userSnap.data() ?? {};
      final passengerName = userData['fullName'] ?? 'Passenger';
      final passengerDept = userData['department'] ?? '';
      final passengerPhone = userData['phone'] ?? '';
      final passengerPhoto = userData['photoURL'] ?? '';

      final pricePerSeat = _getPricePerSeat();
      final totalPrice = pricePerSeat * selectedSeats;

      // 2. Write request to ride_requests collection
      final newDoc = await FirebaseFirestore.instance.collection('ride_requests').add({
        'rideId': rideId,
        'passengerId': passengerId,
        'driverId': driverId,
        'passengerName': passengerName,
        'passengerDepartment': passengerDept,
        'passengerPhone': passengerPhone,
        'passengerPhotoURL': passengerPhoto,
        'seats': selectedSeats,
        'totalPrice': totalPrice,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        existingRequest = {
          'id': newDoc.id,
          'rideId': rideId,
          'passengerId': passengerId,
          'driverId': driverId,
          'seats': selectedSeats,
          'totalPrice': totalPrice,
          'status': 'pending',
        };
      });

      if (mounted) {
        _showSuccessDialog(passengerName, totalPrice);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send request: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog(String name, num total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.emeraldGreen,
                size: 54,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Request Sent!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your request for $selectedSeats seat${selectedSeats > 1 ? 's' : ''} (Rs $total) has been sent to the driver for approval.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // close dialog
                      Navigator.pop(context); // back to search
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Done"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // close dialog
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Home(initialIndex: 1),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("My Bookings"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Timestamp? rideTimestamp = widget.ride['dateTime'] as Timestamp?;
    final DateTime? rideDateTime = rideTimestamp?.toDate();

    final pickup = widget.ride['pickupLocation'] ?? 'Unknown Pickup';
    final destination = widget.ride['destination'] ?? 'Campus';
    final availableSeats = _getAvailableSeats();
    final pricePerSeat = _getPricePerSeat();
    final totalPrice = pricePerSeat * selectedSeats;

    final driverName = driverProfile?['fullName'] ?? 'IUB Driver';
    final driverDept = driverProfile?['department'] ?? 'Islamia University';
    final driverRating = (driverProfile?['rating'] ?? 4.8).toString();
    final driverPhoto = driverProfile?['photoURL'] as String?;
    final driverRides = driverProfile?['ridesGivenCount'] ?? 0;

    final isDriver = _isDriverSelf();
    final isFull = availableSeats <= 0;
    final reqStatus = existingRequest?['status'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          "Ride Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emeraldGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ROUTE VISUALIZATION CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // PICKUP ROW
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.green.shade100, width: 3),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 36,
                                  color: Colors.grey.shade300,
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "PICKUP LOCATION",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pickup,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // DESTINATION ROW
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.orange.shade100, width: 3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "DESTINATION",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    destination,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. DRIVER PROFILE CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
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
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      driverName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                driverDept,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 2),
                                  Text(
                                    driverRating,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    " · $driverRides rides given",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. TRIP SPECS & METRICS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // DEPARTURE
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.access_time_filled, color: Colors.blue.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Departure Schedule",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    "${_formatRideDate(rideDateTime)}, ${_formatTime(rideDateTime)}",
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 24, thickness: 0.8),

                        // AVAILABLE SEATS
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isFull ? Colors.red.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.airline_seat_recline_normal,
                                color: isFull ? Colors.red : AppColors.emeraldGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Seat Availability",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    isFull ? "No seats left" : "$availableSeats seat${availableSeats > 1 ? 's' : ''} available",
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: isFull ? Colors.red : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 24, thickness: 0.8),

                        // PRICE PER SEAT
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.mintWhisper,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: AppColors.emeraldGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Fare Rate",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    "Rs $pricePerSeat / seat",
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. INTERACTIVE SEAT SELECTOR & PRICE BREAKDOWN (IF ELIGIBLE)
                  if (!isDriver && !isFull && reqStatus == null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
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
                          const Text(
                            "Select Number of Seats",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: selectedSeats > 1
                                        ? () => setState(() => selectedSeats--)
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: selectedSeats > 1 ? AppColors.emeraldGreen : Colors.grey.shade400,
                                    iconSize: 28,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.mintIce,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "$selectedSeats",
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.emeraldGreen,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: selectedSeats < availableSeats
                                        ? () => setState(() => selectedSeats++)
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline),
                                    color: selectedSeats < availableSeats ? AppColors.emeraldGreen : Colors.grey.shade400,
                                    iconSize: 28,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Total Fare",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    "Rs $totalPrice",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emeraldGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 5. STATUS / WARNING BANNERS
                  if (isDriver)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "You are the driver of this ride. You cannot request your own ride.",
                              style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (reqStatus == 'pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Your join request is pending driver approval.",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (reqStatus == 'accepted')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.emeraldGreen),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Your seat has been confirmed for this ride!",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.emeraldGreen),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (reqStatus == 'rejected')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: Colors.red.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Your previous request for this ride was declined.",
                              style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isFull)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "This ride is fully booked. No seats remaining.",
                              style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 6. MAIN ACTION BUTTON
                  if (reqStatus == 'accepted') ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveTracking(
                              rideId: rideId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text("Track Ride / View Status"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: AppColors.emeraldGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: (isDriver || isFull || reqStatus == 'pending' || isSubmitting)
                          ? null
                          : _handleJoinRequest,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: AppColors.emeraldGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              isDriver
                                  ? "Your Posted Ride"
                                  : isFull
                                      ? "Ride Full"
                                      : reqStatus == 'pending'
                                          ? "Request Pending"
                                          : "Request to Join (Rs $totalPrice)",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
