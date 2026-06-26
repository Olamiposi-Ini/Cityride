import 'dart:async';
import 'dart:convert';
import 'package:cityride/screens/driver_home.dart';
import 'package:cityride/screens/rider_home.dart';
import 'package:cityride/screens/onboarding.dart';
import 'package:cityride/services/authservice.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animationController.forward();

    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final checkTokenFuture = _authService.getToken();

    await Future.delayed(const Duration(seconds: 2));

    final String? token = await checkTokenFuture;

    if (!mounted) return;

    Widget nextScreen = const OnboardingScreen();
    if (token != null) {
      nextScreen = const RiderHomeScreen();
      try {
        final response = await _authService.getCurrentProfile();
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final String role = data['user']['role'] ?? "RIDER";
          nextScreen = role == "DRIVER"
              ? const DriverHomeScreen()
              : const RiderHomeScreen();
        }
      } catch (e) {
        debugPrint("Splash profile fetch error: $e");
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset('assets/Splash.png', fit: BoxFit.cover),
      ),
    );
  }
}
