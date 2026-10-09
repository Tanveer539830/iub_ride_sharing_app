import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/image_upload_service.dart';
import 'package:iub_ride_sharing_app/screens/complete_profile.dart';
import 'package:iub_ride_sharing_app/screens/driver_all_rides.dart';
import 'package:iub_ride_sharing_app/screens/signing_screen.dart';
import 'package:iub_ride_sharing_app/screens/driver_registration/driver_personal_info.dart';
import 'package:iub_ride_sharing_app/screens/driver_registration/driver_verification_status.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  bool isLoading = true;
  String fullName = "Student";
  String department = "BS Information Technology";
  String gender = "Male";
  String defaultRoute = "City Chowk → Campus";
  String email = "";
  String? photoURL;
  double rating = 4.9;

  String driverStatus = 'not_registered'; // 'not_registered', 'pending', 'approved', 'rejected'
  Map<String, dynamic>? vehicleData;

  int ridesGivenCount = 0;
  int ridesTakenCount = 0;
  int moneySaved = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfileAndStats();
  }

  Future<void> _loadUserProfileAndStats() async {
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      email = user.email ?? "";

      // 1. Fetch User Profile Document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          fullName = data['fullName'] ?? user.displayName ?? "Student";
          department = data['department'] ?? "Information Technology";
          gender = data['gender'] ?? "Not specified";
          defaultRoute = data['defaultRoute'] ?? "Bahawalpur → IUB Campus";
          final rawPhoto = data['photoURL']?.toString();
          photoURL = ImageUploadService.isDummyUrl(rawPhoto) ? null : rawPhoto;
          driverStatus = (data['driverStatus'] ?? 'not_registered').toString();
          if (data['rating'] != null) {
            rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 4.9;
          }
        }
      }

      // 2. Fetch Vehicle Info if registered/hasVehicle
      if (driverStatus == 'approved' || driverStatus == 'pending') {
        try {
          final vDoc = await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(user.uid)
              .get();
          if (vDoc.exists) {
            vehicleData = vDoc.data();
          }
        } catch (e) {
          debugPrint("Error fetching vehicle: $e");
        }
      }

      // 3. Fetch Driver Stats (Rides Given)
      final givenSnap = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: user.uid)
          .get();

      ridesGivenCount = givenSnap.docs.length;

      // 4. Fetch Passenger Stats (Rides Taken / Requests Accepted)
      final takenSnap = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      ridesTakenCount = takenSnap.docs.length;

      // Estimate money saved (e.g. approx Rs 120 per ride shared)
      moneySaved = (ridesGivenCount * 100) + (ridesTakenCount * 80);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => isLoading = false);
    }
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Sign Out",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to sign out from IUB Rides?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SignIn()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.darkNavy).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.darkNavy, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadUserProfileAndStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // AVATAR / PROFILE PICTURE
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Builder(
                    builder: (context) {
                      final imgProvider = ImageUploadService.getImageProvider(photoURL);
                      return CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.coralRed,
                        backgroundImage: imgProvider,
                        child: imgProvider == null
                            ? Text(
                                _getInitials(fullName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CompleteProfile()),
                      );
                      _loadUserProfileAndStats();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // NAME & DETAILS
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$department · IUB",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),

              // RATING & VERIFIED BADGES
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "$rating",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.mintWhisper,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded, size: 12, color: AppColors.emeraldGreen),
                        SizedBox(width: 3),
                        Text(
                          "IUB STUDENT",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (driverStatus == 'approved') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 3),
                          Text(
                            "VERIFIED DRIVER",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // STATS COUNTER ROW
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          "$ridesGivenCount",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Rides given",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    Column(
                      children: [
                        Text(
                          "$ridesTakenCount",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Rides taken",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    Column(
                      children: [
                        Text(
                          "Rs ${moneySaved > 1000 ? '${(moneySaved / 1000).toStringAsFixed(1)}k' : moneySaved}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Est. Saved",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // DRIVER & VEHICLE STATUS CARD
              _buildDriverVehicleCard(),

              const SizedBox(height: 18),

              // ACTION MENU LIST
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: CupertinoIcons.person,
                      title: "Edit Profile",
                      subtitle: "Update name, department, gender & route",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CompleteProfile()),
                        );
                        _loadUserProfileAndStats();
                      },
                    ),
                    _buildMenuTile(
                      icon: CupertinoIcons.clock,
                      title: "My Posted Rides & History",
                      subtitle: "$ridesGivenCount rides created",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriverAllRidesScreen()),
                        );
                      },
                    ),
                    _buildMenuTile(
                      icon: CupertinoIcons.map_pin_ellipse,
                      title: "Default Route",
                      subtitle: defaultRoute,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CompleteProfile()),
                        );
                        _loadUserProfileAndStats();
                      },
                    ),
                    _buildMenuTile(
                      icon: CupertinoIcons.checkmark_shield,
                      title: "Safety & Campus Preferences",
                      subtitle: "Gender matching & verified student badge",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Account verified via IUB student registry"),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      icon: Icons.logout,
                      iconColor: Colors.red.shade600,
                      title: "Sign Out",
                      subtitle: email,
                      onTap: _showLogoutDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverVehicleCard() {
    if (driverStatus == 'approved') {
      final make = vehicleData?['make'] ?? '';
      final model = vehicleData?['model'] ?? '';
      final regNumber = vehicleData?['regNumber'] ?? 'Registered';
      final color = vehicleData?['color'] ?? '';
      final type = vehicleData?['vehicleType'] ?? 'Vehicle';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.emeraldGreen.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mintIce,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.emeraldGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Driver & Vehicle Profile",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black87),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mintWhisper,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "APPROVED",
                    style: TextStyle(color: AppColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$make $model".trim().isNotEmpty ? "$make $model ($type)" : type,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Plate: $regNumber ${color.isNotEmpty ? '· Color: $color' : ''}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
                      ).then((_) => _loadUserProfileAndStats());
                    },
                    child: const Text("Edit", style: TextStyle(color: AppColors.emeraldGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (driverStatus == 'pending') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Driver Verification Under Review",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.orange.shade900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Your documents are pending review by admin",
                      style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.orange.shade800),
            ],
          ),
        ),
      );
    }

    if (driverStatus == 'rejected') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.gpp_bad_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Driver Verification Action Required",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Tap to review issues and update documents",
                      style: TextStyle(fontSize: 11.5, color: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.red.shade800),
            ],
          ),
        ),
      );
    }

    // not_registered
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
        ).then((_) => _loadUserProfileAndStats());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.mintIce,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car_rounded, color: AppColors.emeraldGreen, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Become an IUB Driver",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Offer empty seats & earn fuel cost",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Register",
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
