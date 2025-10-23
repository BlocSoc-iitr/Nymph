import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/create_membershipt.dart';
import '../services/fetch_googleJWTPubkey.dart';
import '../services/generate_ephemeral_key.dart';
import '../services/google_jwt_prover.dart';
import '../services/jwt_prover.dart';
import '../theme/app_colors.dart';

class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({Key? key}) : super(key: key);

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String sliceEmail(dynamic email) {
    return email.substring(email.indexOf('@') + 1);
  }

  // EXACT SAME LOGIC FROM signin_card.dart
  Future<void> _signInWithGoogle() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final ephemeralKey = await getEphemeralKey();

      // Decode the JSON string
      Map<String, dynamic> ephemeralKeyObj = jsonDecode(ephemeralKey);
      final ephemeralPubkey = ephemeralKeyObj['public_key'];
      final ephemeralExpiry = ephemeralKeyObj['expiry'];
      final ephemeralPubkeyHash = ephemeralKeyObj['pubkey_hash'];

      final String? idToken = await _authService.signInManually(
        ephemeralPubkeyHash,
      );
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final UserCredential? userCredential =
          await _authService.signInWithGoogle(credential);

      if (userCredential != null && userCredential.user != null) {
        // User signed in successfully
        if (mounted) {
          final String userEmail = userCredential.user!.email!;
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in as: $userEmail'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        // User cancelled the sign-in flow
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sign-in canceled'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }

      // generate jwt proof
      final header = parseJwtHeader(idToken);
      final payload = parseJwtPayload(idToken);
      final googlePublicKey = await fetchGooglePublicKey(header['kid']);

      final proof = await generateJwtProof(
        jsonEncode(googlePublicKey),
        idToken,
        sliceEmail(payload['email']),
      );

      // create membership
      final proofArgs = {"keyId": header['kid'], "jwtCircuitVersion": "0.3.1"};
      await createMembership(
        ephemeralPubkey,
        ephemeralExpiry,
        sliceEmail(payload['email']),
        "google-oauth",
        proof!,
        proofArgs,
      );

      // Navigation will happen automatically via StreamBuilder in AuthCheckScreen
    } catch (e) {
      // Handle any errors that occur during the sign-in process
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      print('Error signing in with Google: $e');
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Container(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    
                    // App Logo
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // App Name
                    Text(
                      'Nymph',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Tagline
                    Text(
                      'Anonymous Messaging Platform',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      'Share your thoughts securely and anonymously\nwith your organization',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    
                    const Spacer(flex: 3),
                    
                    // Sign In Button
                    Container(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.accentColor,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/google.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sign in with Google',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Privacy note
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Your identity remains anonymous. Only your organization domain is visible.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 2),
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
