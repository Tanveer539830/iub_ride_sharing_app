import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iub_ride_sharing_app/screens/complete_profile.dart';
import 'package:iub_ride_sharing_app/screens/find_a_ride.dart';
import 'package:iub_ride_sharing_app/screens/forget_password_screens/forget_password.dart';
import '../constants/app_colors.dart';
import 'create_account.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;
  bool isGoogleInitialized = false;
  bool _isPasswordHidden = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Only initialize once — avoids re-initializing on every tap.
      if (!isGoogleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId:
          '89817940709-73rr62uu9r16qdd77hih8bsjd3p6ooek.apps.googleusercontent.com',
        );
        if (mounted) {
          setState(() {
            isGoogleInitialized = true;
          });
        }
      }
      ///google user---> represent google account authenticate through google singIn
      ///Conceptually is main account level information/access ati hain
      final GoogleSignInAccount googleUser =
      await GoogleSignIn.instance.authenticate();
      ///googleAuth ---> is main authentication result or credential related information ati hain.
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw Exception("Firebase user is null");
      }

      final uid = user.uid;

      // If this Google account hasn't signed in before, create their profile doc.
      final userDoc =
      await FirebaseFirestore.instance.collection("users").doc(uid).get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection("users").doc(uid).set({
          'uid': uid,
          'fullName': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': '',
          'photoURL': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in successfully!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => CompleteProfile()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
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

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all the fields")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in successfully!')),
        );
        Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) =>CompleteProfile(),));
      }
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Authentication failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome back",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Sign in to continue booking and sharing rides",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Continue with Google
                GestureDetector(
                  onTap: isLoading ? null : _signInWithGoogle,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "lib/assets/images/google_logo.svg",
                          height: 24,
                          width: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Continue with Google",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: Divider(color: AppColors.lightGray)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "Or sign in with password",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.lightGray)),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  "EMAIL",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.grey, width: 1.5)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.grey, width: 1.5)),
                    hintText: "abc@gmail.com",
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  "PASSWORD",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _isPasswordHidden,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordHidden
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordHidden = !_isPasswordHidden;
                        });
                      },
                    ),
                    prefixIcon: const Icon(Icons.key),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.grey, width: 1.5)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.grey, width: 1.5)),
                    hintText: "••••••••",
                  ),
                ),SizedBox(height: 10,),
                GestureDetector(
                  onTap: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgetPassword(),
                      ),
                    );
                  } ,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 15, color: Colors.grey), // ye style
                          children: [
                            TextSpan(
                              text: "Forgot password?",
                              style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold), // ye override kar deta hai
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: isLoading ? null : _signIn,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.mediumTeal),
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Sign in",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateAccount()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        style:
                        const TextStyle(fontSize: 13, color: Colors.grey),
                        children: [
                          const TextSpan(text: "New here? "),
                          TextSpan(
                            text: "Create an account",
                            style: TextStyle(
                              color: AppColors.emeraldGreen,
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
          ),
        ),
      ),
    );
  }
}