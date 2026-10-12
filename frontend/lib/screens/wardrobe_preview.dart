import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Color _shadeColor(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + delta).clamp(0.0, 1.0).toDouble())
      .toColor();
}

// Preview card for the Wardrobe mannequin
class MannequinCard extends StatelessWidget {
  final Color? shirtColor;
  final Color? pantsColor;

  const MannequinCard({super.key, this.shirtColor, this.pantsColor});

  @override
  Widget build(BuildContext context) {
    final shirt =
        shirtColor ??
        Color.alphaBlend(AppColors.mid.withOpacity(0.18), Colors.white);

    final skirt =
        pantsColor ??
        Color.alphaBlend(AppColors.charcoal.withOpacity(0.16), Colors.white);

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
            child: CustomPaint(
              painter: MannequinPainter(shirt: shirt, skirt: skirt),
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

// Draw the mannequin, clothing and stand
class MannequinPainter extends CustomPainter {
  final Color shirt;
  final Color skirt;

  const MannequinPainter({required this.shirt, required this.skirt});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 190);

    // Floor shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 185), width: 62, height: 8),
      Paint()
        ..color = Colors.black.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Stand pole
    final pole = Rect.fromLTRB(48.6, 148, 51.4, 178);

    canvas.drawRect(
      pole,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB5B5B5), Color(0xFFF4F4F4), Color(0xFF9A9A9A)],
        ).createShader(pole),
    );

    // Wooden base
    canvas.drawRect(
      const Rect.fromLTRB(28, 178, 72, 181.5),
      Paint()..color = const Color(0xFFB98C55),
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 181.5), width: 44, height: 10),
      Paint()..color = const Color(0xFFB98C55),
    );

    final base = Rect.fromCenter(
      center: const Offset(50, 178),
      width: 44,
      height: 10,
    );

    canvas.drawOval(
      base,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFEFCF9E), Color(0xFFDDB57C)],
        ).createShader(base),
    );

    // Skirt
    final skirtPath = Path()
      ..moveTo(36, 95)
      ..cubicTo(35, 112, 24, 132, 15, 150)
      ..cubicTo(34, 155, 66, 155, 85, 150)
      ..cubicTo(76, 132, 65, 112, 64, 95)
      ..close();

    final skirtBounds = const Rect.fromLTRB(15, 95, 85, 155);

    canvas.drawPath(
      skirtPath,
      Paint()
        ..shader = LinearGradient(
          colors: [_shadeColor(skirt, 0.07), skirt, _shadeColor(skirt, -0.1)],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(skirtBounds),
    );

    canvas.save();
    canvas.clipPath(skirtPath);

    Path pleat(bool right) {
      double x(double value) => right ? 100 - value : value;

      return Path()
        ..moveTo(x(42), 95)
        ..cubicTo(x(41), 115, x(38), 135, x(33), 156)
        ..lineTo(x(39), 156)
        ..cubicTo(x(44), 135, x(46), 115, x(47), 95)
        ..close();
    }

    final fold = Paint()..color = Colors.black.withOpacity(0.10);

    canvas.drawPath(pleat(false), fold);
    canvas.drawPath(pleat(true), fold);

    final waistShade = const Rect.fromLTRB(30, 95, 70, 112);

    canvas.drawRect(
      waistShade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.10),
            Colors.black.withOpacity(0.0),
          ],
        ).createShader(waistShade),
    );

    canvas.restore();

    canvas.drawPath(
      Path()
        ..moveTo(15, 150)
        ..cubicTo(34, 155, 66, 155, 85, 150),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _shadeColor(skirt, -0.14).withOpacity(0.55),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(35.5, 91, 64.5, 96.5),
        const Radius.circular(1.5),
      ),
      Paint()..color = _shadeColor(skirt, -0.05),
    );

    // Mannequin head and neck
    final head = Rect.fromCenter(
      center: const Offset(50, 17),
      width: 21,
      height: 28,
    );

    final neck = const Rect.fromLTRB(46.5, 29, 53.5, 44);

    canvas.drawRRect(
      RRect.fromRectAndRadius(neck, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD2BA94), Color(0xFFF1E1C8), Color(0xFFC9AF88)],
        ).createShader(neck),
    );

    canvas.drawOval(
      head,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [Color(0xFFFBF1DF), Color(0xFFE9D5B5), Color(0xFFCDB48E)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(head),
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(46, 9), width: 5, height: 9),
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );

    // Sweater
    final sweaterBounds = const Rect.fromLTRB(14, 40, 86, 100);

    final sweaterPaint = Paint()
      ..shader = LinearGradient(
        colors: [_shadeColor(shirt, 0.05), shirt, _shadeColor(shirt, -0.08)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(sweaterBounds);

    Path sleeve(bool right) {
      double x(double value) => right ? 100 - value : value;

      return Path()
        ..moveTo(x(29), 47)
        ..cubicTo(x(22), 52, x(19), 70, x(17), 92)
        ..lineTo(x(28), 94)
        ..cubicTo(x(29), 80, x(31), 66, x(33), 54)
        ..close();
    }

    final torso = Path()
      ..moveTo(29, 48)
      ..cubicTo(31, 43, 40, 41, 44, 41)
      ..lineTo(56, 41)
      ..cubicTo(60, 41, 69, 43, 71, 48)
      ..lineTo(73, 70)
      ..cubicTo(74, 80, 74, 86, 73, 92)
      ..lineTo(27, 92)
      ..cubicTo(26, 86, 26, 80, 27, 70)
      ..close();

    final ribLine = Paint()
      ..strokeWidth = 0.5
      ..color = Colors.black.withOpacity(0.07);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black.withOpacity(0.10);

    for (final right in [false, true]) {
      final sleevePath = sleeve(right);

      canvas.drawPath(sleevePath, sweaterPaint);
      canvas.save();
      canvas.clipPath(sleevePath);

      for (double x = 15; x <= 36; x += 2.2) {
        final xx = right ? 100 - x : x;
        canvas.drawLine(Offset(xx, 46), Offset(xx, 96), ribLine);
      }

      canvas.restore();
      canvas.drawPath(sleevePath, edge);

      final cuff = Path()
        ..moveTo(right ? 83 : 17, 91)
        ..lineTo(right ? 72 : 28, 93)
        ..lineTo(right ? 72 : 28, 98)
        ..lineTo(right ? 83 : 17, 96)
        ..close();

      canvas.drawPath(cuff, Paint()..color = _shadeColor(shirt, -0.07));
    }

    canvas.drawPath(torso, sweaterPaint);
    canvas.save();
    canvas.clipPath(torso);

    for (double x = 26; x <= 74; x += 2.2) {
      canvas.drawLine(Offset(x, 42), Offset(x, 92), ribLine);
    }

    canvas.drawRect(
      const Rect.fromLTRB(20, 88.5, 80, 93),
      Paint()..color = _shadeColor(shirt, -0.06).withOpacity(0.7),
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(40, 62), width: 10, height: 34),
      Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.restore();
    canvas.drawPath(torso, edge);

    // Neckline
    final neckline = Rect.fromCenter(
      center: const Offset(50, 41.8),
      width: 15,
      height: 5.6,
    );

    canvas.drawOval(neckline, Paint()..color = const Color(0xFFD9C3A0));

    canvas.drawOval(
      neckline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _shadeColor(shirt, -0.08),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MannequinPainter oldDelegate) {
    return oldDelegate.shirt != shirt || oldDelegate.skirt != skirt;
  }
}
