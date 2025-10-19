import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:mopro_flutter/mopro_flutter_platform_interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import '../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/create_membershipt.dart';
import '../services/create_message.dart';
import '../services/fetch_googleJWTPubkey.dart';
import '../services/generate_ephemeral_key.dart';
import '../services/google_jwt_prover.dart';
import '../services/jwt_prover.dart';
import '../theme/theme.dart';

class SignInCard extends StatefulWidget {
  final VoidCallback onPostSuccess;
  final bool isInternal;

  const SignInCard(
      {Key? key, required this.onPostSuccess, required this.isInternal})
      : super(key: key);

  @override
  _SignInCardState createState() => _SignInCardState();
}

class _SignInCardState extends State<SignInCard> {
  final AuthService _authService = AuthService();
  final moproFlutterPlugin = MoproFlutter();
  bool _isLoading = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Google Sign-In function using AuthService
  // Update the _signInWithGoogle method in _SignInPageState class to navigate to HomePage
  // Then update the _signInWithGoogle method:
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
        // Navigate to BottomNavBar instead of directly to HomePage
        if (mounted) {
          // Store user information (you may want to save this in a shared preferences or state management)
          final String userEmail = userCredential.user!.email!;
          final String? displayName = userCredential.user!.displayName;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in as: $userEmail'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // User cancelled the sign-in flow
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign-in canceled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // generate jwt proof
      // final idToken = googleAuth.idToken;
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
    } catch (e) {
      // Handle any errors that occur during the sign-in process
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in error: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  String sliceEmail(dynamic email) {
    return email.substring(email.indexOf('@') + 1);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.accentColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: AppColors.accentColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Text(
                  'Create a Post',
                  style: AppTextStyles.h3.copyWith(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.base),
            
            // Markdown editor
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: MarkdownAutoPreview(
                  controller: _textController,
                  emojiConvert: true,
                  decoration: InputDecoration(
                    hintText: "What's happening at your company?",
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.body,
                  maxLines: 5,
                  minLines: 3,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.base),
            
            // Auth section
            StreamBuilder<User?>(
              stream: _authService.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: AppColors.accentColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: AppColors.accentColor,
                              size: 18,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Posting as "Someone from ${sliceEmail(snapshot.data!.email)}"',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.refresh,
                                color: AppColors.textSecondaryColor,
                                size: 20,
                              ),
                              onPressed: () async {
                                await _authService.signOut();
                                await _signInWithGoogle();
                              },
                              tooltip: 'Refresh',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: AppColors.textSecondaryColor,
                                size: 20,
                              ),
                              onPressed: () async {
                                await _authService.signOut();
                              },
                              tooltip: 'Sign out',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () {
                          final text = _textController.text;
                          if (text.isNotEmpty) {
                            createMessage(
                              text,
                              sliceEmail(snapshot.data!.email),
                              widget.isInternal,
                            ).then((_) {
                              _textController.clear();
                              widget.onPostSuccess();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Posted successfully!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          elevation: 2,
                          shadowColor: AppColors.accentColor.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, size: 18),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Post Message',
                              style: AppTextStyles.buttonPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.accentColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign in to post',
                                style: AppTextStyles.bodyMedium,
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                'Use your Google work account to post anonymously',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            onTap: _isLoading ? null : _signInWithGoogle,
                            child: Container(
                              padding: EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accentColor,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/google.png',
                                      width: 36,
                                      height: 36,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
