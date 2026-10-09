import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/services/image_upload_service.dart';
import 'package:iub_ride_sharing_app/screens/Home.dart';

class CompleteProfile extends StatefulWidget {
  const CompleteProfile({super.key});

  @override
  State<CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<CompleteProfile> {
  String? selectedGender;
  XFile? selectedImage;
  String? existingPhotoURL;
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _defaultRouteController = TextEditingController();
  bool isLoading = false;
  bool isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _defaultRouteController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isInitialLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && mounted) {
          _nameController.text = data['fullName'] ?? user.displayName ?? '';
          _departmentController.text = data['department'] ?? '';
          _defaultRouteController.text = data['defaultRoute'] ?? '';
          selectedGender = data['gender'];
          final rawPhoto = data['photoURL']?.toString();
          existingPhotoURL = ImageUploadService.isDummyUrl(rawPhoto) ? null : rawPhoto;
        }
      } else {
        _nameController.text = user.displayName ?? '';
      }
    } catch (e) {
      debugPrint("Error preloading profile: $e");
    } finally {
      if (mounted) {
        setState(() => isInitialLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image picker error: $e")),
        );
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take Photo (Camera)"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    final department = _departmentController.text.trim();
    final defaultRoute = _defaultRouteController.text.trim();

    if (name.isEmpty ||
        department.isEmpty ||
        defaultRoute.isEmpty ||
        selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and select gender")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No user is currently signed in");
      }

      String? uploadedPhotoURL = existingPhotoURL;

      // 1. Upload Profile Photo to Firebase Storage / Base64 fallback
      if (selectedImage != null) {
        try {
          uploadedPhotoURL = await ImageUploadService.uploadImage(
            file: selectedImage!,
            storagePath: 'profile_images/${user.uid}.jpg',
          );

          if (!uploadedPhotoURL.startsWith('data:')) {
            await user.updatePhotoURL(uploadedPhotoURL);
          }
        } catch (storageError) {
          debugPrint("Profile image upload warning: $storageError");
        }
      }

      // 2. Update Firestore User Document
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        'uid': user.uid,
        'fullName': name,
        'email': user.email ?? '',
        'department': department,
        'gender': selectedGender,
        'defaultRoute': defaultRoute,
        'photoURL': uploadedPhotoURL ?? '',
        'isProfileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (user.displayName != name) {
        await user.updateDisplayName(name);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Home()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving profile: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Complete your profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Helps other students recognize and trust you on campus",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // AVATAR PICKER
              Center(
                child: GestureDetector(
                  onTap: _showImagePicker,
                  child: DottedBorder(
                    color: Colors.grey.shade400,
                    strokeWidth: 1.5,
                    dashPattern: const [6, 4],
                    borderType: BorderType.Circle,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade50,
                      ),
                      child: (selectedImage != null || (existingPhotoURL != null && !ImageUploadService.isDummyUrl(existingPhotoURL)))
                          ? ClipOval(
                              child: ImageUploadService.buildImageWidget(
                                localXFile: selectedImage,
                                imageSource: existingPhotoURL,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.grey.shade500,
                                  size: 32,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Photo",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // FULL NAME INPUT
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "FULL NAME",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        border: InputBorder.none,
                        hintText: "Enter full name",
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // DEPARTMENT INPUT
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DEPARTMENT",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.school_outlined),
                        border: InputBorder.none,
                        hintText: "e.g. BS Information Technology",
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // GENDER SELECTION
              Text(
                "GENDER",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = "Male"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedGender == "Male"
                              ? AppColors.mintWhisper
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedGender == "Male"
                                ? AppColors.emeraldGreen
                                : Colors.grey.shade300,
                            width: selectedGender == "Male" ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Male",
                          style: TextStyle(
                            color: selectedGender == "Male"
                                ? Colors.green.shade800
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = "Female"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedGender == "Female"
                              ? AppColors.mintWhisper
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedGender == "Female"
                                ? AppColors.emeraldGreen
                                : Colors.grey.shade300,
                            width: selectedGender == "Female" ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Female",
                          style: TextStyle(
                            color: selectedGender == "Female"
                                ? Colors.green.shade800
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // DEFAULT ROUTE INPUT
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DEFAULT ROUTE",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextField(
                      controller: _defaultRouteController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: InputBorder.none,
                        hintText: "e.g. City Chowk → Baghdad-ul-Jadeed Campus",
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // SAVE & CONTINUE BUTTON
              GestureDetector(
                onTap: isLoading ? null : _saveAndContinue,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isLoading
                        ? AppColors.emeraldGreen.withValues(alpha: 0.6)
                        : AppColors.emeraldGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Save & continue",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
