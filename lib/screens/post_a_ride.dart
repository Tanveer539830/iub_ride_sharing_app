import 'package:flutter/material.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/screens/driver_registration/driver_personal_info.dart';
import 'package:iub_ride_sharing_app/screens/driver_registration/driver_verification_status.dart';

class PostARide extends StatefulWidget {
  const PostARide({super.key});

  @override
  State<PostARide> createState() => _PostARideState();
}

class _PostARideState extends State<PostARide> {
  final pickUpController = TextEditingController();
  final destinationController = TextEditingController();
  final priceController = TextEditingController();
  int selectedSeats = 1;
  DateTime? selectedDateTime;
  bool isLoading = false;
  bool isCheckingStatus = true;
  String driverStatus = 'not_registered'; // 'not_registered', 'pending', 'approved', 'rejected'
  Map<String, dynamic>? vehicleData;

  @override
  void initState() {
    super.initState();
    _checkDriverEligibility();
  }

  Future<void> _checkDriverEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isCheckingStatus = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final status = (doc.data()?['driverStatus'] ?? 'not_registered').toString();

      if (status == 'approved') {
        final vDoc = await FirebaseFirestore.instance.collection('vehicles').doc(user.uid).get();
        if (vDoc.exists) {
          vehicleData = vDoc.data();
        }
      }

      if (mounted) {
        setState(() {
          driverStatus = status;
          isCheckingStatus = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking driver eligibility: $e");
      if (mounted) setState(() => isCheckingStatus = false);
    }
  }

  @override
  void dispose() {
    pickUpController.dispose();
    destinationController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 15)),
      initialDate: selectedDateTime ?? now,
    );

    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: selectedDateTime != null
          ? TimeOfDay(hour: selectedDateTime!.hour, minute: selectedDateTime!.minute)
          : TimeOfDay.now(),
    );

    if (time == null) return;

    final pickedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Validation: cannot select past time if today is selected
    if (pickedDateTime.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a future departure time")),
        );
      }
      return;
    }

    setState(() {
      selectedDateTime = pickedDateTime;
    });
  }

  Future<void> _postRide() async {
    final pickup = pickUpController.text.trim();
    final destination = destinationController.text.trim();
    final priceText = priceController.text.trim();

    // 1. Validations
    if (pickup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter pickup location")),
      );
      return;
    }

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter destination")),
      );
      return;
    }

    if (selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select departure date & time")),
      );
      return;
    }

    if (selectedDateTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Departure time must be in the future")),
      );
      return;
    }

    if (priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter cost per seat")),
      );
      return;
    }

    final price = int.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid price (greater than 0)")),
      );
      return;
    }

    // 2. Auth check
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in before posting a ride")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 3. Save to Firestore 'rides' collection
      await FirebaseFirestore.instance.collection('rides').add({
        'driverId': user.uid,
        'pickupLocation': pickup,
        'destination': destination,
        'price': price,
        'totalSeats': selectedSeats,
        'availableSeats': selectedSeats,
        'status': 'active', // active, full, completed, cancelled
        'dateTime': Timestamp.fromDate(selectedDateTime!),
        'vehicleType': vehicleData?['vehicleType'] ?? 'Car',
        'vehicleModel': "${vehicleData?['make'] ?? ''} ${vehicleData?['model'] ?? ''}".trim(),
        'vehicleRegNumber': vehicleData?['regNumber'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ride posted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        // Return 1 so Home screen switches to My Rides tab
        Navigator.pop(context, 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post ride: $e")),
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

  Widget _buildNotApprovedView() {
    IconData icon;
    Color color;
    String title;
    String description;
    String btnText;
    VoidCallback onBtnPressed;

    if (driverStatus == 'pending') {
      icon = Icons.hourglass_top_rounded;
      color = Colors.orange.shade700;
      title = "Verification in Progress";
      description = "Your driver documents and vehicle details are currently under review by the IUB transport admin. You can post rides as soon as your account is verified.";
      btnText = "View Verification Status";
      onBtnPressed = () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
        );
      };
    } else if (driverStatus == 'rejected') {
      icon = Icons.gpp_bad_rounded;
      color = Colors.red.shade700;
      title = "Verification Needs Update";
      description = "Your driver verification could not be approved. Please review the feedback and update your documents to enable ride posting.";
      btnText = "Update Driver Documents";
      onBtnPressed = () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverVerificationStatusScreen()),
        );
      };
    } else {
      icon = Icons.drive_eta_rounded;
      color = AppColors.emeraldGreen;
      title = "Become an Approved Driver";
      description = "To ensure student safety, only verified IUB drivers can offer rides and post empty seats. Complete your driver & vehicle registration to get started.";
      btnText = "Start Driver Registration";
      onBtnPressed = () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverPersonalInfoScreen()),
        );
      };
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 54, color: color),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: onBtnPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.emeraldGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingStatus) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen)),
      );
    }

    if (driverStatus != 'approved') {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Post a Ride", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _buildNotApprovedView(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Post a ride",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Offer your seats to nearby students",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // FROM / PICKUP INPUT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FROM",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: pickUpController,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                hintText: "From (e.g. City Chowk)",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // TO / DESTINATION INPUT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TO",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: destinationController,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                hintText: "To (e.g. Baghdad-ul-Jadeed Campus)",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // DATE & TIME AND SEATS ROW
                Row(
                  children: [
                    // DATE & TIME PICKER
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: _selectDateTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "DATE & TIME",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedDateTime == null
                                    ? "Select date & time"
                                    : "${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year}  ${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: selectedDateTime == null
                                      ? Colors.grey.shade500
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // SEATS PICKER
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          final seats = await showDialog<int>(
                            context: context,
                            builder: (context) {
                              return SimpleDialog(
                                title: const Text("Select seats offered"),
                                children: [1, 2, 3, 4].map((s) {
                                  return SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, s),
                                    child: Text("$s seat${s > 1 ? 's' : ''}"),
                                  );
                                }).toList(),
                              );
                            },
                          );

                          if (seats != null) {
                            setState(() {
                              selectedSeats = seats;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SEATS",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$selectedSeats available',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // COST PER SEAT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "COST PER SEAT (RS)",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: priceController,
                        textAlign: TextAlign.start,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: "e.g. 100",
                          hintStyle: TextStyle(fontSize: 16, color: Colors.black54),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // PUBLISH BUTTON
                GestureDetector(
                  onTap: isLoading ? null : _postRide,
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
                              "Publish ride",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    "Passengers matching this route will see your ride",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
