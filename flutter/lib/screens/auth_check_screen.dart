import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'google_signin_screen.dart';
import '../theme/app_colors.dart';

class AuthCheckScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  AuthCheckScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.accentColor,
              ),
            ),
          );
        }

        // If user is signed in, go to home page
        if (snapshot.hasData && snapshot.data != null) {
          return StealthHomePage();
        }

        // If user is not signed in, show Google Sign-In screen
        return const GoogleSignInScreen();
      },
    );
  }
}
