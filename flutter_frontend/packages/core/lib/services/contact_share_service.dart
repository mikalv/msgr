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
    if (!await FlutterContacts.requestPermission()) return null;

    // Open native contact picker — returns null if cancelled
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return null;

    // Fetch full contact data
    final full = await FlutterContacts.getContact(contact.id, withProperties: true);
    if (full == null) return null;

    return ContactResult(
      name: full.displayName,
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
