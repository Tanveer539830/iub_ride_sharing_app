import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyRides extends StatefulWidget {
  const MyRides({super.key});

  @override
  State<MyRides> createState() => _MyRidesState();
}

  List<Map<String, dynamic>> pendingRequests = [];
class _MyRidesState extends State<MyRides> {
  
/*Current logged-in driver ki saari pending ride requests Firebase se lao aur pendingRequests list mein store karo.*/
  Future<void> _getPendingRequests() async {///<---Clear underStanding Nhi hai
    ///Getting Current Logged In User Uid
    final currentUser = FirebaseAuth.instance.currentUser?.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('ride_requests')
    ///Sirf woh documents lao jinka driverId current logged-in driver ke UID ke equal hai.
        .where('driverId', isEqualTo: currentUser)
    ///Sirf pending requests chahiye
        .where('status', isEqualTo: 'pending')
    ///Ab Firestore ko actual query execute karo aur result lao.
        .get();
    ///Snapshot mein jitne documents aaye hain, ek ek karke process karo.
    ///request ek waqt mein ek Firestore document ko represent karta hai.
    for (final request in snapshot.docs) {
      final passengerId = request['passengerId'];

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(passengerId)
          .get();
      if (userSnapshot.exists) {
        ///Ab Firestore document ka actual data map ki form mein milta hai.
        final userData = userSnapshot.data();
        final passengerName = userData?['fullName'];

        pendingRequests.add({
          ///request.data() ke andar jo saare key-value pairs hain, unko is naye Map ke andar spread/copy kar do.
          ...request.data(),
          'passengerName': passengerName,
          'requestId': request.id,
        });

        setState(() {});
      }
    }
  }

  String getInitials(String name){
    final words=name.trim().split(" ");
    if(words.length>=2){
      return "${words[0][0]}${words[1][0]}".toUpperCase();
    }
    return words[0][0].toUpperCase();
  }
  Future<void> _acceptRequest(String requestId) async {///<---Clear underStanding Nhi hai
    final requestRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(requestId);
    print("request ID${requestId}");
    final requestSnapshot = await requestRef.get();

    final requestData = requestSnapshot.data();
    final rideId = requestData?['rideId'];
    print('RIDE ID: $rideId');
    final rideRef = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId);
    final rideSnapshot = await rideRef.get();

    final rideData = rideSnapshot.data();
    final availableSeats = (rideData?['availableSeats']);
    ///Main na yahan avaiable seats ko int main is lia rakha hai taka request accept hona per aik seat kam ho
    // final availableSeats = int.parse(rideData?['availableSeats'].toString()??"0");///<----issue yahan lag rha hai
    print('Available seats:${availableSeats}');
    if (availableSeats <= 0) {
      return;
    }
    final newAvailableSeats = availableSeats - 1;
    print('UPDATING SEATS TO: $newAvailableSeats');
    await rideRef.update({
      'availableSeats': newAvailableSeats,
    });
    print("seats updated Sucessfully");
      await requestRef.update({
        'status': 'accepted',
      });
      print('REQUEST ACCEPTED SUCCESSFULLY');
    setState(() {
      pendingRequests.removeWhere(
            (request) => request['requestId'] == requestId,
      );
    });
  }
  Future<void> _declineRequest(String requestId) async {
    final requestRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(requestId);

    await requestRef.update({
      'status': 'declined',
    });

    setState(() {
      pendingRequests.removeWhere(
            (request) => request['requestId'] == requestId,
      );
    });
  }
  @override
  void initState() {
    super.initState();
    _getPendingRequests();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Manage rides you offer and join",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.darkNavy,
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Padding(
                          padding: EdgeInsetsGeometry.symmetric(vertical: 10),
                          child: Text(
                            "As driver",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsGeometry.symmetric(vertical: 10),
                        child: Text(
                          "As passenger",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.coolGray,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        const SizedBox(width: 8),
                        const Text(
                          "City Chowk",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Campus",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "08:00 AM  ·  To day",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "2 requests",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REQUESTS",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: pendingRequests.length,

                      itemBuilder: (context, index) {
                        final request = pendingRequests[index];

                        final passengerName =
                            request['passengerName'] ?? 'Unknown passenger';

                          return Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  getInitials(request['passengerName'] ?? 'Unknown passenger'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                         passengerName,
                                    ),
                                    Text(
                                      "Wants ${request['seats']} seat${request['seats'] == 1 ? '' : 's'}",
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _acceptRequest(request['requestId']);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mintWhisper,
                                  foregroundColor: AppColors.emeraldGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadiusGeometry.circular(10),
                                  ),
                                ),
                                child: Text(
                                  "Accept",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                              SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {

                                  _declineRequest(request['requestId']);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warmCoralTint,
                                  foregroundColor: AppColors.coralRed,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadiusGeometry.circular(10),
                                  ),
                                ),
                                child: Text(
                                  "Decline",
                                  style: TextStyle(color: Colors.red.shade500),
                                ),
                              ),
                            ],

                        );
                      },
                      separatorBuilder: (context, index) => Divider(
                        thickness: 1,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    // ...pendingRequests.map((request) {
                    //   final passengerName = request['passengerName'] ?? 'Unknown passenger';
                    //   List<String> words=passengerName.split('');
                    //   String initials=words[0][0]+words[1][0];
                    //   print(initials);
                    //   return Row(
                    //     children: [
                    //       Container(
                    //         width: 38,
                    //         height: 38,
                    //         decoration: BoxDecoration(
                    //           shape: BoxShape.circle,
                    //           color: Colors.green,
                    //         ),
                    //         alignment: Alignment.center,
                    //         child: Text(
                    //           getInitials(request['passengerName'] ?? 'Unknown passenger'),
                    //           style: TextStyle(
                    //             color: Colors.white,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),
                    //       ),
                    //       SizedBox(width: 10),
                    //       Expanded(
                    //         child: Column(
                    //           mainAxisAlignment: MainAxisAlignment.start,
                    //           crossAxisAlignment: CrossAxisAlignment.start,
                    //           children: [
                    //             Text(
                    //                  passengerName,
                    //             ),
                    //             Text(
                    //               "Wants ${request['seats']} seat${request['seats'] == 1 ? '' : 's'}",
                    //             ),
                    //           ],
                    //         ),
                    //       ),
                    //       ElevatedButton(
                    //         onPressed: () {
                    //           _acceptRequest(request['requestId']);
                    //         },
                    //         style: ElevatedButton.styleFrom(
                    //           backgroundColor: AppColors.mintWhisper,
                    //           foregroundColor: AppColors.emeraldGreen,
                    //           elevation: 0,
                    //           shape: RoundedRectangleBorder(
                    //             borderRadius: BorderRadiusGeometry.circular(10),
                    //           ),
                    //         ),
                    //         child: Text(
                    //           "Accept",
                    //           style: TextStyle(color: Colors.green),
                    //         ),
                    //       ),
                    //       SizedBox(width: 10),
                    //       ElevatedButton(
                    //         onPressed: () {
                    //
                    //           _declineRequest(request['requestId']);
                    //         },
                    //         style: ElevatedButton.styleFrom(
                    //           backgroundColor: AppColors.warmCoralTint,
                    //           foregroundColor: AppColors.coralRed,
                    //           elevation: 0,
                    //           shape: RoundedRectangleBorder(
                    //             borderRadius: BorderRadiusGeometry.circular(10),
                    //           ),
                    //         ),
                    //         child: Text(
                    //           "Decline",
                    //           style: TextStyle(color: Colors.red.shade500),
                    //         ),
                    //       ),
                    //     ],
                    //   );
                    //
                    // }),
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
