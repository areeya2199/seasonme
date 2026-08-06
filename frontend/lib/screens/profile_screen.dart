import 'package:flutter/material.dart';
import 'package:frontend/screens/login.dart';
import '../theme/app_theme.dart';
import '../services/preferences.dart';
import '../services/auth_service.dart';
import '../services/analysis_history.dart';
import '../data/season_palette.dart';
import 'home_screen.dart';
import 'login.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final displayName = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : 'Gim';
    final email = user?.email ?? 'Not signed in';
    final photoUrl = user?.photoURL;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

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
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
            // User Info
            const SizedBox(height: 20),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 233, 172, 187),

                    Color.fromARGB(255, 255, 194, 196),
                    Color.fromARGB(255, 205, 150, 182),
                  ],
                ),
              ),
              // User Avatar Y
              alignment: Alignment.center,
              child: photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        photoUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              displayName,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(fontSize: 12, color: AppColors.mid),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<AnalysisHistoryEntry>>(
              future: AnalysisHistoryService.getAll(),
              builder: (context, snapshot) {
                final history = snapshot.data;
                if (history == null || history.isEmpty)
                  return const SizedBox.shrink();
                final latestLabel = SeasonPaletteData.labelOf(
                  history.first.season,
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
            _ProfileTile(
              icon: Icons.favorite_border,
              label: 'Saved Palettes',
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
            // Log Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blush,
                  side: BorderSide(
                    color: const Color.fromARGB(
                      255,
                      143,
                      63,
                      63,
                    ).withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 16),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: Color.fromARGB(255, 176, 90, 90),
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
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.charcoal),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.charcoal,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
