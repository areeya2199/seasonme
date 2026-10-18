import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Beauty & Jewelry preview: the face picture (assets/preview_face_*.png).
//
// The picture is split into layers so each item can be recolored without
// touching the rest of the drawing:
//   preview_face_base.png       -> the full original picture
//   preview_face_hair.png       -> hair      (shading map, tinted with hair)
//   preview_face_eyeshadow.png  -> eyelids   (soft airbrushed mask)
//   preview_face_blush.png      -> cheeks    (soft airbrushed mask)
//   preview_face_lips.png       -> lips      (shading map, tinted with lips)
//   preview_face_earrings.png   -> earrings  (shading map, tinted with earrings)
// A color that is null leaves that part exactly as in the original picture.

// Preview card for the Beauty & Jewelry face
class BeautyPreviewCard extends StatelessWidget {
  final Color? hair;
  final Color? eyeshadow;
  final Color? blush;
  final Color? lips;
  final Color? earrings;

  const BeautyPreviewCard({
    super.key,
    this.hair,
    this.eyeshadow,
    this.blush,
    this.lips,
    this.earrings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 100,
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _layer('assets/preview_face_base.png'),
                _flat('assets/preview_face_blush.png', blush),
                _flat('assets/preview_face_eyeshadow.png', eyeshadow),
                _shaded('assets/preview_face_lips.png', lips, 0.55, 0.9),
                _shaded('assets/preview_face_hair.png', hair, 0.5, 0.9),
                _shaded('assets/preview_face_earrings.png', earrings, 0.5, 0.6),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.mid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _layer(String path) {
  return Image.asset(
    path,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
  );
}

// Hidden while [color] is null, but kept loaded so it shows instantly.
Widget _hideable(Color? color, Widget child) {
  return Visibility(visible: color != null, maintainState: true, child: child);
}

// Soft mask painted in one flat color (blush, eyeshadow)
Widget _flat(String path, Color? color) {
  return _hideable(
    color,
    ColorFiltered(
      colorFilter: ColorFilter.mode(
        color ?? Colors.transparent,
        BlendMode.srcIn,
      ),
      child: _layer(path),
    ),
  );
}

// Grey "shading map" image recolored with
//   color * (base + gain * shade)
// so strands, gloss and outlines of the original drawing are kept.
Widget _shaded(String path, Color? color, double base, double gain) {
  final c = color ?? Colors.white;
  final r = ((c.value >> 16) & 0xFF) / 255.0;
  final g = ((c.value >> 8) & 0xFF) / 255.0;
  final b = (c.value & 0xFF) / 255.0;
  return _hideable(
    color,
    ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        r * gain, 0, 0, 0, r * base * 255, //
        g * gain, 0, 0, 0, g * base * 255, //
        b * gain, 0, 0, 0, b * base * 255, //
        0, 0, 0, 1, 0, //
      ]),
      child: _layer(path),
    ),
  );
}
