import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/preferences.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _loadingProvider;

  Future<void> _handleSocialSignIn(
    Future<dynamic> Function() signIn,
    String providerName,
  ) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadingProvider = providerName;
    });
    try {
      final result = await signIn();
      if (result == null) {
        //User cancelled
        if (mounted) setState(() => _loading = false);
        return;
      }
      await AppPrefs.setLoggedIn(true);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$providerName sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogo(),
                const SizedBox(height: 20),
                const Text(
                  'Login',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 28),
                _ProviderButton(
                  icon: Icons.g_mobiledata_rounded,
                  iconColor: const Color(0xFFEA4335),
                  label: 'Login With Google',
                  loading: _loadingProvider == 'Google',
                  disabled: _loading,
                  onTap: () => _handleSocialSignIn(
                    AuthService.signInWithGoogle,
                    'Google',
                  ),
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cream,
        border: Border.all(color: AppColors.gold, width: 3),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.lock_open, color: Colors.black, size: 32),
    );
  }
}

//Login With Google
class _ProviderButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;

  const _ProviderButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.mid,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
