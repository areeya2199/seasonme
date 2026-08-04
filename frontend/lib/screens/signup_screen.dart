import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    // TODO: hook up to real registration API.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: SoftCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color((0xff4c3935)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _FieldLabel('Username'),
                const SizedBox(height: 6),
                _RoundedField(
                  controller: _usernameController,
                  hint: 'Enter your username',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Email'),
                const SizedBox(height: 6),
                _RoundedField(
                  controller: _emailController,
                  hint: 'Enter your email',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Password'),
                const SizedBox(height: 6),
                _RoundedField(
                  controller: _passwordController,
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.mid,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Confirm your password'),
                const SizedBox(height: 6),
                _RoundedField(
                  controller: _confirmPasswordController,
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.mid,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 20),
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

                    onPressed: _handleSignUp,
                    child: const Text(
                      'Sign Up',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: AppColors.mid.withOpacity(0.2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Or sign up with',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mid,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: AppColors.mid.withOpacity(0.2)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialCircle(Icons.facebook, const Color(0xFF1877F2)),
                    const SizedBox(width: 16),
                    _socialCircle(Icons.apple, AppColors.charcoal),
                    const SizedBox(width: 16),
                    _socialCircle(Icons.g_mobiledata, const Color(0xFFEA4335)),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "have an account? ",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 65, 60, 59),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.gold,
                            fontFamily: 'Nunito',
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
      ),
    );
  }

  Widget _socialCircle(IconData icon, Color color) => Container(
    width: 46,
    height: 46,
    decoration: const BoxDecoration(
      color: AppColors.cream,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.mid),
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.charcoal),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.mid),
        prefixIcon: Icon(icon, size: 18, color: AppColors.mid),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cream,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
