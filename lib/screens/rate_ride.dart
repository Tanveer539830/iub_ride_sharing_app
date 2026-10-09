import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/Home.dart';

class RateRide extends StatefulWidget {
  final String? rideId;
  final String? driverId;
  final String? driverName;

  const RateRide({
    super.key,
    this.rideId,
    this.driverId,
    this.driverName,
  });

  @override
  State<RateRide> createState() => _RateRideState();
}

class _RateRideState extends State<RateRide> {
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;

  String? _resolvedRideId;
  String? _resolvedDriverId;
  String _resolvedDriverName = "Driver";
  String? _resolvedDriverPhoto;
  String _resolvedRoute = "";

  final List<String> _feedbackTags = [
    "Punctual ⏱️",
    "Safe Driving 🚗",
    "Polite & Friendly 😊",
    "Clean Vehicle ✨",
    "Great Route 🗺️",
    "Good Music 🎵",
  ];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _resolveTripDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _resolveTripDetails() async {
    setState(() => _isLoading = true);

    _resolvedRideId = widget.rideId;
    _resolvedDriverId = widget.driverId;
    if (widget.driverName != null && widget.driverName!.isNotEmpty) {
      _resolvedDriverName = widget.driverName!;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // If rideId or driverId not passed, find the most recent completed ride for this passenger
      if (_resolvedRideId == null || _resolvedDriverId == null) {
        final reqSnap = await FirebaseFirestore.instance
            .collection('ride_requests')
            .where('passengerId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (final doc in reqSnap.docs) {
          final data = doc.data();
          final rId = data['rideId'] as String?;
          if (rId != null) {
            final rDoc = await FirebaseFirestore.instance.collection('rides').doc(rId).get();
            if (rDoc.exists) {
              final rData = rDoc.data();
              if (rData?['status'] == 'completed') {
                _resolvedRideId = rId;
                _resolvedDriverId = rData?['driverId'] as String?;
                final pickup = rData?['pickupLocation'] ?? '';
                final dest = rData?['destination'] ?? '';
                _resolvedRoute = "$pickup → $dest";
                break;
              }
            }
          }
        }
      } else {
        // Fetch ride info for route
        final rDoc = await FirebaseFirestore.instance.collection('rides').doc(_resolvedRideId).get();
        if (rDoc.exists) {
          final rData = rDoc.data();
          final pickup = rData?['pickupLocation'] ?? '';
          final dest = rData?['destination'] ?? '';
          _resolvedRoute = "$pickup → $dest";
          _resolvedDriverId ??= rData?['driverId'] as String?;
        }
      }

      // Fetch Driver Details from users collection
      if (_resolvedDriverId != null && _resolvedDriverId!.isNotEmpty) {
        final dDoc = await FirebaseFirestore.instance.collection('users').doc(_resolvedDriverId).get();
        if (dDoc.exists) {
          final dData = dDoc.data();
          _resolvedDriverName = dData?['fullName'] ?? _resolvedDriverName;
          _resolvedDriverPhoto = dData?['photoURL'] as String?;
        }
      }
    } catch (e) {
      debugPrint("Error resolving rating details: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getRatingLabel(int stars) {
    switch (stars) {
      case 1:
        return "Poor 😞";
      case 2:
        return "Fair 😐";
      case 3:
        return "Good 🙂";
      case 4:
        return "Very Good! 😊";
      case 5:
        return "Excellent! 🌟";
      default:
        return "";
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
    return "D";
  }

  Future<void> _submitRating() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to submit a review")),
      );
      return;
    }

    if (_resolvedDriverId == null || _resolvedDriverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver information not found")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Fetch passenger profile
      final pDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final pData = pDoc.data() ?? {};
      final pName = pData['fullName'] ?? 'Passenger';
      final pPhoto = pData['photoURL'] ?? '';

      // 2. Add review to ratings collection
      await FirebaseFirestore.instance.collection('ratings').add({
        'rideId': _resolvedRideId ?? '',
        'driverId': _resolvedDriverId,
        'passengerId': currentUser.uid,
        'passengerName': pName,
        'passengerPhotoURL': pPhoto,
        'rating': _selectedRating,
        'review': _commentController.text.trim(),
        'tags': _selectedTags.toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Recalculate Driver Average Rating and update user document
      final allDriverRatingsSnap = await FirebaseFirestore.instance
          .collection('ratings')
          .where('driverId', isEqualTo: _resolvedDriverId)
          .get();

      double totalScore = 0;
      final count = allDriverRatingsSnap.docs.length;
      for (final doc in allDriverRatingsSnap.docs) {
        final score = doc.data()['rating'];
        if (score is num) {
          totalScore += score.toDouble();
        }
      }
      final double newAvg = count > 0 ? (totalScore / count) : _selectedRating.toDouble();
      final double roundedAvg = double.parse(newAvg.toStringAsFixed(1));

      // Update Driver Profile
      await FirebaseFirestore.instance.collection('users').doc(_resolvedDriverId).update({
        'rating': roundedAvg,
        'ridesGivenCount': FieldValue.increment(1),
      });

      // 4. Update Passenger Profile ridesTakenCount
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'ridesTakenCount': FieldValue.increment(1),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit rating: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
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
                Icons.thumb_up_alt_rounded,
                color: AppColors.emeraldGreen,
                size: 50,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Thank You!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your rating has been submitted. Your feedback helps maintain a trusted and safe community at IUB.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
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
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Back to My Rides",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Rate Your Trip",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 1. CELEBRATION ICON
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.mintWhisper,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.emeraldGreen,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            "Ride Completed!",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          if (_resolvedRoute.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _resolvedRoute,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // DRIVER AVATAR & NAME
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.emeraldGreen,
                                backgroundImage: (_resolvedDriverPhoto != null && _resolvedDriverPhoto!.isNotEmpty)
                                    ? NetworkImage(_resolvedDriverPhoto!)
                                    : null,
                                child: (_resolvedDriverPhoto == null || _resolvedDriverPhoto!.isEmpty)
                                    ? Text(
                                        _getInitials(_resolvedDriverName),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  "How was your ride with $_resolvedDriverName?",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 2. INTERACTIVE STAR RATING
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNumber = index + 1;
                              final isSelected = starNumber <= _selectedRating;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedRating = starNumber),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isSelected ? Colors.amber : Colors.grey.shade300,
                                    size: 42,
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _getRatingLabel(_selectedRating),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 3. QUICK FEEDBACK TAG CHIPS
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "What went well?",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _feedbackTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.grey.shade800,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.emeraldGreen,
                                backgroundColor: Colors.grey.shade100,
                                checkmarkColor: Colors.white,
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.emeraldGreen : Colors.grey.shade300,
                                  ),
                                ),
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedTags.add(tag);
                                    } else {
                                      _selectedTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // 4. COMMENT TEXTFIELD
                          TextField(
                            controller: _commentController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Write a short comment for the driver (optional)...",
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 1.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 5. SUBMIT BUTTON
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRating,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              backgroundColor: AppColors.emeraldGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    "Submit Rating",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
