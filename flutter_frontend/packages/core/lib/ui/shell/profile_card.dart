import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _avatarSize = 64.0;

const _nameColors = <Color>[
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFFE57373),
  Color(0xFF4DD0E1),
  Color(0xFFFFF176),
  Color(0xFFA1887F),
  Color(0xFF90A4AE),
  Color(0xFFF06292),
];

Color _colorForName(String name) {
  var hash = 0;
  for (var i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return _nameColors[hash.abs() % _nameColors.length];
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) {
  return '${_monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ---------------------------------------------------------------------------
// Public API: show profile card
// ---------------------------------------------------------------------------

/// Show a profile card modal for a given profile.
///
/// If [profile] has limited data (e.g. only id and displayName from a message),
/// the card will fetch full details from the API.
///
/// Set [isOwnProfile] to true to show edit button instead of send message.
void showProfileCard(
  BuildContext context, {
  required MsgrProfile profile,
  bool isOwnProfile = false,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _ProfileCardDialog(
      profile: profile,
      isOwnProfile: isOwnProfile,
    ),
  );
}

/// Show a profile card by profile ID, fetching data from API.
void showProfileCardById(
  BuildContext context,
  WidgetRef ref, {
  required String profileId,
}) {
  final auth = ref.read(simpleAuthProvider);
  final isOwn = auth.profileId == profileId;

  showDialog(
    context: context,
    builder: (ctx) => _ProfileCardByIdDialog(
      profileId: profileId,
      isOwnProfile: isOwn,
    ),
  );
}

// ---------------------------------------------------------------------------
// Profile card dialog (when we already have a MsgrProfile)
// ---------------------------------------------------------------------------

class _ProfileCardDialog extends ConsumerStatefulWidget {
  const _ProfileCardDialog({
    required this.profile,
    required this.isOwnProfile,
  });

  final MsgrProfile profile;
  final bool isOwnProfile;

  @override
  ConsumerState<_ProfileCardDialog> createState() => _ProfileCardDialogState();
}

class _ProfileCardDialogState extends ConsumerState<_ProfileCardDialog> {
  MsgrProfile? _fullProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) {
      setState(() {
        _fullProfile = widget.profile;
        _loading = false;
      });
      return;
    }

    try {
      final client = ref.read(msgrApiProvider);
      final data = await client.getProfile(team.slug, widget.profile.id);
      if (mounted) {
        setState(() {
          _fullProfile = MsgrProfile.fromJson(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _fullProfile = widget.profile;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return _ProfileCardContent(
      profile: _fullProfile ?? widget.profile,
      isOwnProfile: widget.isOwnProfile,
    );
  }
}

// ---------------------------------------------------------------------------
// Profile card dialog (when we only have a profile ID)
// ---------------------------------------------------------------------------

class _ProfileCardByIdDialog extends ConsumerStatefulWidget {
  const _ProfileCardByIdDialog({
    required this.profileId,
    required this.isOwnProfile,
  });

  final String profileId;
  final bool isOwnProfile;

  @override
  ConsumerState<_ProfileCardByIdDialog> createState() =>
      _ProfileCardByIdDialogState();
}

class _ProfileCardByIdDialogState
    extends ConsumerState<_ProfileCardByIdDialog> {
  MsgrProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) {
      setState(() {
        _error = 'No team selected';
        _loading = false;
      });
      return;
    }

    try {
      final client = ref.read(msgrApiProvider);
      final data = await client.getProfile(team.slug, widget.profileId);
      if (mounted) {
        setState(() {
          _profile = MsgrProfile.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load profile';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _profile == null) {
      return AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        content: Text(
          _error ?? 'Could not load profile',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return _ProfileCardContent(
      profile: _profile!,
      isOwnProfile: widget.isOwnProfile,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared profile card content
// ---------------------------------------------------------------------------

class _ProfileCardContent extends ConsumerWidget {
  const _ProfileCardContent({
    required this.profile,
    required this.isOwnProfile,
  });

  final MsgrProfile profile;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForName(profile.displayName);
    final initials = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: _avatarSize / 2,
                backgroundColor: color.withOpacity(0.25),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Display name
              Text(
                profile.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // Handle (use id as fallback)
              Text(
                '@${profile.displayName.toLowerCase().replaceAll(' ', '.')}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),

              // Role badge
              if (profile.role != null && profile.role!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleBadgeColor(profile.role!).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _roleBadgeColor(profile.role!).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _formatRole(profile.role!),
                    style: TextStyle(
                      color: _roleBadgeColor(profile.role!),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),

              // Contact info rows
              if (profile.email != null && profile.email!.isNotEmpty)
                _InfoRow(icon: Icons.email_outlined, label: profile.email!),
              if (profile.phone != null && profile.phone!.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, label: profile.phone!),

              // Member since
              if (profile.insertedAt != null)
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member since ${_formatDate(profile.insertedAt!)}',
                ),

              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                child: isOwnProfile
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showEditProfileDialog(context, ref);
                        },
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Send message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF02ac88),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            _createDmAndNavigate(context, ref),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createDmAndNavigate(BuildContext context, WidgetRef ref) async {
    final team = ref.read(selectedTeamProvider);
    final auth = ref.read(simpleAuthProvider);
    if (team == null || auth.profileId == null) return;

    Navigator.of(context).pop();

    try {
      final client = ref.read(msgrApiProvider);
      final raw = await client.createDm(
        team.slug,
        [auth.profileId!, profile.id],
      );
      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;

      final channelId = data['id']?.toString();
      if (channelId == null) return;

      // Refresh channel list and select the new DM
      await ref.read(channelListProvider.notifier).refresh();

      final channels = ref.read(channelListProvider).channels;
      final dmChannel = channels.where((c) => c.id == channelId).firstOrNull;
      if (dmChannel != null) {
        ref.read(selectedChannelProvider.notifier).select(dmChannel);
      }
    } catch (_) {
      // Silently fail — DM creation may not be available
    }
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _EditProfileDialog(teamSlug: team.slug),
    );
  }

  static Color _roleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFFFFD54F);
      case 'admin':
        return const Color(0xFF4FC3F7);
      default:
        return const Color(0xFF81C784);
    }
  }

  static String _formatRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1);
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile dialog
// ---------------------------------------------------------------------------

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final auth = ref.read(simpleAuthProvider);
    _nameController.text = auth.displayName ?? '';
    _emailController.text = auth.email ?? '';

    // Try to fetch full profile for phone number
    if (auth.profileId != null) {
      try {
        final client = ref.read(msgrApiProvider);
        final data =
            await client.getProfile(widget.teamSlug, auth.profileId!);
        if (mounted) {
          final profile = MsgrProfile.fromJson(data);
          _nameController.text = profile.displayName;
          if (profile.email != null) _emailController.text = profile.email!;
          if (profile.phone != null) _phoneController.text = profile.phone!;
        }
      } catch (_) {
        // Use auth state values as fallback
      }
    }

    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final client = ref.read(msgrApiProvider);
      await client.updateMyProfile(
        widget.teamSlug,
        displayName: name,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3E),
      title: const Text(
        'Edit profile',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 360,
        child: !_loaded
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar placeholder
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white38,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Avatar upload coming soon',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField(_nameController, 'Display name', autofocus: true),
                  const SizedBox(height: 12),
                  _buildField(_emailController, 'Email (optional)',
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildField(_phoneController, 'Phone (optional)',
                      keyboardType: TextInputType.phone),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF02ac88),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
