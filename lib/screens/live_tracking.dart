import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/rate_ride.dart';
import 'package:iub_ride_sharing_app/screens/ride_chat.dart';

class LiveTracking extends StatefulWidget {
  final String? rideId;

  const LiveTracking({super.key, this.rideId});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  String? activeRideId;
  bool isInitializing = true;
  bool isUpdatingStatus = false;
  List<Map<String, dynamic>> confirmedPassengers = [];
  Map<String, dynamic>? driverProfile;

  @override
  void initState() {
    super.initState();
    _resolveActiveRide();
  }

  Future<void> _resolveActiveRide() async {
    setState(() => isInitializing = true);
    if (widget.rideId != null && widget.rideId!.isNotEmpty) {
      activeRideId = widget.rideId;
      await _fetchTripAdditionalData(activeRideId!);
      if (mounted) setState(() => isInitializing = false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => isInitializing = false);
      return;
    }

    try {
      // 1. Try finding as driver
      final driverSnap = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['active', 'on_the_way', 'arrived', 'full'])
          .get();

      if (driverSnap.docs.isNotEmpty) {
        activeRideId = driverSnap.docs.first.id;
        await _fetchTripAdditionalData(activeRideId!);
      } else {
        // 2. Try finding as passenger
        final passSnap = await FirebaseFirestore.instance
            .collection('ride_requests')
            .where('passengerId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'accepted')
            .get();

        if (passSnap.docs.isNotEmpty) {
          activeRideId = passSnap.docs.first.data()['rideId'] as String?;
          if (activeRideId != null) {
            await _fetchTripAdditionalData(activeRideId!);
          }
        }
      }
    } catch (e) {
      debugPrint("Error resolving active ride: $e");
    }

    if (mounted) {
      setState(() => isInitializing = false);
    }
  }

  Future<void> _fetchTripAdditionalData(String rId) async {
    try {
      // 1. Fetch Ride to get driverId
      final rideDoc = await FirebaseFirestore.instance.collection('rides').doc(rId).get();
      if (rideDoc.exists) {
        final rData = rideDoc.data();
        final driverId = rData?['driverId'] as String?;
        if (driverId != null && driverId.isNotEmpty) {
          final dDoc = await FirebaseFirestore.instance.collection('users').doc(driverId).get();
          if (dDoc.exists) {
            driverProfile = dDoc.data();
          }
        }
      }

      // 2. Fetch confirmed passengers
      final reqSnap = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('rideId', isEqualTo: rId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final list = <Map<String, dynamic>>[];
      for (final doc in reqSnap.docs) {
        final data = doc.data();
        final pId = data['passengerId'] as String?;
        String pName = data['passengerName'] ?? 'Student';
        String pDept = data['passengerDepartment'] ?? 'IUB';
        String pPhone = data['passengerPhone'] ?? '';
        String pPhoto = data['passengerPhotoURL'] ?? '';

        if (pId != null && (pName == 'Student' || pDept == 'IUB')) {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(pId).get();
          if (uDoc.exists) {
            final uData = uDoc.data();
            pName = uData?['fullName'] ?? pName;
            pDept = uData?['department'] ?? pDept;
            pPhone = uData?['phone'] ?? pPhone;
            pPhoto = uData?['photoURL'] ?? pPhoto;
          }
        }

        list.add({
          ...data,
          'passengerName': pName,
          'department': pDept,
          'phone': pPhone,
          'photoURL': pPhoto,
        });
      }

      if (mounted) {
        setState(() {
          confirmedPassengers = list;
        });
      }
    } catch (e) {
      debugPrint("Error fetching trip additional data: $e");
    }
  }

  Future<void> _updateRideStatus(String newStatus, String successMsg) async {
    if (activeRideId == null) return;
    setState(() => isUpdatingStatus = true);

    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(activeRideId)
          .update({
        'status': newStatus,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (newStatus == 'completed') {
        _showTripCompletedDialog(isDriver: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUpdatingStatus = false);
      }
    }
  }

  void _showTripCompletedDialog({required bool isDriver}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text("Ride Completed!"),
          ],
        ),
        content: Text(
          isDriver
              ? "Great job! You have safely completed the ride. All passengers have reached their destination."
              : "You have safely arrived at your destination! Please take a moment to rate your driver.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (!isDriver)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RateRide()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text("Rate Driver"),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text("Done"),
            ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not provided")),
      );
      return;
    }

