import 'package:flutter/cupertino.dart';

import '../../../features/contacts/domain/contact_entry.dart';
import '../../../features/contacts/services/contact_importer.dart';
import 'contact_page.dart';
import 'widgets/contact_list_tile.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({
    super.key,
    ContactImporter? importer,
  }) : importer = importer ?? SystemContactImporter();

  final ContactImporter importer;

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

enum _ContactListStatus { loading, permissionDenied, empty, ready }

class _ContactListPageState extends State<ContactListPage> {
  var _status = _ContactListStatus.loading;
  var _contacts = <ContactEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _ContactListStatus.loading);
    final permitted = await widget.importer.ensurePermission();
    if (!mounted) return;

    if (!permitted) {
      setState(() => _status = _ContactListStatus.permissionDenied);
      return;
    }

    final contacts = await widget.importer.loadContacts();
    if (!mounted) return;

    setState(() {
      _contacts = contacts;
      _status = contacts.isEmpty
          ? _ContactListStatus.empty
          : _ContactListStatus.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[
      const CupertinoSliverNavigationBar(
        largeTitle: Text('Kontakter'),
      ),
    ];

    switch (_status) {
      case _ContactListStatus.loading:
        slivers.add(
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator()),
          ),
        );
        break;
      case _ContactListStatus.permissionDenied:
        slivers.add(
          SliverFillRemaining(
            hasScrollBody: false,
            child: _PermissionDeniedView(onRetry: _load),
          ),
        );
        break;
      case _ContactListStatus.empty:
        slivers.add(
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyStateView(),
          ),
        );
        break;
      case _ContactListStatus.ready:
        slivers.addAll(_buildContactSlivers());
        break;
    }

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: slivers,
      ),
    );
  }

  List<Widget> _buildContactSlivers() {
    return [
      CupertinoSliverRefreshControl(onRefresh: _load),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final contact = _contacts[index];
            final showDivider = index < _contacts.length - 1;
            return Column(
              children: [
                ContactListTile(
                  contact: contact,
                  onTap: () => _openContact(contact),
                ),
                if (showDivider)
                  Container(
                    color: CupertinoColors.separator.resolveFrom(context),
                    height: 0.5,
                  ),
              ],
            );
          },
          childCount: _contacts.length,
        ),
      ),
    ];
  }

  Future<void> _openContact(ContactEntry contact) async {
    final updated = await Navigator.of(context).push<ContactEntry>(
      CupertinoPageRoute(
        builder: (_) => ContactPage(contact: contact),
      ),
    );

    if (updated == null) {
      return;
    }

    final index = _contacts.indexWhere((element) => element.id == contact.id);
    if (index == -1) {
      return;
    }

    setState(() {
      _contacts = List<ContactEntry>.of(_contacts)
        ..[index] = updated;
    });
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.lock_fill,
            size: 48,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tillatelse kreves',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gi Messengr tilgang til kontaktene dine for å se hvem som allerede er på plattformen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('Prøv igjen'),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            CupertinoIcons.person_crop_circle_badge_plus,
            size: 48,
            color: CupertinoColors.activeBlue,
          ),
          SizedBox(height: 16),
          Text(
            'Ingen kontakter ennå',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Legg til kontakter manuelt eller importer fra systemet når du har gitt tilgang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
