import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as system_contacts;
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/contact_entry.dart';

/// Abstraction around retrieving contacts from the underlying platform so the
/// UI can be tested without depending on plugins.
abstract class ContactImporter {
  Future<bool> ensurePermission();

  Future<List<ContactEntry>> loadContacts();
}

class SystemContactImporter implements ContactImporter {
  SystemContactImporter({
    Logger? log,
  }) : _log = log ?? Logger('SystemContactImporter');

  final Logger _log;

  @override
  Future<bool> ensurePermission() async {
    if (kIsWeb) {
      _log.info('Contact permission is unavailable on the web platform.');
      return false;
    }

    try {
      final status = await Permission.contacts.status;
      if (status.isGranted) {
        return true;
      }

      final result = await Permission.contacts.request();
      return result.isGranted;
    } catch (error, stackTrace) {
      _log.warning('Requesting contact permission failed', error, stackTrace);
      return false;
    }
  }

  @override
  Future<List<ContactEntry>> loadContacts() async {
    if (kIsWeb) {
      return const [];
    }

    try {
      final contacts = await system_contacts.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      return contacts
          .map(
            (contact) => ContactEntry(
              id: contact.id,
              displayName: contact.displayName,
              givenName: contact.name.first,
              familyName: contact.name.last,
              phones:
                  contact.phones.map((phone) => phone.number.trim()).toList(),
              emails:
                  contact.emails.map((email) => email.address.trim()).toList(),
              avatar: contact.photo,
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      _log.severe('Failed to load contacts', error, stackTrace);
      return const [];
    }
  }
}