    final uri = Uri.parse("tel:$cleanPhone");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open dialer: $e")),
        );
      }
    }
  }

  Future<void> _shareTripDetails(Map<String, dynamic> ride, bool isDriver) async {
    final pickup = ride['pickupLocation'] ?? 'Pickup';
    final destination = ride['destination'] ?? 'Campus';
    final status = (ride['status'] ?? 'active').toString().toUpperCase();
    final driverName = driverProfile?['fullName'] ?? 'Driver';

    final text = "🚗 IUB Ride Sharing Update:\n"
        "Role: ${isDriver ? 'Driver' : 'Passenger'}\n"
        "Driver: $driverName\n"
        "Route: $pickup → $destination\n"
        "Status: $status\n"
        "Shared via IUB Ride Sharing App.";

    await Share.share(text, subject: "IUB Ride Sharing Status");
  }

  String _getInitials(String name) {
    final words = name.trim().split(" ");
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return "${words[0][0]}${words[1][0]}".toUpperCase();
    }
    if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return "U";
  }

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.emeraldGreen),
        ),
      );
    }

    if (activeRideId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Live Tracking")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                "No Active Ride Found",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "You don't have any ongoing or scheduled rides.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .doc(activeRideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen)),
          );
        }

        final ride = snapshot.data!.data() as Map<String, dynamic>?;
        if (ride == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Live Tracking")),
            body: const Center(child: Text("Ride document no longer exists.")),
          );
        }

        final status = (ride['status'] ?? 'active').toString();
        final pickup = ride['pickupLocation'] ?? 'Pickup Point';
        final destination = ride['destination'] ?? 'IUB Campus';
        final driverId = ride['driverId'] as String?;
        final isDriver = currentUid != null && driverId != null && currentUid == driverId;

        final driverName = driverProfile?['fullName'] ?? 'IUB Driver';
        final driverDept = driverProfile?['department'] ?? 'Islamia University';
        final driverPhone = driverProfile?['phone'] ?? '';
        final driverRating = (driverProfile?['rating'] ?? 4.8).toString();
        final driverPhoto = driverProfile?['photoURL'] as String?;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isDriver ? "Trip Execution (Driver)" : "Live Ride Tracking",
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.black87, size: 20),
                onPressed: () => _shareTripDetails(ride, isDriver),
                tooltip: "Share Trip Details",
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP ROUTE & ETA BANNER CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppColors.darkNavy,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.car_detailed,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getBannerTitle(status, isDriver),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getBannerSubtitle(status, isDriver),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24, thickness: 0.8),
                      // Route summary inside banner
                      Row(
                        children: [
                          const Icon(Icons.trip_origin, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pickup,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, color: Colors.white54, size: 14),
                          ),
                          const Icon(Icons.location_on, color: Colors.orangeAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              destination,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. TRIP PROGRESS STEPPER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _buildTripProgressStepper(status),
                ),

                const SizedBox(height: 18),

                // 3. PERSPECTIVE SPECIFIC SECTIONS:
                if (!isDriver) ...[
                  // PASSENGER VIEW: DRIVER CARD WITH LIVE CALL
                  Text(
                    "ASSIGNED DRIVER",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
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
                                    fontSize: 15,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$driverDept · ★ $driverRating",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.emeraldGreen),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RideChat(
                                      rideId: activeRideId!,
                                      otherUserName: driverName,
                                      otherUserPhoto: driverPhoto,
                                      pickupLocation: pickup,
                                      destination: destination,
                                    ),
                                  ),
                                );
                              },
                              tooltip: "Chat with Driver",
                            ),
                            if (driverPhone.toString().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone, color: Colors.green),
                                onPressed: () => _makePhoneCall(driverPhone.toString()),
                                tooltip: "Call Driver",
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // PASSENGER RIDE ACTIONS
                  if (status == 'completed') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.mintWhisper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.emeraldGreen, size: 40),
                          const SizedBox(height: 8),
                          const Text(
                            "You have reached your destination!",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Help the IUB community by rating your driver.",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const RateRide()),
                              );
                            },
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text("Rate Your Ride"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Passenger waiting / info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              status == 'on_the_way'
                                  ? "The driver is approaching the pickup location. Please be ready!"
                                  : status == 'arrived'
                                      ? "Driver has reached the pickup spot. Please board the vehicle."
                                      : "Ride is scheduled. Driver will notify when starting the trip.",
                              style: TextStyle(fontSize: 12.5, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // DRIVER VIEW: CONFIRMED PASSENGERS LIST & ACTIONS
                  Text(
                    "CONFIRMED PASSENGERS (${confirmedPassengers.length})",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (confirmedPassengers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          "No confirmed passengers yet",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                        itemCount: confirmedPassengers.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final p = confirmedPassengers[index];
                          final name = p['passengerName'] ?? 'Student';
                          final dept = p['department'] ?? 'IUB';
                          final seats = p['seats'] ?? 1;
                          final phone = p['phone'] ?? '';
                          final photo = p['photoURL'] as String?;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.emeraldGreen,
                              backgroundImage: (photo != null && photo.isNotEmpty)
                                  ? NetworkImage(photo)
                                  : null,
                              child: (photo == null || photo.isEmpty)
                                  ? Text(
                                      _getInitials(name),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "$dept · $seats seat${seats > 1 ? 's' : ''}",
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
                                          rideId: activeRideId!,
                                          otherUserName: name,
                                          otherUserPhoto: photo,
                                          pickupLocation: pickup,
                                          destination: destination,
                                        ),
                                      ),
                                    );
                                  },
                                  tooltip: "Chat with Passenger",
                                ),
                                if (phone.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.phone, color: Colors.green),
                                    onPressed: () => _makePhoneCall(phone),
                                    tooltip: "Call Passenger",
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // DRIVER ACTION BUTTONS
                  _buildDriverActionButtons(status),
                ],

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getBannerTitle(String status, bool isDriver) {
    switch (status) {
      case 'on_the_way':
        return isDriver ? "Trip in Progress" : "Driver is on the way";
      case 'arrived':
        return isDriver ? "Arrived at Pickup" : "Driver Arrived at Pickup";
      case 'completed':
        return "Ride Completed";
      default:
        return isDriver ? "Ride Scheduled" : "Trip Scheduled & Confirmed";
    }
  }

  String _getBannerSubtitle(String status, bool isDriver) {
    switch (status) {
      case 'on_the_way':
        return isDriver
            ? "Driving towards pickup chowk..."
            : "Driver is heading towards your pickup location.";
      case 'arrived':
        return isDriver
            ? "Waiting for passengers to board..."
            : "Vehicle has reached pickup spot. Please board!";
      case 'completed':
        return "Successfully reached destination.";
      default:
        return isDriver
            ? "Ready when you are. Tap 'Start Trip' below."
            : "Driver will start the journey shortly.";
    }
  }

  Widget _buildTripProgressStepper(String status) {
    final int currentStepIndex;
    if (status == 'on_the_way') {
      currentStepIndex = 2; // On the way
    } else if (status == 'arrived') {
      currentStepIndex = 3; // Arrived
    } else if (status == 'completed') {
      currentStepIndex = 4; // Completed
    } else {
      currentStepIndex = 1; // Confirmed / Ready
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepNode(1, currentStepIndex),
            _buildStepLine(1, currentStepIndex),
            _buildStepNode(2, currentStepIndex),
            _buildStepLine(2, currentStepIndex),
            _buildStepNode(3, currentStepIndex),
            _buildStepLine(3, currentStepIndex),
            _buildStepNode(4, currentStepIndex),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
              child: Text(
                "Ready",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.start,
              ),
            ),
            Expanded(
              child: Text(
                "On way",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                "Arrived",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                "Finished",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepNode(int step, int currentStep) {
    final isDone = step < currentStep;
    final isCurrent = step == currentStep;

    Color nodeColor = AppColors.coolGray;
    if (isDone) nodeColor = AppColors.mintGreen;
    if (isCurrent) nodeColor = Colors.orange;

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: nodeColor,
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: Colors.orange.shade200, width: 3) : null,
      ),
      child: isDone
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }

  Widget _buildStepLine(int step, int currentStep) {
    final isDone = step < currentStep;
    return Expanded(
      child: Container(
        height: 3,
        color: isDone ? AppColors.mintGreen : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildDriverActionButtons(String status) {
    if (isUpdatingStatus) {
      return const Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen));
    }

    if (status == 'active' || status == 'full') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateRideStatus(
            'on_the_way',
            "Trip started! Status updated to 'On the way'",
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            "Start Trip (On the Way)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emeraldGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    if (status == 'on_the_way') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateRideStatus(
            'arrived',
            "Marked as Arrived at pickup location",
          ),
          icon: const Icon(Icons.location_on),
          label: const Text(
            "Mark as Arrived at Pickup",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    if (status == 'arrived') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateRideStatus(
            'completed',
            "Ride marked as Completed! Safe journey.",
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text(
            "Complete Trip (Reached Campus)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text(
            "Trip Completed Successfully",
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
