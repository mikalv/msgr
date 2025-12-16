import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:characters/characters.dart';

import '../../../../features/contacts/domain/contact_entry.dart';

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.contact,
    this.size = 48,
  });

  final ContactEntry contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (contact.hasAvatar) {
      return _ImageAvatar(avatar: contact.avatar!, size: size);
    }

    return _InitialsAvatar(
      displayName: contact.displayName,
      size: size,
    );
  }
}

class _ImageAvatar extends StatelessWidget {
  const _ImageAvatar({required this.avatar, required this.size});

  final Uint8List avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.memory(
        avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.displayName, required this.size});

  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(displayName);
    final color = _colorFromName(displayName);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty
          ? '?'
          : parts.first.characters.take(2).toString().toUpperCase();
    }

    final first = parts.first.isNotEmpty ? parts.first.characters.first : '';
    final last = parts.last.isNotEmpty ? parts.last.characters.first : '';
    final initials = (first + last).trim();
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }

  static Color _colorFromName(String name) {
    final normalized = name.toLowerCase().codeUnits.fold<int>(0, (prev, code) => prev + code);
    final hue = (normalized % 360).toDouble();
    final hslColor = HSLColor.fromAHSL(1, hue, 0.45, 0.65);
    final materialColor = hslColor.toColor();
    return Color.fromARGB(
      255,
      materialColor.red,
      materialColor.green,
      materialColor.blue,
    );
  }
}
