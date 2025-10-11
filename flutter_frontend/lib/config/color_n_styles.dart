import 'package:flutter/widgets.dart';

class AppColors {
  static const primary = Color(0xFFFA7070);
  static const second = Color(0xFFFBF2CF);
  static const white = Color(0xFFF4FAFB);
  static const black = Color(0xFF292526);
}

class AppStyles {
  static TextStyle appTextStyle({
    double size = 16,
    Color? color,
    FontWeight? weight,
    double letterSpacing = 1.5,
    TextOverflow? overFlow,
    TextDecoration? decoration,
  }) {
    return TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        overflow: overFlow,
        decoration: decoration);
  }

  static TextStyle large({Color color = AppColors.black}) {
    return appTextStyle(
      size: 38,
      color: color,
      weight: FontWeight.bold,
    );
  }

  static TextStyle medium() {
    return appTextStyle(
      size: 18,
      color: AppColors.primary,
      weight: FontWeight.w600,
    );
  }

  static TextStyle regular({color = AppColors.black}) {
    return appTextStyle(
      color: color,
      weight: FontWeight.w500,
    );
  }

  static TextStyle light(
      {TextOverflow? overflow, Color color = AppColors.black}) {
    return appTextStyle(
        size: 12, color: color, weight: FontWeight.w400, overFlow: overflow);
  }

  static TextStyle links() {
    return appTextStyle(
      size: 12,
      color: AppColors.primary,
      weight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
  }
}
