import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserRoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  /// Stream of current user's profile document
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? getUserStream() {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Get live data map of current user
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Get vehicle info of current user (or specified uid)
  static Future<Map<String, dynamic>?> getVehicleInfo([String? userId]) async {
    final uid = userId ?? currentUid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('vehicles').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint("Error fetching vehicle: $e");
      return null;
    }
  }

  /// Get driver document of current user (or specified uid)
  static Future<Map<String, dynamic>?> getDriverDetails([String? userId]) async {
    final uid = userId ?? currentUid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('drivers').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint("Error fetching driver details: $e");
      return null;
    }
  }

  /// Get driver verification status
  /// Returns: 'not_registered' | 'pending' | 'approved' | 'rejected'
  static Future<String> getDriverStatus() async {
    final data = await getUserProfile();
    return (data?['driverStatus'] ?? 'not_registered').toString();
  }

  /// Get current active app mode
  /// Returns: 'passenger' | 'driver'
  static Future<String> getActiveMode() async {
    final data = await getUserProfile();
    return (data?['activeMode'] ?? 'passenger').toString();
  }

  /// Switch active mode between 'passenger' and 'driver'
  static Future<bool> switchActiveMode(String newMode) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      if (newMode == 'driver') {
        final status = await getDriverStatus();
        if (status != 'approved') {
          return false; // Cannot switch to driver mode if not approved
        }
      }

      await _firestore.collection('users').doc(uid).set({
        'activeMode': newMode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint("Error switching mode: $e");
      return false;
    }
  }

  /// Set initial mode during role selection onboarding
  static Future<void> setInitialRole(String mode) async {
    final uid = currentUid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      'activeMode': mode,
      'driverStatus': mode == 'driver' ? 'not_registered' : (await getDriverStatus()),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Check if the user is an authorized Admin
  static bool isUserAdmin([String? email, Map<String, dynamic>? userData]) {
    final userEmail = email ?? _auth.currentUser?.email;
    if (userEmail == null) return false;
    final lower = userEmail.toLowerCase().trim();

    // 1. Authorized primary admin email specified by project owner:
    if (lower == 'f22binft1e02085@iub.edu.pk') return true;
    if (lower == 'tanveerhussain539830@gmail.com') return true;
    if (lower.startsWith('admin')) return true;

    // 2. Firestore role / isAdmin flag
    if (userData?['isAdmin'] == true || userData?['role'] == 'admin') return true;

    return false;
  }
}
