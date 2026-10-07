import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/screens/find_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/my_rides.dart';
import 'package:iub_ride_sharing_app/screens/profile.dart';

class PostARide extends StatefulWidget {
  const PostARide({super.key});

  @override
  State<PostARide> createState() => _PostARideState();
}

///Ya actual screen ka state ya data managemnet screen ya area hai
class _PostARideState extends State<PostARide> {
  final pickUpController = TextEditingController();
  final destinationController = TextEditingController();
  final priceController = TextEditingController();
  int selectedSeats = 1;
  // String selectedSeats = "1";
  DateTime? selectedDateTime;

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      /*| Property      | Meaning                                                |
| ------------- | ------------------------------------------------------ |
| `firstDate`   | Sabse **pehli allowed** date                           |
| `lastDate`    | Sabse **aakhri allowed** date                          |
| `initialDate` | Picker open hone par **initially shown/selected** date |
*/
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 15)),
      initialDate: DateTime.now(),
    );

    if (date == null) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) {
      return;
    }

    setState(() {
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _postRide() async {
    ///Validation
    if (pickUpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please Enter PickUp Location")));
      return;
    }
    if (destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please Enter destination Location")),
      );
      return;
    }
    if (priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please Enter Price")));
      return;
    }
    if (selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date and time")),
      );
      return;
    }
    // final price = double.tryParse(priceController.text.trim());
    final price = priceController.text.trim();

    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid price")),
      );
      return;
    }
    try {
      ///Get loggedIn User
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      ///Save to fireStore
      await FirebaseFirestore.instance.collection('rides').add({
        'driverId': user.uid,
        'pickupLocation': pickUpController.text.trim(),
        'destination': destinationController.text.trim(),
        'price': price,
        'availableSeats': selectedSeats,
        'dateTime': Timestamp.fromDate(selectedDateTime!),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // _ridePostedToast();

      ///Show Success
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
          content: Text("Ride posted successfully")));
      ///Current screen ko close kr ka previuos screen per jana or value (1) return krna
      Navigator.pop(context,1);
      print("working publish");
      ///Catch Error
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Something went wrong: $e")));
    }
  }
  // void _ridePostedToast() {
  //   Fluttertoast.showToast(
  //     msg: "Ride posted Successfully",
  //     toastLength: Toast.LENGTH_SHORT,
  //     gravity: ToastGravity.TOP,
  //     timeInSecForIosWeb: 2,
  //     backgroundColor: Colors.red,
  //     textColor: Colors.white,
  //     fontSize: 16.0,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsetsGeometry.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Post a ride",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      "Offer your seats to nearby students",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
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
                        "From",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: pickUpController,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hint: Text(
                                  "From (e.g. City Chowk)",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
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
                        "To",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: destinationController,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hint: Text(
                                  "To (e.g. IUB Campus)",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectDateTime,
                        child: Container(
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
                                "DATE & TIME",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),

                              Text(
                                selectedDateTime == null
                                    ? "Select date & time"
                                    : "${selectedDateTime!.day}/"
                                          "${selectedDateTime!.month}/"
                                          "${selectedDateTime!.year} "
                                          "${selectedDateTime!.hour}:"
                                          "${selectedDateTime!.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final seats = await showDialog<int>(
                          // final seats = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              return SimpleDialog(
                                title: const Text("Select seats"),
                                children: [
                                  SimpleDialogOption(
                                    // onPressed: () => Navigator.pop(context, "1"),
                                    onPressed: () => Navigator.pop(context, 1),
                                    child: const Text("1 seat"),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, 2),
                                    child: const Text("2 seats"),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, 3),
                                    child: const Text("3 seats"),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, 4),
                                    child: const Text("4 seats"),
                                  ),
                                ],
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
                                "SEATS",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$selectedSeats available',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
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
                        "COST PER SEAT",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: priceController,
                        textAlign: TextAlign.start,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hint: Text(
                            "Enter Cost Per Seat",
                            style: TextStyle(fontSize: 18, color: Colors.black),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 50),
                GestureDetector(
                  onTap: _postRide,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Publish ride",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Passengers matching this route will be notified",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
