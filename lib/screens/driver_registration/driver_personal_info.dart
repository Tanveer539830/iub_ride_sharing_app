import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/image_upload_service.dart';
import 'vehicle_info_screen.dart';

class DriverPersonalInfoScreen extends StatefulWidget {
  const DriverPersonalInfoScreen({super.key});

  @override
  State<DriverPersonalInfoScreen> createState() => _DriverPersonalInfoScreenState();
}

class _DriverPersonalInfoScreenState extends State<DriverPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _licenseController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();

  XFile? _cnicFrontImage;
  XFile? _cnicBackImage;
  XFile? _licenseImage;

  String? _existingCnicFrontUrl;
  String? _existingCnicBackUrl;
  String? _existingLicenseUrl;

  bool _isLoading = false;
  bool _isInitialLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingDriverData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _licenseController.dispose();
    _primaryPhoneController.dispose();
    _secondaryPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDriverData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isInitialLoading = false);
      return;
    }

    try {
      // 1. Fetch from users collection
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (uDoc.exists) {
        final uData = uDoc.data() ?? {};
        _nameController.text = uData['fullName'] ?? user.displayName ?? '';
        _primaryPhoneController.text = uData['phone'] ?? '';
      }

      // 2. Fetch existing driver doc if previously submitted
      final dDoc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
      if (dDoc.exists) {
        final dData = dDoc.data() ?? {};
        if (dData['fullName'] != null && dData['fullName'].toString().isNotEmpty) {
          _nameController.text = dData['fullName'];
        }
        _cnicController.text = dData['cnicNumber'] ?? '';
        _licenseController.text = dData['licenseNumber'] ?? '';
        if (dData['primaryPhone'] != null) {
          _primaryPhoneController.text = dData['primaryPhone'];
        }
        _secondaryPhoneController.text = dData['secondaryPhone'] ?? '';
        final rawFront = dData['cnicFrontUrl']?.toString();
        final rawBack = dData['cnicBackUrl']?.toString();
        final rawLicense = dData['licenseCardUrl']?.toString();
        _existingCnicFrontUrl = ImageUploadService.isDummyUrl(rawFront) ? null : rawFront;
        _existingCnicBackUrl = ImageUploadService.isDummyUrl(rawBack) ? null : rawBack;
        _existingLicenseUrl = ImageUploadService.isDummyUrl(rawLicense) ? null : rawLicense;
      }
    } catch (e) {
      debugPrint("Error preloading driver info: $e");
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _pickImage(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 36, color: AppColors.emeraldGreen),
                    SizedBox(height: 8),
                    Text("Take Photo", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_rounded, size: 36, color: AppColors.emeraldGreen),
                    SizedBox(height: 8),
                    Text("Choose Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 75);
      if (picked != null) {
        setState(() {
          if (type == 'cnic_front') _cnicFrontImage = picked;
          if (type == 'cnic_back') _cnicBackImage = picked;
          if (type == 'license') _licenseImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image: $e")),
        );
      }
    }
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cnicFrontImage == null && _existingCnicFrontUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload CNIC Front picture")),
      );
      return;
    }

    if (_cnicBackImage == null && _existingCnicBackUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload CNIC Back picture")),
      );
      return;
    }

    if (_licenseImage == null && _existingLicenseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload Driving License picture")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? cnicFrontUrl = _existingCnicFrontUrl;
      String? cnicBackUrl = _existingCnicBackUrl;
      String? licenseUrl = _existingLicenseUrl;

      // 1. Upload Images to Firebase Storage / Base64 fallback
      if (_cnicFrontImage != null) {
        cnicFrontUrl = await ImageUploadService.uploadImage(
          file: _cnicFrontImage!,
          storagePath: 'driver_documents/${user.uid}/cnic_front.jpg',
        );
      }

      if (_cnicBackImage != null) {
        cnicBackUrl = await ImageUploadService.uploadImage(
          file: _cnicBackImage!,
          storagePath: 'driver_documents/${user.uid}/cnic_back.jpg',
        );
      }

      if (_licenseImage != null) {
        licenseUrl = await ImageUploadService.uploadImage(
          file: _licenseImage!,
          storagePath: 'driver_documents/${user.uid}/license_card.jpg',
        );
      }

      // 2. Save Driver Document in Firestore
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
        'driverId': user.uid,
        'fullName': _nameController.text.trim(),
        'cnicNumber': _cnicController.text.trim(),
        'cnicFrontUrl': cnicFrontUrl ?? '',
        'cnicBackUrl': cnicBackUrl ?? '',
        'licenseNumber': _licenseController.text.trim().toUpperCase(),
        'licenseCardUrl': licenseUrl ?? '',
        'primaryPhone': _primaryPhoneController.text.trim(),
        'secondaryPhone': _secondaryPhoneController.text.trim(),
        'verificationStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        // Proceed to Step 2: Vehicle Information
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VehicleInfoScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save driver details: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Driver Registration (Step 1/2)",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PROGRESS INDICATOR
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.emeraldGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Personal & License Details",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Upload your official documents for campus verification and safety compliance.",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),

                      // FULL NAME
                      _buildLabel("FULL NAME (AS PER CNIC)"),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter full name" : null,
                        decoration: _buildInputDecoration(hint: "e.g. Muhammad Ali", icon: Icons.person_outline),
                      ),
                      const SizedBox(height: 16),

                      // CNIC NUMBER
                      _buildLabel("CNIC NUMBER (WITH DASHES)"),
                      TextFormField(
                        controller: _cnicController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Please enter CNIC number";
                          final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
                          if (clean.length != 13) return "CNIC must be 13 digits (e.g. 31202-1234567-1)";
                          return null;
                        },
                        decoration: _buildInputDecoration(hint: "31202-1234567-1", icon: Icons.credit_card_outlined),
                      ),
                      const SizedBox(height: 16),

                      // CNIC FRONT & BACK UPLOAD CARDS
                      _buildLabel("CNIC FRONT & BACK PICTURES"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDocUploadCard(
                              title: "CNIC Front",
                              file: _cnicFrontImage,
                              networkUrl: _existingCnicFrontUrl,
                              onTap: () => _pickImage('cnic_front'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDocUploadCard(
                              title: "CNIC Back",
                              file: _cnicBackImage,
                              networkUrl: _existingCnicBackUrl,
                              onTap: () => _pickImage('cnic_back'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // DRIVING LICENSE NUMBER
                      _buildLabel("DRIVING LICENSE NUMBER"),
                      TextFormField(
                        controller: _licenseController,
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter license number" : null,
                        decoration: _buildInputDecoration(hint: "e.g. BWP-123456", icon: Icons.drive_eta_outlined),
                      ),
                      const SizedBox(height: 16),

                      // DRIVING LICENSE CARD UPLOAD
                      _buildLabel("DRIVING LICENSE PICTURE"),
                      _buildDocUploadCard(
                        title: "Driving License Card",
                        file: _licenseImage,
                        networkUrl: _existingLicenseUrl,
                        onTap: () => _pickImage('license'),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 20),

                      // PRIMARY PHONE
                      _buildLabel("PRIMARY PHONE (CALLS & SMS)"),
                      TextFormField(
                        controller: _primaryPhoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Please enter primary phone";
                          final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
                          if (clean.length < 10) return "Enter a valid phone number";
                          return null;
                        },
                        decoration: _buildInputDecoration(hint: "03001234567", icon: Icons.phone_outlined),
                      ),
                      const SizedBox(height: 16),

                      // SECONDARY PHONE (OPTIONAL)
                      _buildLabel("SECONDARY PHONE / EMERGENCY (OPTIONAL)"),
                      TextFormField(
                        controller: _secondaryPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _buildInputDecoration(hint: "03011234567 (Optional)", icon: Icons.phone_android_outlined),
                      ),
                      const SizedBox(height: 28),

                      // NEXT BUTTON
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleNext,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: AppColors.emeraldGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Next: Vehicle Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 1.5),
      ),
    );
  }

  Widget _buildDocUploadCard({
    required String title,
    required XFile? file,
    required String? networkUrl,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    final hasRealNetworkImage = networkUrl != null && !ImageUploadService.isDummyUrl(networkUrl);
    final hasImage = file != null || hasRealNetworkImage;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(14),
        color: hasImage ? AppColors.emeraldGreen : Colors.grey.shade400,
        strokeWidth: 1.2,
        dashPattern: const [6, 4],
        child: Container(
          height: isFullWidth ? 130 : 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasImage ? AppColors.mintIce.withValues(alpha: 0.3) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImageUploadService.buildImageWidget(
                        localXFile: file,
                        imageSource: hasRealNetworkImage ? networkUrl : null,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 30, color: Colors.grey.shade600),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      "Tap to upload",
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
