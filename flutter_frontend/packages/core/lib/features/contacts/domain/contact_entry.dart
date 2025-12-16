import 'dart:typed_data';

import 'package:collection/collection.dart';

/// Represents a contact entry that can be rendered in the UI or synchronised
/// with the backend.
class ContactEntry {
  const ContactEntry({
    required this.id,
    required this.displayName,
    this.givenName,
    this.familyName,
    this.phones = const [],
    this.emails = const [],
    this.avatar,
    this.msgrHandle,
  });

  final String id;
  final String displayName;
  final String? givenName;
  final String? familyName;
  final List<String> phones;
  final List<String> emails;
  final Uint8List? avatar;

  /// Messenger specific username/handle, if present.
  final String? msgrHandle;

  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  String? get primaryPhone => phones.firstOrNull;

  String? get primaryEmail => emails.firstOrNull;

  ContactEntry copyWith({
    String? displayName,
    String? givenName,
    String? familyName,
    List<String>? phones,
    List<String>? emails,
    Uint8List? avatar,
    String? msgrHandle,
  }) {
    return ContactEntry(
      id: id,
      displayName: displayName ?? this.displayName,
      givenName: givenName ?? this.givenName,
      familyName: familyName ?? this.familyName,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      avatar: avatar ?? this.avatar,
      msgrHandle: msgrHandle ?? this.msgrHandle,
    );
  }
}
