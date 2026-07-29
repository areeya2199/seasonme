import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'password_changed_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _reEnterPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureReEnter = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _reEnterPasswordController.dispose();
    super.dispose();
  }

  void _setNewPassword() {
    // TODO: submit new password to backend, then continue.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PasswordChangedScreen()),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.charcoal.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 36,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please set your new password.',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.mid,
                  ),
                ),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'New password',
                    style: TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  style: const TextStyle(color: AppColors.charcoal),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mid,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.mid,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mid,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Re-enter password',
                    style: TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _reEnterPasswordController,
                  obscureText: _obscureReEnter,
                  style: const TextStyle(color: AppColors.charcoal),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mid,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.mid,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureReEnter
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mid,
                      ),
                      onPressed: () =>
                          setState(() => _obscureReEnter = !_obscureReEnter),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _setNewPassword,
                    child: const Text(
                      'Set new password',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: Color.fromARGB(255, 255, 255, 255),
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
