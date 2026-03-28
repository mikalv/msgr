import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Service for picking a contact from the device to share in chat.
class ContactShareService {
  ContactShareService._();
  static final instance = ContactShareService._();

  /// Pick a contact from the device. Returns null if cancelled or denied.
  Future<ContactResult?> pickContact() async {
    if (kIsWeb) return null;

    // Request permission
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted) return null;

    // Get all contacts
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.email, ContactProperty.organization},
    );
    if (contacts.isEmpty) return null;

    // TODO: show a proper contact picker dialog instead of using first contact
    final full = contacts.first;
    final displayName = [full.name?.first, full.name?.last]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    return ContactResult(
      name: displayName.isNotEmpty ? displayName : 'Unknown',
      phone: full.phones.isNotEmpty ? full.phones.first.number : null,
      email: full.emails.isNotEmpty ? full.emails.first.address : null,
      organization: full.organizations.isNotEmpty ? full.organizations.first.name : null,
    );
  }
}

class ContactResult {
  const ContactResult({
    required this.name,
    this.phone,
    this.email,
    this.organization,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? organization;

  /// Build content map for sending as a message.
  Map<String, dynamic> toContentMap() => {
    'type': 'contact',
    'text': '$name${phone != null ? ' — $phone' : ''}',
    'name': name,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (organization != null) 'organization': organization,
  };
}
