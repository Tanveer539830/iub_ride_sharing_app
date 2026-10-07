import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/post_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/profile.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'find_a_ride.dart';
import 'my_rides.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int selectedScreen = 0;
  final List<Widget> screen = [FindARide(), MyRides(), Profile()];
  final List<String> titles = ["Find a Ride", "My Rides", "Profile"];
  final Image imagePath = Image.asset("lib/assets/images/tanveer_hussain.jpeg");
  // void _showToast(){
  //   Fluttertoast.showToast(
  //       msg: "My First Toast",
  //       toastLength: Toast.LENGTH_SHORT,
  //       gravity: ToastGravity.TOP,
  //       timeInSecForIosWeb: 2,
  //       backgroundColor: Colors.red,
  //       textColor: Colors.white,
  //       fontSize: 16.0,
  //   );
  // }
  ///My Custom Toast
  // Widget _myCustomToast(){
  //   Widget toast=Container(
  //     width: 300,
  //     height: 100,
  //     padding: EdgeInsets.symmetric(horizontal: 5,vertical:5),
  //     decoration: BoxDecoration(
  //         borderRadius: BorderRadius.circular(12),
  //         color: Colors.greenAccent
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(Icons.check),
  //         Expanded(
  //             child: Text("This is My Custom Toast ")
  //         ),
  //       ],
  //     ),
  //   );
  //   return toast;
  // }
  // void _showCustomToast(){
  //   final overlay=Overlay.of(context);
  //   final overlayEntry=OverlayEntry(builder: (context){
  //     return Positioned(top: 50,left:10,right:10,child: _myCustomToast(),);
  //   }
  //   );
  //   overlay.insert(overlayEntry);
  //   Future.delayed(
  //     Duration(seconds: 10),
  //         () {
  //       overlayEntry.remove();
  //     },
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selectedScreen],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        actions: [
          IconButton(
           onPressed: (){
           },
            icon: Icon(CupertinoIcons.bell),
            iconSize: 25,
            color: Colors.grey.shade900,
            tooltip: "Notifications",
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(CupertinoIcons.ellipsis_vertical),
            iconSize: 25,
            color: Colors.grey.shade900,
            tooltip: "Menu",
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundImage: AssetImage(
                  "lib/assets/images/tanveer_hussain.jpeg",
                ),
              ),
              accountName: Text(
                "Tanveer Hussain",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                "tanveerhussain539830@gmail.com",
                overflow: TextOverflow.ellipsis,
              ),
              decoration: BoxDecoration(color: AppColors.darkNavy,),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "MAIN",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
            ),

            ListTile(
              leading: Icon(Icons.home),
              title: Text("Home"),
              onTap: () {
                setState(() {
                  selectedScreen = 0;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.add),
              title: Text("Post a Ride"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PostARide()),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.my_library_add),
              title: Text("My Rides"),
              onTap: () {
                setState(() {
                  selectedScreen = 1;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
              onTap: () {
                setState(() {
                  selectedScreen = 2;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "ACCOUNT",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
            ),
            ListTile(
              leading: Icon(Icons.history_outlined),
              title: Text("Ride History"),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.star),
              title: Text("Rating and Review"),
            ),
            Divider(),
            ListTile(leading: Icon(Icons.settings), title: Text("Setting")),
            Divider(),
            ListTile(leading: Icon(Icons.info), title: Text("About")),
            Divider(),
            ListTile(
              leading: Icon(Icons.subdirectory_arrow_right_outlined),
              title: Text("Logout"),
            ),
          ],
        ),
      ),
      body: screen[selectedScreen],
      bottomNavigationBar: BottomNavigationBar(
        useLegacyColorScheme: true,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: selectedScreen,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            selectedScreen = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: "Home",
            tooltip: "Go to Home Screen",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            label: "My Rides",
            tooltip: "Your all Previous rides ",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: "Person",
            tooltip: "Profile",
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        hoverColor: Colors.green,
        onPressed: () async{
          final result=await Navigator.push(context, MaterialPageRoute(builder: (_)=>const PostARide()));
          ///post a ride sa result aya 1 is lia My Rides screen open hogi
          if(result==1){
            setState(() {
              selectedScreen=1;
            });
          }
        },
        shape: const CircleBorder(),
        backgroundColor: Colors.red.shade500,
        elevation: 6,
        child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
