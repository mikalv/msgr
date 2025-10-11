import 'package:flutter/material.dart';

InputDecoration authInputDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
  String? helperText,
  String? hintText,
}) {
  final Color primary = const Color(0xFF6366F1);
  final Color borderColor = Colors.white.withOpacity(0.18);
  final Color fillColor = Colors.white.withOpacity(0.06);
  OutlineInputBorder buildBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: 1.2),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    helperText: helperText,
    helperMaxLines: 2,
    prefixIcon: icon != null
        ? Icon(
            icon,
            color: Colors.white70,
          )
        : null,
    filled: true,
    fillColor: fillColor,
    labelStyle: const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    helperStyle: const TextStyle(color: Colors.white60),
    hintStyle: const TextStyle(color: Colors.white54),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: buildBorder(borderColor),
    enabledBorder: buildBorder(borderColor),
    focusedBorder: buildBorder(primary),
    errorBorder: buildBorder(Colors.redAccent.withOpacity(0.8)),
    focusedErrorBorder: buildBorder(Colors.redAccent),
  );
}
