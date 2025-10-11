import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/contacts/domain/contact_entry.dart';
import 'package:messngr/features/contacts/services/contact_importer.dart';
import 'package:messngr/ui/pages/contacts/contact_list_page.dart';
import 'package:messngr/ui/pages/contacts/edit_contact_page.dart';

class _FakeContactImporter implements ContactImporter {
  _FakeContactImporter({
    required this.permissionGranted,
    this.contacts = const [],
  });

  final bool permissionGranted;
  final List<ContactEntry> contacts;

  @override
  Future<bool> ensurePermission() async {
    return permissionGranted;
  }

  @override
  Future<List<ContactEntry>> loadContacts() async {
    return contacts;
  }
}

void main() {
  group('ContactListPage', () {
    testWidgets('renders contacts when permission granted', (tester) async {
      final importer = _FakeContactImporter(
        permissionGranted: true,
        contacts: [
          const ContactEntry(
            id: '1',
            displayName: 'Ola Nordmann',
            phones: ['+47 555 66 777'],
          ),
          const ContactEntry(
            id: '2',
            displayName: 'Kari Nordmann',
            emails: ['kari@example.com'],
          ),
        ],
      );

      await tester.pumpWidget(
        CupertinoApp(home: ContactListPage(importer: importer)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ola Nordmann'), findsOneWidget);
      expect(find.text('Kari Nordmann'), findsOneWidget);
      expect(find.text('+47 555 66 777'), findsOneWidget);
      expect(find.text('kari@example.com'), findsOneWidget);
    });

    testWidgets('shows permission messaging when denied', (tester) async {
      final importer = _FakeContactImporter(permissionGranted: false);

      await tester.pumpWidget(
        CupertinoApp(home: ContactListPage(importer: importer)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tillatelse kreves'), findsOneWidget);
      expect(find.text('Prøv igjen'), findsOneWidget);
    });
  });

  group('EditContactPage', () {
    testWidgets('saves updated fields and notifies listener', (tester) async {
      const initialContact = ContactEntry(
        id: '1',
        displayName: 'Ukjent',
      );

      ContactEntry? savedContact;

      await tester.pumpWidget(
        CupertinoApp(
          home: EditContactPage(
            contact: initialContact,
            onSubmit: (contact) => savedContact = contact,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('contactDisplayNameField')),
        'Oda Messengr',
      );
      await tester.enterText(
        find.byKey(const Key('contactGivenNameField')),
        'Oda',
      );
      await tester.enterText(
        find.byKey(const Key('contactFamilyNameField')),
        'Messengr',
      );
      await tester.enterText(
        find.byKey(const Key('contactHandleField')),
        'oda',
      );

      await tester.tap(find.byKey(const Key('addPhoneButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('phoneField_0')), '+47 123 45 678');

      await tester.tap(find.byKey(const Key('addEmailButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('emailField_0')), 'oda@msgr.no');

      await tester.tap(find.text('Lagre'));
      await tester.pumpAndSettle();

      expect(savedContact, isNotNull);
      expect(savedContact!.displayName, 'Oda Messengr');
      expect(savedContact!.givenName, 'Oda');
      expect(savedContact!.familyName, 'Messengr');
      expect(savedContact!.msgrHandle, 'oda');
      expect(savedContact!.phones, ['+47 123 45 678']);
      expect(savedContact!.emails, ['oda@msgr.no']);
    });
  });
}
