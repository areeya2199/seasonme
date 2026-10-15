import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Wardrobe preview: the mannequin picture (assets/preview_mannequin_*.png).
//
// The picture is split into 3 layers so the clothes can be recolored while
// every line, fold and shadow of the original drawing is kept:
//   preview_mannequin_shirt.png  -> shirt  (shading map, tinted with shirtColor)
//   preview_mannequin_skirt.png  -> skirt  (shading map, tinted with pantsColor)
//   preview_mannequin_base.png   -> mannequin, outlines and stand (on top)
// A null color keeps the clothes white, exactly like the original picture.

// Preview card for the Wardrobe mannequin
class MannequinCard extends StatelessWidget {
  final Color? shirtColor;
  final Color? pantsColor;

  const MannequinCard({super.key, this.shirtColor, this.pantsColor});

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
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _tinted(
                  'assets/preview_mannequin_shirt.png',
                  shirtColor ?? Colors.white,
                ),
                _tinted(
                  'assets/preview_mannequin_skirt.png',
                  pantsColor ?? Colors.white,
                ),
                _layer('assets/preview_mannequin_base.png'),
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

// Colors a grey "shading map" image: every pixel becomes
//   color * (0.62 + 0.38 * shade)
// so the brightest parts show exactly [color] and the folds get darker.
Widget _tinted(String path, Color color) {
  final r = ((color.value >> 16) & 0xFF) / 255.0;
  final g = ((color.value >> 8) & 0xFF) / 255.0;
  final b = (color.value & 0xFF) / 255.0;
  const base = 0.62;
  const gain = 0.38;
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(<double>[
      r * gain, 0, 0, 0, r * base * 255, //
      g * gain, 0, 0, 0, g * base * 255, //
      b * gain, 0, 0, 0, b * base * 255, //
      0, 0, 0, 1, 0, //
    ]),
    child: _layer(path),
  );
}
