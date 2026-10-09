import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/user_role_service.dart';
import 'package:iub_ride_sharing_app/services/image_upload_service.dart';
import 'package:iub_ride_sharing_app/screens/driver_all_rides.dart';
import 'package:iub_ride_sharing_app/screens/post_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/profile.dart';
import 'package:iub_ride_sharing_app/screens/signing_screen.dart';
import 'package:iub_ride_sharing_app/screens/driver_registration/driver_personal_info.dart';
import 'package:iub_ride_sharing_app/screens/driver_registration/driver_verification_status.dart';
import 'package:iub_ride_sharing_app/screens/admin/admin_driver_requests_screen.dart';
import 'find_a_ride.dart';
import 'my_rides.dart';

class Home extends StatefulWidget {
  final int initialIndex;
  const Home({super.key, this.initialIndex = 0});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late int selectedScreen;
  final List<Widget> screen = [
    const FindARide(),
    const MyRides(),
    const Profile()
  ];
  final List<String> titles = ["Find a Ride", "My Rides", "Profile"];

  String drawerName = "Student";
  String drawerEmail = "";
  String? drawerPhotoURL;
  String activeMode = 'passenger'; // 'passenger' or 'driver'
  String driverStatus = 'not_registered'; // 'not_registered', 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    selectedScreen = widget.initialIndex;
    _loadDrawerUserInfo();
  }

  Future<void> _loadDrawerUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    drawerEmail = user.email ?? "";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && mounted) {
          setState(() {
            drawerName = data['fullName'] ?? user.displayName ?? "Student";
            drawerPhotoURL = data['photoURL'];
            activeMode = (data['activeMode'] ?? 'passenger').toString();
            driverStatus = (data['driverStatus'] ?? 'not_registered').toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading drawer user info: $e");
    }
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

  Future<void> _handleModeSwitch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (driverStatus != 'approved') {
      Navigator.pop(context); // close drawer
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
      );
      return;
    }

    final newMode = activeMode == 'driver' ? 'passenger' : 'driver';
    final success = await UserRoleService.switchActiveMode(newMode);

    if (success && mounted) {
      setState(() {
        activeMode = newMode;
      });
      Navigator.pop(context); // Close drawer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMode == 'driver' ? "Switched to Driver Mode 🚗" : "Switched to Passenger Mode 🎒",
          ),
          backgroundColor: AppColors.emeraldGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user != null
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data != null) {
          drawerName = data['fullName'] ?? user?.displayName ?? "Student";
          drawerPhotoURL = data['photoURL'];
          activeMode = (data['activeMode'] ?? 'passenger').toString();
          driverStatus = (data['driverStatus'] ?? 'not_registered').toString();
        }

        final isDriverMode = activeMode == 'driver';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              titles[selectedScreen],
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            actions: [
              // MODE BADGE CHIP IN APP BAR
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    if (driverStatus == 'approved') {
                      _handleModeSwitch();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDriverMode
                          ? AppColors.darkNavy
                          : AppColors.emeraldGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDriverMode
                            ? AppColors.darkNavy
                            : AppColors.emeraldGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDriverMode ? Icons.directions_car_filled : Icons.directions_walk_rounded,
                          size: 14,
                          color: isDriverMode ? Colors.white : AppColors.emeraldGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDriverMode ? "Driver" : "Passenger",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDriverMode ? Colors.white : AppColors.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No new notifications")),
                  );
                },
                icon: const Icon(CupertinoIcons.bell),
                iconSize: 22,
                color: Colors.grey.shade900,
                tooltip: "Notifications",
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  currentAccountPicture: Builder(
                    builder: (context) {
                      final imgProvider = ImageUploadService.getImageProvider(drawerPhotoURL);
                      return CircleAvatar(
                        backgroundColor: AppColors.coralRed,
                        backgroundImage: imgProvider,
                        child: imgProvider == null
                            ? Text(
                                _getInitials(drawerName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  accountName: Row(
                    children: [
                      Flexible(
                        child: Text(
                          drawerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (driverStatus == 'approved')
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                    ],
                  ),
                  accountEmail: Text(
                    drawerEmail,
                    overflow: TextOverflow.ellipsis,
                  ),
                  decoration: const BoxDecoration(color: AppColors.darkNavy),
                ),
                const SizedBox(height: 8),

                // MODE TOGGLE / REGISTRATION CARD IN DRAWER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: _buildRoleDrawerCard(),
                ),

                const Divider(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "MAIN NAVIGATION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text("Find a Ride"),
                  selected: selectedScreen == 0,
                  selectedColor: AppColors.emeraldGreen,
                  onTap: () {
                    setState(() => selectedScreen = 0);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text("Post a Ride"),
                  onTap: () async {
                    Navigator.pop(context);
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PostARide()),
                    );
                    if (res == 1) {
                      setState(() => selectedScreen = 1);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.directions_car_outlined),
                  title: const Text("My Rides"),
                  selected: selectedScreen == 1,
                  selectedColor: AppColors.emeraldGreen,
                  onTap: () {
                    setState(() => selectedScreen = 1);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Profile"),
                  selected: selectedScreen == 2,
                  selectedColor: AppColors.emeraldGreen,
                  onTap: () {
                    setState(() => selectedScreen = 2);
                    Navigator.pop(context);
                  },
                ),

                const Divider(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "DRIVER & CARPOOLING",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // DYNAMIC DRIVER ACTION TILE
                _buildDriverActionTile(),

                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text("Ride History"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverAllRidesScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_border),
                  title: const Text("Ratings & Reviews"),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => selectedScreen = 2);
                  },
                ),

                // ADMIN PORTAL SECTION
                if (UserRoleService.isUserAdmin(user?.email, data)) ...[
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.security_rounded, size: 14, color: Colors.purple.shade700),
                        const SizedBox(width: 6),
                        Text(
                          "ADMINISTRATION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.admin_panel_settings_rounded, color: Colors.purple.shade700, size: 20),
                    ),
                    title: const Text(
                      "Driver Approvals Portal",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    subtitle: const Text("Review pending driver applications", style: TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Admin",
                        style: TextStyle(color: Colors.purple.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDriverRequestsScreen()),
                      );
                    },
                  ),
                ],

                const Divider(height: 20),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
          ),
          body: screen[selectedScreen],
          bottomNavigationBar: BottomNavigationBar(
            useLegacyColorScheme: true,
            selectedItemColor: AppColors.emeraldGreen,
            unselectedItemColor: Colors.grey,
            currentIndex: selectedScreen,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                selectedScreen = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: "Home",
                tooltip: "Find a Ride",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_car_outlined),
                label: "My Rides",
                tooltip: "Manage Offered & Joined Rides",
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person),
                label: "Profile",
                tooltip: "Student Profile & Stats",
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton(
            hoverColor: Colors.green,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostARide()),
              );
              if (result == 1) {
                setState(() {
                  selectedScreen = 1; // switch to My Rides
                });
              }
            },
            shape: const CircleBorder(),
            backgroundColor: Colors.red.shade500,
            elevation: 6,
            child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  Widget _buildRoleDrawerCard() {
    if (driverStatus == 'approved') {
      final isDriver = activeMode == 'driver';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDriver ? AppColors.darkNavy.withValues(alpha: 0.06) : AppColors.mintIce,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDriver ? AppColors.darkNavy.withValues(alpha: 0.2) : AppColors.emeraldGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isDriver ? Icons.directions_car_filled_rounded : Icons.directions_walk_rounded,
              color: isDriver ? AppColors.darkNavy : AppColors.emeraldGreen,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDriver ? "Driver Mode Active" : "Passenger Mode Active",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    isDriver ? "Offering seats to students" : "Searching & booking rides",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _handleModeSwitch,
              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.black87),
              tooltip: isDriver ? "Switch to Passenger" : "Switch to Driver",
            ),
          ],
        ),
      );
    }

    if (driverStatus == 'pending') {
      return InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Driver Verification Pending",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
                    ),
                    Text(
                      "Tap to view review status",
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.orange.shade800),
            ],
          ),
        ),
      );
    }

    if (driverStatus == 'rejected') {
      return InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.gpp_bad_rounded, color: Colors.red.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Verification Needs Update",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade900),
                    ),
                    Text(
                      "Tap to resubmit documents",
                      style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red.shade800),
            ],
          ),
        ),
      );
    }

    // not_registered
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.mintIce,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.drive_eta_rounded, color: AppColors.emeraldGreen, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Become a Driver",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    "Offer rides & split fuel costs",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "Register",
                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverActionTile() {
    if (driverStatus == 'approved') {
      return ListTile(
        leading: Icon(
          Icons.swap_horiz_rounded,
          color: activeMode == 'driver' ? Colors.blue.shade700 : AppColors.emeraldGreen,
        ),
        title: Text(
          activeMode == 'driver' ? "Switch to Passenger Mode" : "Switch to Driver Mode",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          activeMode == 'driver' ? "Currently driving" : "Currently passenger",
          style: const TextStyle(fontSize: 11),
        ),
        onTap: _handleModeSwitch,
      );
    }

    if (driverStatus == 'pending') {
      return ListTile(
        leading: Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800),
        title: const Text("Verification Status", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("Application under review", style: TextStyle(fontSize: 11)),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          );
        },
      );
    }

    if (driverStatus == 'rejected') {
      return ListTile(
        leading: Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
        title: const Text("Update Driver Info", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("Resubmit documents", style: TextStyle(fontSize: 11)),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          );
        },
      );
    }

    return ListTile(
      leading: const Icon(Icons.drive_eta_rounded, color: AppColors.emeraldGreen),
      title: const Text("Become a Driver", style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text("Register license & vehicle", style: TextStyle(fontSize: 11)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
        );
      },
    );
  }
}
