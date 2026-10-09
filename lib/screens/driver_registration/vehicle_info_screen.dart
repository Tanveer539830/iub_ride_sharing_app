import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/image_upload_service.dart';
import 'driver_verification_status.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _colorController = TextEditingController();

  // Selected Vehicle Type
  String _selectedVehicleType = 'Sedan';
  final List<String> _vehicleTypes = [
    'Sedan',
    'Hatchback',
    'SUV',
    'Van',
    'Car',
    'Bike / Motorcycle',
    'Other',
  ];

  // Images
  XFile? _frontImage;
  XFile? _backImage;

  String? _existingFrontUrl;
  String? _existingBackUrl;

  bool _isLoading = false;
  bool _isInitialLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingVehicleData();
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _regNumberController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingVehicleData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isInitialLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('vehicles').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final type = data['vehicleType']?.toString() ?? 'Sedan';
        if (_vehicleTypes.contains(type)) {
          _selectedVehicleType = type;
        } else {
          _selectedVehicleType = 'Other';
        }

        _makeController.text = data['make']?.toString() ?? '';
        _modelController.text = data['model']?.toString() ?? '';
        _yearController.text = data['year']?.toString() ?? '';
        _regNumberController.text = data['regNumber']?.toString() ?? '';
        _colorController.text = data['color']?.toString() ?? '';

        final rawFront = data['frontPhotoUrl']?.toString();
        final rawBack = data['backPhotoUrl']?.toString();
        _existingFrontUrl = ImageUploadService.isDummyUrl(rawFront) ? null : rawFront;
        _existingBackUrl = ImageUploadService.isDummyUrl(rawBack) ? null : rawBack;
      }
    } catch (e) {
      debugPrint("Error loading existing vehicle data: $e");
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _pickImage(String target) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.emeraldGreen),
                title: const Text("Take Photo with Camera"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                  );
                  if (picked != null) {
                    setState(() {
                      if (target == 'front') _frontImage = picked;
                      if (target == 'back') _backImage = picked;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.emeraldGreen),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 75,
                  );
                  if (picked != null) {
                    setState(() {
                      if (target == 'front') _frontImage = picked;
                      if (target == 'back') _backImage = picked;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check images
    if (_frontImage == null && _existingFrontUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload Vehicle Front picture")),
      );
      return;
    }

    if (_backImage == null && _existingBackUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload Vehicle Back / Plate picture")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? frontUrl = _existingFrontUrl;
      String? backUrl = _existingBackUrl;

      // 1. Upload Vehicle Images (Firebase Storage or Base64 fallback)
      if (_frontImage != null) {
        frontUrl = await ImageUploadService.uploadImage(
          file: _frontImage!,
          storagePath: 'vehicle_images/${user.uid}/front.jpg',
        );
      }

      if (_backImage != null) {
        backUrl = await ImageUploadService.uploadImage(
          file: _backImage!,
          storagePath: 'vehicle_images/${user.uid}/back.jpg',
        );
      }

      // 2. Save Vehicle Document
      await FirebaseFirestore.instance.collection('vehicles').doc(user.uid).set({
        'userId': user.uid,
        'vehicleType': _selectedVehicleType,
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'year': _yearController.text.trim(),
        'regNumber': _regNumberController.text.trim().toUpperCase(),
        'color': _colorController.text.trim(),
        'frontPhotoUrl': frontUrl ?? '',
        'backPhotoUrl': backUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update User Document & Driver Document
      final batch = FirebaseFirestore.instance.batch();

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.set(userRef, {
        'driverStatus': 'pending',
        'hasVehicle': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(user.uid);
      batch.set(driverRef, {
        'hasVehicle': true,
        'verificationStatus': 'pending',
        'vehicleType': _selectedVehicleType,
        'vehicleRegNumber': _regNumberController.text.trim().toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Driver & Vehicle details submitted for verification!"),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );

        // Move to Driver Verification Status Screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save vehicle details: $e"),
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
    if (_isInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Driver Registration",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Step 2 of 2: Vehicle Information",
              style: TextStyle(
                color: AppColors.emeraldGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Progress Indicator
                _buildProgressHeader(),

                const SizedBox(height: 20),

                // SECTION 1: VEHICLE TYPE
                _buildSectionTitle("1. Vehicle Category", Icons.directions_car_filled_rounded),
                const SizedBox(height: 10),
                _buildVehicleTypeSelector(),

                const SizedBox(height: 22),

                // SECTION 2: VEHICLE SPECIFICATIONS
                _buildSectionTitle("2. Vehicle Specifications", Icons.tune_rounded),
                const SizedBox(height: 12),

                // Make & Model Row
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _makeController,
                        label: "Make / Brand",
                        hint: "e.g. Toyota, Honda",
                        icon: Icons.branding_watermark_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _modelController,
                        label: "Model",
                        hint: "e.g. Corolla, Civic",
                        icon: Icons.model_training_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Year & Color Row
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _yearController,
                        label: "Model Year",
                        hint: "e.g. 2021",
                        keyboardType: TextInputType.number,
                        icon: Icons.calendar_today_rounded,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Required";
                          final year = int.tryParse(val.trim());
                          if (year == null || year < 1990 || year > DateTime.now().year + 1) {
                            return "Invalid year";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _colorController,
                        label: "Color",
                        hint: "e.g. White, Black",
                        icon: Icons.color_lens_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Registration Number
                _buildTextField(
                  controller: _regNumberController,
                  label: "Vehicle Registration / License Plate",
                  hint: "e.g. LEA-20-4521 or BWP-8910",
                  textCapitalization: TextCapitalization.characters,
                  icon: Icons.pin_rounded,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Please enter registration number";
                    if (val.trim().length < 4) return "Enter a valid plate number";
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // SECTION 3: VEHICLE PHOTOS
                _buildSectionTitle("3. Vehicle Photos", Icons.add_a_photo_rounded),
                const SizedBox(height: 6),
                Text(
                  "Upload clear photos of your vehicle front (with plate visible) and back.",
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildImageUploadBox(
                        title: "Front Photo",
                        imageFile: _frontImage,
                        networkUrl: _existingFrontUrl,
                        onTap: () => _pickImage('front'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildImageUploadBox(
                        title: "Back / Plate Photo",
                        imageFile: _backImage,
                        networkUrl: _existingBackUrl,
                        onTap: () => _pickImage('back'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // SUBMIT BUTTON
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: AppColors.emeraldGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                            Text(
                              "Submit for Verification",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline_rounded, size: 20),
                          ],
                        ),
                ),

                const SizedBox(height: 14),

                Center(
                  child: Text(
                    "🔒 All vehicle & driver details are verified securely by IUB",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildStepDot("1", "Personal", isDone: true, isActive: false),
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.emeraldGreen,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          _buildStepDot("2", "Vehicle", isDone: false, isActive: true),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          _buildStepDot("3", "Verification", isDone: false, isActive: false),
        ],
      ),
    );
  }

  Widget _buildStepDot(String number, String label, {required bool isDone, required bool isActive}) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.emeraldGreen
                : (isActive ? AppColors.emeraldGreen : Colors.grey.shade300),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    number,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isActive || isDone ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.emeraldGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVehicleType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.emeraldGreen),
          items: _vehicleTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Row(
                children: [
                  Icon(
                    type.contains('Bike') ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                    color: AppColors.emeraldGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    type,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedVehicleType = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        style: const TextStyle(fontSize: 14.5, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: AppColors.emeraldGreen, size: 20),
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
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildImageUploadBox({
    required String title,
    required XFile? imageFile,
    required String? networkUrl,
    required VoidCallback onTap,
  }) {
    final hasRealNetworkImage = networkUrl != null && !ImageUploadService.isDummyUrl(networkUrl);
    final hasImage = imageFile != null || hasRealNetworkImage;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(14),
        color: hasImage ? AppColors.emeraldGreen : Colors.grey.shade400,
        strokeWidth: 1.5,
        dashPattern: const [6, 4],
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasImage ? AppColors.mintIce.withValues(alpha: 0.3) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImageUploadService.buildImageWidget(
                        localXFile: imageFile,
                        imageSource: hasRealNetworkImage ? networkUrl : null,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Tap to change",
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, color: Colors.grey.shade400, size: 30),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
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
