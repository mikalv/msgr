import 'package:flutter/cupertino.dart';

import '../../../features/contacts/domain/contact_entry.dart';

class EditContactPage extends StatefulWidget {
  const EditContactPage({
    super.key,
    required this.contact,
    this.onSubmit,
  });

  final ContactEntry contact;
  final ValueChanged<ContactEntry>? onSubmit;

  @override
  State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  late TextEditingController _givenNameController;
  late TextEditingController _familyNameController;
  late TextEditingController _displayNameController;
  late TextEditingController _handleController;
  late List<TextEditingController> _phoneControllers;
  late List<TextEditingController> _emailControllers;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _givenNameController = TextEditingController(text: contact.givenName);
    _familyNameController = TextEditingController(text: contact.familyName);
    _displayNameController = TextEditingController(text: contact.displayName);
    _handleController = TextEditingController(text: contact.msgrHandle);
    _phoneControllers =
        contact.phones.map((value) => TextEditingController(text: value)).toList();
    _emailControllers =
        contact.emails.map((value) => TextEditingController(text: value)).toList();
  }

  @override
  void dispose() {
    _givenNameController.dispose();
    _familyNameController.dispose();
    _displayNameController.dispose();
    _handleController.dispose();
    for (final controller in _phoneControllers) {
      controller.dispose();
    }
    for (final controller in _emailControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPhoneField() {
    setState(() {
      _phoneControllers.add(TextEditingController());
    });
  }

  void _addEmailField() {
    setState(() {
      _emailControllers.add(TextEditingController());
    });
  }

  void _removePhoneField(int index) {
    setState(() {
      final controller = _phoneControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _removeEmailField(int index) {
    setState(() {
      final controller = _emailControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _onSave() {
    final updated = widget.contact.copyWith(
      displayName: _displayNameController.text.trim().isEmpty
          ? widget.contact.displayName
          : _displayNameController.text.trim(),
      givenName: _givenNameController.text.trim().isEmpty
          ? null
          : _givenNameController.text.trim(),
      familyName: _familyNameController.text.trim().isEmpty
          ? null
          : _familyNameController.text.trim(),
      phones: _phoneControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      emails: _emailControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      msgrHandle: _handleController.text.trim().isEmpty
          ? null
          : _handleController.text.trim(),
    );

    widget.onSubmit?.call(updated);
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Rediger kontakt'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildNameSection(),
            const SizedBox(height: 32),
            _buildPhonesSection(),
            const SizedBox(height: 32),
            _buildEmailsSection(),
            const SizedBox(height: 32),
            _buildHandleSection(),
            const SizedBox(height: 40),
            CupertinoButton.filled(
              onPressed: _onSave,
              child: const Text('Lagre'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Navn',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        CupertinoTextFormFieldRow(
          key: const Key('contactDisplayNameField'),
          controller: _displayNameController,
          placeholder: 'Visningsnavn',
        ),
        CupertinoTextFormFieldRow(
          key: const Key('contactGivenNameField'),
          controller: _givenNameController,
          placeholder: 'Fornavn',
        ),
        CupertinoTextFormFieldRow(
          key: const Key('contactFamilyNameField'),
          controller: _familyNameController,
          placeholder: 'Etternavn',
        ),
      ],
    );
  }

  Widget _buildPhonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Telefon',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            CupertinoButton(
              key: const Key('addPhoneButton'),
              padding: EdgeInsets.zero,
              onPressed: _addPhoneField,
              child: const Icon(CupertinoIcons.add_circled),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_phoneControllers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Ingen telefonnumre lagt til'),
          ),
        ...List.generate(_phoneControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextFormFieldRow(
                    key: Key('phoneField_$index'),
                    controller: _phoneControllers[index],
                    placeholder: '+47 123 45 678',
                    keyboardType: TextInputType.phone,
                  ),
                ),
                CupertinoButton(
                  key: Key('removePhoneButton_$index'),
                  padding: EdgeInsets.zero,
                  onPressed: () => _removePhoneField(index),
                  child: const Icon(CupertinoIcons.minus_circle),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'E-post',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            CupertinoButton(
              key: const Key('addEmailButton'),
              padding: EdgeInsets.zero,
              onPressed: _addEmailField,
              child: const Icon(CupertinoIcons.add_circled),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_emailControllers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Ingen e-postadresser lagt til'),
          ),
        ...List.generate(_emailControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextFormFieldRow(
                    key: Key('emailField_$index'),
                    controller: _emailControllers[index],
                    placeholder: 'navn@msgr.no',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                CupertinoButton(
                  key: Key('removeEmailButton_$index'),
                  padding: EdgeInsets.zero,
                  onPressed: () => _removeEmailField(index),
                  child: const Icon(CupertinoIcons.minus_circle),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHandleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Msgr-handle',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        CupertinoTextFormFieldRow(
          key: const Key('contactHandleField'),
          controller: _handleController,
          placeholder: 'brukernavn',
          prefix: const Text('@'),
        ),
      ],
    );
  }
}
