//Splash
import 'package:flutter/material.dart';
import 'package:frontend/screens/login.dart';
import '../theme/app_theme.dart';
import '../services/preferences.dart';
import 'home_screen.dart';
import 'login.dart';

//splash screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeNext();
  }

  Future<void> _routeNext() async {
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1700)),
      AppPrefs.isLoggedIn(),
    ]);
    if (!mounted) return;

    final isLoggedIn = results[1] as bool;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //ไม่เอาพื้หลังจาก app_theme
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xfffce7f3),
              Color(0xffffeaeb),
              Color(0xffffeddf),
              Color(0xfff9ecf2),
              Color(0xfff3eaff),
            ],
          ),
        ),

        //แสดงโลโก้ SeasonMe
        child: Center(
          child: Image.asset(
            'assets/seasonme_logo.png',
            width: 150,
            height: 150,
          ),
        ),
      ),
    );
  }
}
