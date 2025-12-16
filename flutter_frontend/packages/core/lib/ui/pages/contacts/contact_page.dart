import 'package:flutter/cupertino.dart';

import '../../../features/contacts/domain/contact_entry.dart';
import 'edit_contact_page.dart';
import 'widgets/contact_avatar.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({
    super.key,
    required this.contact,
  });

  final ContactEntry contact;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(contact.displayName),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                final updated = await Navigator.of(context).push<ContactEntry>(
                  CupertinoPageRoute(
                    builder: (_) => EditContactPage(contact: contact),
                  ),
                );
                if (updated != null) {
                  Navigator.of(context).pop(updated);
                }
              },
              child: const Text('Endre'),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ContactDetailView(contact: contact),
          ),
        ],
      ),
    );
  }
}

class _ContactDetailView extends StatelessWidget {
  const _ContactDetailView({required this.contact});

  final ContactEntry contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                ContactAvatar(contact: contact, size: 96),
                const SizedBox(height: 12),
                Text(
                  contact.displayName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (contact.msgrHandle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '@${contact.msgrHandle}',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (contact.phones.isNotEmpty)
            _DetailSection(
              title: 'Telefon',
              values: contact.phones,
            ),
          if (contact.emails.isNotEmpty)
            _DetailSection(
              title: 'E-post',
              values: contact.emails,
            ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          ...values.map(
            (value) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color:
                    CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
                  context,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
