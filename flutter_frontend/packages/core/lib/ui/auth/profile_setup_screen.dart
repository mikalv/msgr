import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';

/// Full-screen profile setup shown after login when the user has no display name.
///
/// This is a MANDATORY step — the user cannot proceed to the app without
/// setting a display name. Updates both account-level and team-level profile.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(simpleAuthProvider);
    // Pre-fill if there's an existing name (but not if it's just the email)
    final existing = auth.displayName ?? '';
    if (existing.isNotEmpty && existing != auth.email) {
      _nameController.text = existing;
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final client = ref.read(msgrApiProvider);

      // 1. Update account-level display name
      await client.updateAccount(displayName: name);

      // 2. Update team-level profile if we have a team selected
      final team = ref.read(selectedTeamProvider);
      if (team != null) {
        try {
          await client.updateMyProfile(team.slug, displayName: name);
        } catch (_) {
          // Team profile update is best-effort
        }
      }

      // 3. Update local auth state
      final auth = ref.read(simpleAuthProvider);
      ref.read(simpleAuthProvider.notifier).login(
        accountId: auth.accountId!,
        profileId: auth.profileId!,
        email: auth.email,
        displayName: name,
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );

      widget.onComplete();
    } catch (e) {
      setState(() => _error = e.toString());
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007A5A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Welcome to Msgr',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'What should we call you?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 32),

                // Name field
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    labelStyle: TextStyle(color: Colors.white.withAlpha(130)),
                    hintText: 'e.g. Ola Nordmann',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
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
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],

                const SizedBox(height: 24),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007A5A),
                      disabledBackgroundColor: const Color(0xFF007A5A).withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'You can change this later in settings',
                  style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(80)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
