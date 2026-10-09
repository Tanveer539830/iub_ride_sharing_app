import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/image_upload_service.dart';

class AdminDriverDetailScreen extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const AdminDriverDetailScreen({
    super.key,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<AdminDriverDetailScreen> createState() => _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends State<AdminDriverDetailScreen> {
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? vehicleData;
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCompleteDriverDossier();
  }

  Future<void> _loadCompleteDriverDossier() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch User Profile
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.driverId)
          .get();
      if (uDoc.exists) {
        userProfile = uDoc.data();
      }

      // 2. Fetch Vehicle Profile
      final vDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.driverId)
          .get();
      if (vDoc.exists) {
        vehicleData = vDoc.data();
      }
    } catch (e) {
      debugPrint("Error loading admin driver dossier: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
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
          SnackBar(content: Text("Could not call: $e")),
        );
      }
    }
  }

  void _viewFullImage(String imageUrl, String title) {
    if (ImageUploadService.isDummyUrl(imageUrl)) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ImageUploadService.buildImageWidget(
                  imageSource: imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: Container(
                    padding: const EdgeInsets.all(30),
                    color: Colors.white,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("Image could not be loaded"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveDriver() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen),
            SizedBox(width: 8),
            Text("Approve Driver?"),
          ],
        ),
        content: const Text(
          "This will grant the user verified driver status and immediately allow them to post rides on campus.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text("Yes, Approve"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update users collection
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.driverId);
      batch.set(userRef, {
        'driverStatus': 'approved',
        'hasVehicle': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update drivers collection
      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
      batch.set(driverRef, {
        'verificationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Driver approved successfully! 🎉"),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to approve driver: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> _rejectDriver() async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text("Reject Driver Application"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a reason so the student can rectify and resubmit their documents:",
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "e.g. Blurry CNIC back photo, driving license expired...",
                hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a rejection reason")),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Reject Application"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final reason = reasonController.text.trim();
    setState(() => isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.driverId);
      batch.set(userRef, {
        'driverStatus': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
      batch.set(driverRef, {
        'verificationStatus': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Driver application rejected with feedback: $reason"),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to reject driver: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driverData;
    final fullName = driver['fullName'] ?? userProfile?['fullName'] ?? "Driver Applicant";
    final email = userProfile?['email'] ?? "No email";
    final primaryPhone = driver['primaryPhone'] ?? userProfile?['phone'] ?? "";
    final secondaryPhone = driver['secondaryPhone'] ?? "";
    final cnicNumber = driver['cnicNumber'] ?? "N/A";
    final licenseNumber = driver['licenseNumber'] ?? "N/A";
    final cnicFrontUrl = driver['cnicFrontUrl'] ?? "";
    final cnicBackUrl = driver['cnicBackUrl'] ?? "";
    final licenseCardUrl = driver['licenseCardUrl'] ?? "";

    final vehicleType = vehicleData?['vehicleType'] ?? driver['vehicleType'] ?? "Vehicle";
    final make = vehicleData?['make'] ?? "";
    final model = vehicleData?['model'] ?? "";
    final year = vehicleData?['year'] ?? "";
    final regNumber = vehicleData?['regNumber'] ?? driver['vehicleRegNumber'] ?? "N/A";
    final color = vehicleData?['color'] ?? "";
    final frontPhotoUrl = vehicleData?['frontPhotoUrl'] ?? "";
    final backPhotoUrl = vehicleData?['backPhotoUrl'] ?? "";

    final status = (driver['verificationStatus'] ?? 'pending').toString().toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Driver Verification Review",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. APPLICANT OVERVIEW CARD
                  _buildApplicantHeaderCard(fullName, email, primaryPhone, secondaryPhone, status),

                  const SizedBox(height: 18),

                  // 2. CNIC IDENTIFICATION SECTION
                  _buildSectionCard(
                    title: "CNIC Identification",
                    icon: Icons.badge_rounded,
                    children: [
                      _buildInfoRow("CNIC Number", cnicNumber),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDocumentImagePreview(
                              title: "CNIC Front",
                              imageUrl: cnicFrontUrl,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDocumentImagePreview(
                              title: "CNIC Back",
                              imageUrl: cnicBackUrl,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 3. DRIVING LICENSE SECTION
                  _buildSectionCard(
                    title: "Driving License",
                    icon: Icons.credit_card_rounded,
                    children: [
                      _buildInfoRow("License Number", licenseNumber),
                      const SizedBox(height: 12),
                      _buildDocumentImagePreview(
                        title: "Driving License Card",
                        imageUrl: licenseCardUrl,
                        height: 150,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. VEHICLE SPECIFICATIONS & PHOTOS SECTION
                  _buildSectionCard(
                    title: "Vehicle Details",
                    icon: Icons.directions_car_filled_rounded,
                    children: [
                      _buildInfoRow("Category", vehicleType),
                      _buildInfoRow("Make & Model", "$make $model ($year)".trim()),
                      _buildInfoRow("Registration Number", regNumber),
                      _buildInfoRow("Color", color),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDocumentImagePreview(
                              title: "Vehicle Front",
                              imageUrl: frontPhotoUrl,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDocumentImagePreview(
                              title: "Vehicle Back / Plate",
                              imageUrl: backPhotoUrl,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // REJECT BUTTON
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : _rejectDriver,
                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                  label: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // APPROVE BUTTON
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isProcessing ? null : _approveDriver,
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Approve Driver", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicantHeaderCard(
    String name,
    String email,
    String primaryPhone,
    String secondaryPhone,
    String status,
  ) {
    Color statusBg = Colors.orange.shade50;
    Color statusColor = Colors.orange.shade800;
    String statusLabel = "PENDING REVIEW";

    if (status == 'approved') {
      statusBg = AppColors.mintWhisper;
      statusColor = AppColors.emeraldGreen;
      statusLabel = "APPROVED";
    } else if (status == 'rejected') {
      statusBg = Colors.red.shade50;
      statusColor = Colors.red.shade700;
      statusLabel = "REJECTED";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Primary Phone", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  Text(primaryPhone.isNotEmpty ? primaryPhone : "N/A", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  if (secondaryPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text("Secondary: $secondaryPhone", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ],
              ),
              if (primaryPhone.isNotEmpty)
                IconButton(
                  onPressed: () => _makePhoneCall(primaryPhone),
                  icon: const Icon(Icons.phone, color: AppColors.emeraldGreen),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.mintIce,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.emeraldGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(
            value.isNotEmpty ? value : "—",
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentImagePreview({
    required String title,
    required String imageUrl,
    double height = 110,
  }) {
    final hasImage = !ImageUploadService.isDummyUrl(imageUrl);

    return InkWell(
      onTap: hasImage ? () => _viewFullImage(imageUrl, title) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageUploadService.buildImageWidget(
                      imageSource: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 28),
                    const SizedBox(height: 4),
                    Text("No $title", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
      ),
    );
  }
}
