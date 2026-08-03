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
        builder: (_) =>
            isLoggedIn ? const HomeScreen() : const WelcomeGateScreen(),
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

//Discover the color that were made for you
class WelcomeGateScreen extends StatelessWidget {
  const WelcomeGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Discover the color that',
                style: TextStyle(
                  color: Color(0xff4c3935),
                  fontFamily: 'Lora',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'were made for you',
                style: TextStyle(
                  color: Color(0xffde939c),
                  fontFamily: 'Lora',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      //Icon
                      child: Center(
                        child: Image.asset(
                          'assets/account-restriction.png',
                          width: 355,
                          height: 355,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff4c3935),

                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
