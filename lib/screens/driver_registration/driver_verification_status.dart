import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/user_role_service.dart';
import 'package:iub_ride_sharing_app/screens/Home.dart';
import 'driver_personal_info.dart';

class DriverVerificationStatusScreen extends StatelessWidget {
  final bool showBackButton;
  const DriverVerificationStatusScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Driver Status")),
        body: const Center(child: Text("Please sign in to view status")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const Home()),
                    (route) => false,
                  );
                },
              )
            : null,
        title: const Text(
          "Driver Verification",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.emeraldGreen),
            );
          }

          final data = snapshot.data?.data();
          final status = (data?['driverStatus'] ?? 'not_registered').toString();
          final rejectionReason = data?['rejectionReason']?.toString();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: _buildStatusContent(context, status, rejectionReason),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, String status, String? rejectionReason) {
    switch (status) {
      case 'approved':
        return _buildApprovedState(context);
      case 'rejected':
        return _buildRejectedState(context, rejectionReason);
      case 'pending':
        return _buildPendingState(context);
      case 'not_registered':
      default:
        return _buildNotRegisteredState(context);
    }
  }

  // 1. PENDING STATE
  Widget _buildPendingState(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.shade200, width: 2),
          ),
          child: Icon(
            Icons.hourglass_top_rounded,
            size: 46,
            color: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Verification in Progress",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your CNIC, Driving License, and Vehicle registration details are currently being reviewed by the IUB Transport Admin team.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Timeline Step Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
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
              _buildTimelineRow(
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.emeraldGreen,
                title: "Application Submitted",
                subtitle: "Personal & vehicle documents uploaded",
                isLast: false,
              ),
              _buildTimelineRow(
                icon: Icons.sync_rounded,
                iconColor: Colors.orange.shade700,
                title: "Document Verification",
                subtitle: "Under review by university admin",
                isLast: false,
              ),
              _buildTimelineRow(
                icon: Icons.lock_clock_rounded,
                iconColor: Colors.grey.shade400,
                title: "Driver Activation",
                subtitle: "Unlock ride posting & driver dashboard",
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Info Notice Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.mintIce,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.emeraldGreen, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "You don't have to wait! You can continue using IUB Rides as a Passenger to search, book, and share rides anytime.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Passenger Home Button
        ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Home()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.emeraldGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Continue as Passenger", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Edit Registration Button
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: Colors.grey.shade800,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Edit Submitted Details", style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // 2. APPROVED STATE
  Widget _buildApprovedState(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.mintWhisper,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.emeraldGreen, width: 2),
          ),
          child: const Icon(
            Icons.verified_rounded,
            size: 50,
            color: AppColors.emeraldGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "You're an Approved Driver! 🎉",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your documents and vehicle have been verified. You can now post rides, offer empty seats to campus, and manage ride requests.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Enter Driver Mode Button
        ElevatedButton(
          onPressed: () async {
            await UserRoleService.switchActiveMode('driver');
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const Home()),
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.emeraldGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_rounded, size: 20),
              SizedBox(width: 8),
              Text("Switch to Driver Mode", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Stay in Passenger Mode Button
        OutlinedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Home()),
              (route) => false,
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: Colors.grey.shade800,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Continue as Passenger", style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // 3. REJECTED STATE
  Widget _buildRejectedState(BuildContext context, String? reason) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red.shade200, width: 2),
          ),
          child: Icon(
            Icons.gpp_bad_rounded,
            size: 46,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Verification Needs Attention",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your driver application could not be approved due to missing or unclear information.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Rejection Reason Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Reason for Rejection",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reason != null && reason.isNotEmpty
                    ? reason
                    : "Document photos were blurry or license details did not match IUB records. Please re-upload clear photos.",
                style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.35),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Edit & Reapply Button
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.emeraldGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_document, size: 18),
              SizedBox(width: 8),
              Text("Edit & Resubmit Application", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Passenger Home Button
        OutlinedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Home()),
              (route) => false,
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: Colors.grey.shade800,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Continue as Passenger", style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // 4. NOT REGISTERED STATE
  Widget _buildNotRegisteredState(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.mintIce,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            size: 46,
            color: AppColors.emeraldGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Become an IUB Driver",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Register your vehicle and license to post rides, offer empty seats to students, and split your fuel costs.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.emeraldGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            "Start Driver Registration",
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Home()),
              (route) => false,
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: Colors.grey.shade800,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Continue as Passenger", style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
