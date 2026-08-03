import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'camera_screen.dart';
import 'upload_screen.dart';
import 'questionnaire_screen.dart';
import 'photoguide.dart';

//select screen
class SelectScreen extends StatelessWidget {
  const SelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            GradientBackButton(onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 4),
            const Text(
              'New Analysis',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.gold,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How would you like\nto add your photo?',
              style: TextStyle(
                fontSize: 26,
                fontFamily: 'Ninito',
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "We'll analyze your skin, hair and eye tones to find your season.",
              style: TextStyle(fontSize: 13, color: AppColors.mid, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Take a Photo
            _OptionCard(
              icon: Icons.camera_alt_outlined,
              iconColor: AppColors.gold,
              title: 'Take a Photo',
              subtitle: 'Use the guided camera',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              ),
            ),
            const SizedBox(height: 14),

            // Upload a Photo
            _OptionCard(
              icon: Icons.photo_library_outlined,
              iconColor: AppColors.sage,
              title: 'Upload a Photo',
              subtitle: 'Choose from gallery',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadPhotoScreen()),
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                const Text(
                  'For best results',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => showFacePhotoGuide(context),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'i',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.mid),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mid),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.sage, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
          ),
        ],
      ),
    );
  }
}
