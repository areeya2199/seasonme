import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../services/preferences.dart';
import 'home_screen.dart';

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
            isLoggedIn ? const HomeScreen() : const HowWeWorkScreen(),
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

//How We Work
class HowWeWorkScreen extends StatelessWidget {
  const HowWeWorkScreen({super.key});

  static const List<Map<String, dynamic>> _steps = [
    {
      'icon': Icons.camera_alt_outlined,
      'title': 'Selfie or Upload your photo',
      'subtitle': 'No makeup , Natural light',
    },
    {
      'icon': Icons.help_outline,
      'title': 'Answer the question',
      'subtitle': 'veins color , Jewelry',
    },
    {
      'icon': Icons.search,
      'title': 'Color analysis',
      'subtitle': 'take a minute',
    },
    {
      'icon': Icons.palette_outlined,
      'title': 'Get your result',
      'subtitle': 'Personal palette',
    },
  ];

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            const Text(
              'How We Work',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color.fromARGB(255, 84, 34, 20),
              ),
            ),

            const SizedBox(height: 30),
            Expanded(
              child: ListView.separated(
                itemCount: _steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  final step = _steps[i];
                  return Row(
                    children: [
                      const SizedBox(width: 14),
                      Expanded(
                        child: SoftCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.blush.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  step['icon'] as IconData,
                                  size: 30,
                                  color: Color.fromARGB(255, 63, 62, 62),
                                ),
                              ),

                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color.fromARGB(255, 84, 34, 20),
                                      ),
                                    ),
                                    Text(
                                      step['subtitle'] as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color.fromARGB(
                                          255,
                                          213,
                                          155,
                                          155,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 245, 177, 194),
                  foregroundColor: Color.fromARGB(255, 255, 199, 201),
                  shadowColor: Color.fromARGB(255, 192, 132, 167),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WelcomeGateScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Got It',
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
            const Text(
              'camera access needed',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: Color.fromARGB(255, 65, 60, 59),
              ),
            ),
          ],
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Discover the color that',
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 34, 20),
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
                          width: 450,
                          height: 450,
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
                    backgroundColor: Color.fromARGB(255, 233, 172, 187),
                    foregroundColor: Color.fromARGB(255, 255, 194, 196),
                    shadowColor: Color.fromARGB(255, 205, 150, 182),
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
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: Color.fromARGB(255, 65, 60, 59),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
