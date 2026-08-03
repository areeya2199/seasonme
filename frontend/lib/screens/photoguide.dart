import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

//Face Photo Guide
Future<void> showFacePhotoGuide(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => const FacePhotoGuideDialog(),
  );
}

class FacePhotoGuideDialog extends StatelessWidget {
  const FacePhotoGuideDialog({super.key});

  static const List<Map<String, String>> _tips = [
    {
      'icon': 'sun',
      'title': 'Natural Daylight',
      'subtitle': 'Avoid direct sunlight',
    },
    {'icon': 'face', 'title': 'Bare Skin', 'subtitle': 'Remove all makeup'},
    {
      'icon': 'scan',
      'title': 'Face the camera',
      'subtitle': 'Look directly at the camera',
    },
    {'icon': 'person', 'title': 'Hair Away', 'subtitle': 'Show your full face'},
  ];

  static IconData _iconFor(String key) {
    switch (key) {
      case 'sun':
        return Icons.wb_sunny_outlined;
      case 'face':
        return Icons.face_retouching_natural;
      case 'scan':
        return Icons.center_focus_strong_outlined;
      case 'person':
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 620),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppColors.charcoal,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Face Photo Guide',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: Image.asset('assets/person.png', fit: BoxFit.cover),
                  ),
                ),

                const SizedBox(height: 18),
                ..._tips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 252, 230, 233),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconFor(tip['icon']!),
                            size: 18,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title']!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              Text(
                                tip['subtitle']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Got It',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
