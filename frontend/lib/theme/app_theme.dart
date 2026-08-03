import 'package:flutter/material.dart';

/// สีพื้นหลัง
class AppColors {
  static const cream = Color.fromARGB(255, 249, 238, 233); //พื้นหลัง
  static const charcoal = Color(0xFF2C2825);
  static const gold = Color(0xFFC9A96E);
  static const blush = Color(0xFFD4A5A5);
  static const sage = Color(0xFF8FAF9F);
  static const mauve = Color.fromARGB(255, 10, 71, 2);
  static const mid = Color.fromARGB(255, 17, 7, 1);
  //สีข้อความคำอธิบายตัวเล็กต่างๆ
  static const white = Color.fromARGB(255, 253, 252, 255);
  //กล่องhistory,กล่องProfile,กล่องบอกสีที่เหมาะกับผู้ใช้ outfit checker

  //สีพื้นหลังของทุกหน้าแบบไล่สี
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xfffff9f2), Color(0xfffcf6ef), Color(0xFFF7E4E2)],
    stops: [0.0, 0.55, 1.0],
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Nunito',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xfffee8f2),
        primary: AppColors.gold,
        secondary: AppColors.blush,
        surface: AppColors.white,
        background: AppColors.cream,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.charcoal),
        titleTextStyle: TextStyle(
          color: AppColors.charcoal,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xff4c3935),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),

          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

//Reusable rounded card container used across screens
class SoftCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class GradientScaffold extends StatelessWidget {
  final Widget body;
  final bool safeArea;

  const GradientScaffold({super.key, required this.body, this.safeArea = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: safeArea ? SafeArea(child: body) : body,
      ),
    );
  }
}

class GradientBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const GradientBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 18,
          color: AppColors.charcoal,
        ),
      ),
    );
  }
}
