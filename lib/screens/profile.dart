import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
 Widget buildMenuTile(IconData icon,String title){
   return Container(
     padding: EdgeInsets.symmetric(vertical: 16,horizontal: 4),
     decoration: BoxDecoration(border:Border(
       bottom: BorderSide(color: AppColors.coolGray,width: 1),
     )
     ),
     child: Row(
       children: [Icon(icon,color: Colors.black87,size: 22,),
         SizedBox(width: 14,),
         Expanded(child: Text(title,style: TextStyle(fontSize: 16,fontWeight: FontWeight.w500),)),
         Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 18),
         
       ],
     ),
   );
 }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 26,vertical: 100),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      height: 78,
                      width: 78,
                      decoration:BoxDecoration(
                        color: AppColors.coralRed,
                        shape: BoxShape.circle,
                    )
                    ,child:  Text('TH', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),)
                      ,),
                    SizedBox(height: 10,),
                    Text("Tanveer Hussain",style: TextStyle(fontSize:18,fontWeight: FontWeight.bold),),
                    Text("Bs Information Technology.IUB",style: TextStyle(color: Colors.grey,fontSize:18,),),
                    const Text(
                      "★★★★☆ 4.9 rating",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                            children: [
                          Text("38", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Rides given", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ]),
                        Column(children: [
                          Text("12", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Rides taken", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ]),
                        Column(children: [
                          Text("Rs 3.1k", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Saved", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ]),
                      ],
                    ),const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          buildMenuTile(CupertinoIcons.clock, "Ride History"),
                          buildMenuTile(CupertinoIcons.star, "Ratings & reviews"),
                          buildMenuTile(CupertinoIcons.checkmark_shield, "Safety & ride preferences"),
                          buildMenuTile(CupertinoIcons.gear, "Settings"),
                        ],
                      ),
                    ),
                  ]
                  ,),
              )
              ,)
            ,)
    );
  }
}
