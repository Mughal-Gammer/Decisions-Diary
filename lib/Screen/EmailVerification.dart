import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'login page.dart';

class EmailVerificationScreen extends StatefulWidget {
  final Map<String, String> pendingUserData;

  const EmailVerificationScreen({
    Key? key,
    required this.userCredential,
    required this.pendingUserData,
  }) : super(key: key);

  final UserCredential userCredential;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool isEmailVerified = false;
  bool isResendLoading = false;
  Timer? _verificationTimer;
  Timer? _countdownTimer;
  int _countdown = 60;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });

    _startVerificationCheck();
    _startCountdown();
  }

  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _checkEmailVerified(),
    );
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified && mounted) {
      setState(() => isEmailVerified = true);
      _verificationTimer?.cancel();

      // Save user data now
      final userId = user.uid;
      await FirebaseDatabase.instance.ref("users/$userId").set({
        ...widget.pendingUserData,
        'UserId': userId,
      });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }


  }

  Future<void> _resendVerificationEmail() async {
    setState(() => isResendLoading = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification email resent!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => _countdown = 60);
      _startCountdown();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isResendLoading = false);
    }
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Verify Your Email',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEmailVerified
                          ? 'Your email has been successfully verified!'
                          : 'A verification link has been sent to your email. Please check your inbox and click the link to verify your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (!isEmailVerified) ...[
                      ElevatedButton.icon(
                        onPressed: (_countdown > 0 || isResendLoading)
                            ? null
                            : _resendVerificationEmail,
                        icon: isResendLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        )
                            : const Icon(Icons.email_outlined,color: Colors.blueAccent,),
                        label: Text(
                          _countdown > 0
                              ? 'Resend in $_countdown seconds'
                              : 'Resend Verification Email',
                          style: TextStyle(
                            color: Colors.blueAccent
                          ),
                        ),
                        style:

                        ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
