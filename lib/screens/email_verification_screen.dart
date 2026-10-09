import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'package:iub_ride_sharing_app/screens/complete_profile.dart';
import 'package:iub_ride_sharing_app/screens/Home.dart';
import 'package:iub_ride_sharing_app/screens/signing_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isEmailVerified = false;
  bool _canResendEmail = false;
  bool _isChecking = false;
  int _resendCooldown = 60;
  Timer? _timer;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    _isEmailVerified = user?.emailVerified ?? false;

    if (!_isEmailVerified) {
      _sendVerificationEmail();

      // Periodic Auto-Checker every 4 seconds
      _timer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _checkEmailVerified(isManual: false),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      setState(() {
        _canResendEmail = false;
        _resendCooldown = 60;
      });

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown > 0) {
          if (mounted) setState(() => _resendCooldown--);
        } else {
          timer.cancel();
          if (mounted) setState(() => _canResendEmail = true);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending verification email: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _checkEmailVerified({bool isManual = true}) async {
    if (_isChecking) return;
    if (isManual) setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        _timer?.cancel();
        _cooldownTimer?.cancel();

        if (mounted) {
          setState(() {
            _isEmailVerified = true;
            _isChecking = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Email verified successfully! Welcome to IUB Rides."),
              backgroundColor: Colors.green,
            ),
          );

          await _routeUserAfterVerification(updatedUser.uid);
        }
        return;
      } else if (isManual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email not verified yet. Please click the link sent to your inbox."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking email verification: $e");
    } finally {
      if (mounted && isManual) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _routeUserAfterVerification(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (userDoc.exists && (userDoc.data()?['isProfileComplete'] == true)) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const Home()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CompleteProfile()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CompleteProfile()),
        );
      }
    }
  }

  Future<void> _signOut() async {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignIn()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "your university email";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: _signOut,
          tooltip: "Back / Change Email",
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 16, color: Colors.red),
            label: const Text("Sign Out", style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ICON ANIMATION / BADGE
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.mintIce,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3), width: 3),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppColors.emeraldGreen,
                  size: 48,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Verify University Email",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                "We have sent a verification confirmation link to:",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // INSTRUCTION CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Next Steps:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "1. Open your university inbox / Gmail app.\n"
                      "2. Click the verification link sent by Firebase.\n"
                      "3. Return here and tap 'I Have Verified' or wait for auto-detection.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.brown.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // MANUAL VERIFY BUTTON
              ElevatedButton(
                onPressed: _isChecking ? null : () => _checkEmailVerified(isManual: true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isChecking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "I Have Verified",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),

              const SizedBox(height: 16),

              // RESEND EMAIL BUTTON
              OutlinedButton.icon(
                onPressed: _canResendEmail ? _sendVerificationEmail : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  _canResendEmail
                      ? "Resend Verification Email"
                      : "Resend available in ${_resendCooldown}s",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.emeraldGreen,
                  side: BorderSide(
                    color: _canResendEmail ? AppColors.emeraldGreen : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
