import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../constants/app_colors.dart';
class LiveTracking extends StatefulWidget {
  const LiveTracking({super.key});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: SafeArea(
            child: Padding(
                padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 400,
                      width: double.infinity,
                      decoration:
                      BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.mintIce,
                      ),
                      child: Stack(
                        children: [
                         Positioned(
                           top: 40,
                          left: 24,
                          right: 24,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16,vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.darkNavy,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child:Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text("Arriving in 4 min",style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: Colors.white),),
                                        SizedBox(height: 2,),
                                        Text("Ahmad is on the way",style: TextStyle(fontSize: 12,color: AppColors.lightGray),)
                                      ],
                                    ),),
                                  Icon(
                                    CupertinoIcons.car_detailed,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                ],
                              ),
                          ),
                         ),
                          Positioned(
                            top: 190,
                            left: 24,
                            right: 24,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on,color: Colors.green,),
                      Text("  - - - - - - - - - - - - - - "),
                      Icon(Icons.location_on,color: Colors.red,),
                    ],
                  ),
                          ),
                        ],
                      ),
              ),SizedBox(height: 30,),
                  Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Container(width: 16,height: 16,decoration: BoxDecoration(color:AppColors.mintGreen,shape: BoxShape.circle,),),
                          Expanded(child: Container(
                            height: 2,
                            width: 50,
                            color: Colors.grey,
                          ),),

                      Container(width: 16,height: 16,decoration: BoxDecoration(color:AppColors.mintGreen,shape: BoxShape.circle),),
                          Expanded(child: Container(
                            height: 2,
                            width: 50,
                            color: Colors.grey,
                          ),),
                          Container(width: 16,height: 16,decoration: BoxDecoration(color:Colors.orange,shape: BoxShape.circle),),
                          Expanded(child: Container(
                            height: 2,
                            width: 50,
                            color: Colors.grey,
                          ),),
                      Container(width: 16,height: 16,decoration: BoxDecoration(color:AppColors.coolGray,shape: BoxShape.circle),)
                    ],
                    ),SizedBox(height: 8,),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Requested",
                            textAlign: TextAlign.start,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "Confirmed",
                            textAlign: TextAlign.start,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "On the way",
                            textAlign: TextAlign.end,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "Arrived",
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    )
                  ],
                  ),SizedBox(height: 20,)
                  ,Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: (){},
                      style:OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(46),
                        side: BorderSide(color: AppColors.lightGray,),
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),backgroundColor: Colors.white) , child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      Icon(Icons.call),
                      SizedBox(width: 8),
                      Text("Call driver",style: TextStyle(color: Colors.black),),
              ],
            ),)),SizedBox(width: 12,),Expanded(child: OutlinedButton(onPressed: (){},
                        style:OutlinedButton.styleFrom(
                            minimumSize: Size.fromHeight(46),
                            side: BorderSide(color: AppColors.lightGray,),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),backgroundColor: Colors.white) , child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.ios_share_outlined),
                            SizedBox(width: 8),
                            Text("Share trip",style: TextStyle(color: Colors.black),),
                          ],
                        ),))
                ],
            ),SizedBox(height: 10,),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text("Your location is only shared for the duration of this ride", textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  )],)

                ]
              ),
            ),
      ),
    );
  }
}
