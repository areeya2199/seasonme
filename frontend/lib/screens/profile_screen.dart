import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  //replace with real user data from local storage / API.
  //ยังไม่เสร็จสมบูรณ์
  static const String _name = 'Gim';
  static const String _email = 'gim_uraiwan@gmail.com';

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GradientBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff4c3935),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xffecd5f1), Color(0xffde939c)],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 45, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text(
              _name,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              _email,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.mid,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),

              child: Row(mainAxisSize: MainAxisSize.min),
            ),
            const SizedBox(height: 20),
            Row(),
            const SizedBox(height: 20),
            _ProfileTile(
              icon: Icons.edit_outlined,
              label: 'Edit Profile',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.notifications_none,
              label: 'Notifications',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.settings_outlined,
              label: 'Preferences',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blush,
                  side: BorderSide(color: Color(0xffff4848)),

                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(
                  Icons.logout,
                  size: 16,
                  color: Color(0xffff4848),
                ),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Color(0xffff4848),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.blush,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.mid),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blush.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.charcoal),
            ),
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
            const Icon(Icons.chevron_right, color: AppColors.mid, size: 20),
          ],
        ),
      ),
    );
  }
}
