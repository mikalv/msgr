import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';

/// Full-screen profile setup shown after joining a team.
///
/// Required fields: username (for @mentions) and display name.
/// Optional fields can be set later in profile edit.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(simpleAuthProvider);
    // Pre-fill display name if exists (but not if it's the email)
    final existing = auth.displayName ?? '';
    if (existing.isNotEmpty && existing != auth.email) {
      _displayNameController.text = existing;
    }
    // Derive username suggestion from email
    final email = auth.email ?? '';
    if (email.contains('@')) {
      _usernameController.text = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    }
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim().toLowerCase();
    final displayName = _displayNameController.text.trim();

    if (username.length < 2) {
      setState(() => _error = 'Username must be at least 2 characters');
      return;
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(username)) {
      setState(() => _error = 'Username can only contain lowercase letters, numbers, dots, dashes');
      return;
    }
    if (displayName.length < 2) {
      setState(() => _error = 'Display name must be at least 2 characters');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final client = ref.read(msgrApiProvider);

      // Update account-level
      await client.updateAccount(displayName: displayName, handle: username);

      // Update team-level profile
      final team = ref.read(selectedTeamProvider);
      if (team != null) {
        try {
          await client.updateMyProfile(team.slug, displayName: displayName);
        } catch (_) {}
      }

      // Update local auth state
      final auth = ref.read(simpleAuthProvider);
      ref.read(simpleAuthProvider.notifier).login(
        accountId: auth.accountId!,
        profileId: auth.profileId!,
        email: auth.email,
        displayName: displayName,
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );

      widget.onComplete();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('handle') || msg.contains('unique')) {
        setState(() => _error = 'Username "$username" is already taken');
      } else {
        setState(() => _error = msg);
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D21),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007A5A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person_add, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Set up your profile',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How should people find and recognize you?',
                    style: TextStyle(fontSize: 15, color: Colors.white.withAlpha(150)),
                  ),
                  const SizedBox(height: 32),

                  // Username
                  _field(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'e.g. ola.nordmann',
                    prefix: '@',
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    helperText: 'Used for @mentions. Lowercase, no spaces.',
                  ),
                  const SizedBox(height: 16),

                  // Display name
                  _field(
                    controller: _displayNameController,
                    label: 'Display name',
                    hint: 'e.g. Ola Nordmann',
                    capitalization: TextCapitalization.words,
                    helperText: 'Shown in messages and member lists.',
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007A5A),
                        disabledBackgroundColor: const Color(0xFF007A5A).withAlpha(100),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'You can add more details later in profile settings',
                    style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(80)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    String? helperText,
    bool autofocus = false,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          autofocus: autofocus,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white.withAlpha(130)),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
            prefixText: prefix,
            prefixStyle: TextStyle(color: Colors.white.withAlpha(100), fontSize: 16),
            filled: true,
            fillColor: Colors.white.withAlpha(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF007A5A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          textInputAction: TextInputAction.next,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(helperText, style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(70))),
        ],
      ],
    );
  }
}
