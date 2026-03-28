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
    final status = await FlutterContacts.permissions.request(PermissionType.contacts);
    if (status != PermissionStatus.granted) return null;

    // Get all contacts and let user pick (flutter_contacts v2 API)
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phones, ContactProperty.emails, ContactProperty.organizations},
    );
    if (contacts.isEmpty) return null;

    // Return the first contact for now — a proper picker UI should be built
    // TODO: show a contact picker dialog
    final full = contacts.first;

    return ContactResult(
      name: full.name.display,
      phone: full.phones.isNotEmpty ? full.phones.first.number : null,
      email: full.emails.isNotEmpty ? full.emails.first.address : null,
      organization: full.organizations.isNotEmpty ? full.organizations.first.company : null,
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
