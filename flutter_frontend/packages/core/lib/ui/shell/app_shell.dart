import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/draft_provider.dart';
import 'package:core/providers/models.dart' hide ChannelKind;
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';
import 'package:core/providers/unread_provider.dart';
import 'package:core/providers/web_push_provider.dart';
import 'package:core/providers/web_push_stub.dart' if (dart.library.html) 'package:core/providers/web_push_web.dart' as webPushImpl;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:core/ui/settings/settings_page.dart';

import 'package:core/ui/theme/msgr_theme.dart';
import 'package:core/ui/widgets/avatar_upload_dialog.dart';

import 'channel_sidebar.dart';
import 'quick_switcher.dart';
import 'shell_models.dart';
import 'team_rail.dart';

/// Main responsive app shell wrapping the chat content area.
///
/// Layout strategy:
///   - Desktop (> 1024 px): `[TeamRail | ChannelSidebar | child]`
///   - Tablet  (600-1024 px): `[ChannelSidebar | child]` with a [Drawer] for
///     the team rail.
///   - Mobile  (< 600 px): Only [child] is shown; team and channel selection
///     happens through full-screen navigation.
///
/// State is driven by Riverpod providers:
///   - [teamListProvider] / [selectedTeamProvider] for team selection
///   - [channelListProvider] / [selectedChannelProvider] for channel selection
///   - [unreadCountsProvider] for badges
///   - [channelDraftsProvider] for draft indicators
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  /// The chat content area that fills the remaining space.
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;

  /// Channel navigation history for Cmd+[ / Cmd+] support.
  final List<String> _channelHistory = [];
  int _channelHistoryIndex = -1;

  /// Track which teams we've already shown profile setup for this session.
  final Set<String> _profileSetupShownFor = {};

  @override
  void initState() {
    super.initState();
    // Check profile on first team load
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfileSetup());
  }

  /// Show profile setup dialog if the user's team profile has no display_name.
  Future<void> _checkProfileSetup() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;
    if (_profileSetupShownFor.contains(team.slug)) return;

    try {
      final client = ref.read(msgrApiProvider);
      final profiles = await client.getProfiles(team.slug);
      final myProfileId = ref.read(simpleAuthProvider).profileId;
      final myProfile = profiles.where((p) => p['id'] == myProfileId).firstOrNull;

      if (myProfile != null) {
        final displayName = myProfile['display_name']?.toString() ?? '';
        if (displayName.isEmpty || displayName == myProfile['email']) {
          _profileSetupShownFor.add(team.slug);
          if (mounted) await _showProfileSetupDialog(team.slug);
          return;
        }
      }
    } catch (_) {}
    if (team.slug.isNotEmpty) _profileSetupShownFor.add(team.slug);
  }

  /// Whether the modifier key is Meta (macOS) or Control (other platforms).
  bool get _useMeta {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  }

  void _navigateBack() {
    if (_channelHistoryIndex > 0) {
      _channelHistoryIndex--;
      final channelId = _channelHistory[_channelHistoryIndex];
      final channels = ref.read(channelListProvider).channels;
      final ch = channels.where((c) => c.id == channelId).firstOrNull;
      if (ch != null) {
        ref.read(selectedChannelProvider.notifier).select(ch);
      }
    }
  }

  void _navigateForward() {
    if (_channelHistoryIndex < _channelHistory.length - 1) {
      _channelHistoryIndex++;
      final channelId = _channelHistory[_channelHistoryIndex];
      final channels = ref.read(channelListProvider).channels;
      final ch = channels.where((c) => c.id == channelId).firstOrNull;
      if (ch != null) {
        ref.read(selectedChannelProvider.notifier).select(ch);
      }
    }
  }

  void _pushChannelHistory(String channelId) {
    // Trim forward history when navigating to a new channel
    if (_channelHistoryIndex < _channelHistory.length - 1) {
      _channelHistory.removeRange(
          _channelHistoryIndex + 1, _channelHistory.length);
    }
    // Avoid duplicate consecutive entries
    if (_channelHistory.isEmpty || _channelHistory.last != channelId) {
      _channelHistory.add(channelId);
    }
    _channelHistoryIndex = _channelHistory.length - 1;
  }

  void _switchToTeamByIndex(int index) {
    final teams = ref.read(teamsProvider);
    if (index < teams.length) {
      ref.read(selectedTeamProvider.notifier).select(teams[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamState = ref.watch(teamListProvider);

    // Track channel changes for navigation history
    final currentChannel = ref.watch(selectedChannelProvider);
    if (currentChannel != null) {
      // Only push if it differs from current history position
      if (_channelHistory.isEmpty ||
          _channelHistoryIndex < 0 ||
          _channelHistory[_channelHistoryIndex] != currentChannel.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pushChannelHistory(currentChannel.id);
        });
      }
    }

    // Show loading while teams are being fetched
    if (teamState.isLoading && teamState.teams.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show welcome screen when user has no teams
    if (teamState.teams.isEmpty) {
      return _WelcomeScreen(
        error: teamState.error,
        onCreateTeam: () => _showCreateTeamDialog(),
        onJoinTeam: () => _showJoinTeamDialog(),
        onRetry: () => ref.read(teamListProvider.notifier).refresh(),
      );
    }

    return MsgrTheme(
      colors: MsgrColorTokens.dark,
      child: CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Cmd+K / Ctrl+K: Quick switcher
        SingleActivator(LogicalKeyboardKey.keyK, meta: _useMeta, control: !_useMeta):
            () => showQuickSwitcher(context),

        // Cmd+[ / Ctrl+[: Navigate back
        SingleActivator(LogicalKeyboardKey.bracketLeft, meta: _useMeta, control: !_useMeta):
            _navigateBack,

        // Cmd+] / Ctrl+]: Navigate forward
        SingleActivator(LogicalKeyboardKey.bracketRight, meta: _useMeta, control: !_useMeta):
            _navigateForward,

        // Cmd+Shift+N / Ctrl+Shift+N: Create channel
        SingleActivator(LogicalKeyboardKey.keyN, meta: _useMeta, control: !_useMeta, shift: true):
            () => _showCreateChannelDialog(),

        // Cmd+1 through Cmd+9: Switch team by index
        for (var i = 0; i < 9; i++)
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
            meta: _useMeta,
            control: !_useMeta,
          ): () => _switchToTeamByIndex(i),

        // Escape: Toggle sidebar collapsed (close panels)
        const SingleActivator(LogicalKeyboardKey.escape): () {
          setState(() => _sidebarCollapsed = !_sidebarCollapsed);
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1024;
            final isTablet =
                constraints.maxWidth >= 600 && constraints.maxWidth <= 1024;

            if (isDesktop) {
              return _buildDesktop();
            } else if (isTablet) {
              return _buildTablet();
            } else {
              return _buildMobile();
            }
          },
        ),
      ),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers to bridge new providers into the existing shell widgets
  // ---------------------------------------------------------------------------

  List<TeamItem> get _mockTeamsFromProviders {
    final teams = ref.watch(teamsProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);
    return teams.map((t) {
      // Sum unread counts for all channels in this team.
      final channels = ref.read(channelListProvider).channels;
      var teamUnread = 0;
      for (final ch in channels) {
        if (ch.teamSlug == t.slug) {
          teamUnread += unreadCounts[ch.id] ?? 0;
        }
      }
      return TeamItem(
        id: t.id,
        name: t.name,
        slug: t.slug,
        iconEmoji: t.iconEmoji ?? '\u{1F4AC}',
        unreadCount: teamUnread,
      );
    }).toList();
  }

  int get _selectedTeamIndex {
    final selectedTeam = ref.watch(selectedTeamProvider);
    final teams = ref.watch(teamsProvider);
    if (selectedTeam == null || teams.isEmpty) return 0;
    final idx = teams.indexWhere((t) => t.id == selectedTeam.id);
    return idx >= 0 ? idx : 0;
  }

  MsgrTeam? get _activeTeam => ref.watch(selectedTeamProvider);

  List<ChannelItem> get _mockChannelsFromProviders {
    final channelState = ref.watch(channelListProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);
    final drafts = ref.watch(channelDraftsProvider);
    return channelState.publicChannels.map((c) {
      return ChannelItem(
        id: c.id,
        name: c.name,
        slug: c.slug,
        iconEmoji: c.icon ?? '#',
        kind: c.visibility == ChannelVisibility.private
            ? ChannelKind.private
            : ChannelKind.public,
        unreadCount: unreadCounts[c.id] ?? 0,
        hasDraft: drafts[c.id]?.isNotEmpty ?? false,
      );
    }).toList();
  }

  List<DmItem> get _mockDmsFromProviders {
    final channelState = ref.watch(channelListProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);
    final myProfileId = ref.watch(simpleAuthProvider).profileId;

    return channelState.dmChannels.map((c) {
      // Build DM title from member names (exclude self)
      String dmName = c.name;
      final members = c.memberNames;
      if (members != null && members.isNotEmpty) {
        final otherNames = members.entries
            .where((e) => e.key != myProfileId)
            .map((e) => e.value)
            .where((n) => n.isNotEmpty)
            .toList();
        if (otherNames.isNotEmpty) {
          dmName = otherNames.join(', ');
        }
      }

      return DmItem(
        id: c.id,
        name: dmName,
        isOnline: false,
        unreadCount: unreadCounts[c.id] ?? 0,
      );
    }).toList();
  }

  String? get _selectedChannelId {
    return ref.watch(selectedChannelProvider)?.id;
  }

  // ---------------------------------------------------------------------------
  // Desktop: TeamRail + ChannelSidebar + content
  // ---------------------------------------------------------------------------
  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          TeamRail(
            teams: _mockTeamsFromProviders,
            selectedIndex: _selectedTeamIndex,
            onTeamSelected: _onTeamSelected,
            onAddTeam: _showCreateTeamDialog,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 0 : MsgrDimensions.sidebarWidth,
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: _sidebarCollapsed
                ? const SizedBox.shrink()
                : _buildSidebar(),
          ),
          Container(width: 1, color: MsgrTheme.of(context).contentBorder),
          Expanded(
            child: Container(
              color: MsgrTheme.of(context).contentBg,
              child: Column(
                children: [
                  if (kIsWeb) _WebPushBanner(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet: ChannelSidebar + content, team rail in a Drawer
  // ---------------------------------------------------------------------------
  Widget _buildTablet() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        width: MsgrDimensions.teamRailWidth + MsgrDimensions.sidebarWidth,
        child: Row(
          children: [
            TeamRail(
              teams: _mockTeamsFromProviders,
              selectedIndex: _selectedTeamIndex,
              onTeamSelected: (index) {
                _onTeamSelected(index);
                Navigator.of(context).pop(); // close drawer
              },
              onAddTeam: _showCreateTeamDialog,
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                if (kIsWeb) _WebPushBanner(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile: content only (team/channel via navigation)
  // ---------------------------------------------------------------------------
  Widget _buildMobile() {
    final teamName = _activeTeam?.name ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Row(
          children: [
            TeamRail(
              teams: _mockTeamsFromProviders,
              selectedIndex: _selectedTeamIndex,
              onTeamSelected: (index) {
                _onTeamSelected(index);
              },
              onAddTeam: _showCreateTeamDialog,
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          teamName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: MsgrTheme.of(context).sidebarBg,
        foregroundColor: MsgrTheme.of(context).sidebarTextBright,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          if (kIsWeb) _WebPushBanner(),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared sidebar builder
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    final teamName = _activeTeam?.name ?? '';
    return ChannelSidebar(
      teamName: teamName,
      channels: _mockChannelsFromProviders,
      dmContacts: _mockDmsFromProviders,
      selectedChannelId: _selectedChannelId,
      selectedDmId: null, // DMs share the selectedChannelProvider
      onChannelSelected: (channel) {
        _onChannelSelected(channel.id);
      },
      onDmSelected: (dm) {
        _onDmSelected(dm.id);
      },
      onCreateChannel: _showCreateChannelDialog,
      onOpenSettings: () => openSettingsPage(context),
      userDisplayName: ref.watch(simpleAuthProvider).displayName,
      userEmail: ref.watch(simpleAuthProvider).email,
      userProfileId: ref.watch(simpleAuthProvider).profileId,
      onAvatarTap: () {
        final team = ref.read(selectedTeamProvider);
        if (team != null) {
          showAvatarUploadDialog(context, teamSlug: team.slug, currentAvatarUrl: null);
        }
      },
      onEditProfile: () {
        final team = ref.read(selectedTeamProvider);
        if (team != null) _showProfileSetupDialog(team.slug);
      },
      onInvitePeople: _showInviteDialog,
      onLogout: () => ref.read(simpleAuthProvider.notifier).logout(),
    );
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------
  void _onTeamSelected(int index) {
    final teams = ref.read(teamsProvider);
    if (index >= 0 && index < teams.length) {
      ref.read(selectedTeamProvider.notifier).select(teams[index]);
      ref.read(selectedChannelProvider.notifier).clear();
      // Check if the new team needs profile setup
      Future.microtask(() => _checkProfileSetup());
    }
  }

  void _onChannelSelected(String channelId) {
    final channels = ref.read(channelListProvider).channels;
    final channel = channels.where((c) => c.id == channelId).firstOrNull;
    if (channel != null) {
      ref.read(selectedChannelProvider.notifier).select(channel);
      ref.read(unreadCountsProvider.notifier).markRead(channelId);
    }
  }

  void _onDmSelected(String dmId) {
    _onChannelSelected(dmId);
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    bool autoSlug = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3E),
              title: const Text(
                'Opprett team',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Teamnavn',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        hintText: 'F.eks. Min bedrift',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        if (autoSlug) {
                          slugController.text = _nameToSlug(value);
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: slugController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Slug (URL-vennlig)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        hintText: 'min-bedrift',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) {
                        autoSlug = false;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Avbryt', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF02ac88),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Opprett'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final slug = slugController.text.trim();
      if (name.isNotEmpty && slug.isNotEmpty) {
        await ref.read(teamListProvider.notifier).createTeam(name, slug);
        // Show profile setup dialog before entering the team
        if (mounted) {
          await _showProfileSetupDialog(slug);
        }
        // Auto-select the newly created team via microtask to avoid
        // _dependents.isEmpty assertion.
        Future.microtask(() {
          if (!mounted) return;
          final teams = ref.read(teamsProvider);
          if (teams.isNotEmpty) {
            final newTeam = teams.lastWhere(
              (t) => t.slug == slug,
              orElse: () => teams.last,
            );
            ref.read(selectedTeamProvider.notifier).select(newTeam);
            ref.read(selectedChannelProvider.notifier).clear();
          }
        });
      }
    }

    nameController.dispose();
    slugController.dispose();
  }

  Future<void> _showJoinTeamDialog() async {
    final slugController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Bli med i team',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: slugController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Team-slug',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                hintText: 'F.eks. min-bedrift',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Avbryt', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF02ac88),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bli med'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      final slug = slugController.text.trim();
      if (slug.isNotEmpty) {
        await ref.read(teamListProvider.notifier).joinTeam(slug);
        // Show profile setup dialog before entering the team
        if (mounted) {
          await _showProfileSetupDialog(slug);
        }
        // Auto-select the joined team via microtask to avoid
        // _dependents.isEmpty assertion.
        Future.microtask(() {
          if (!mounted) return;
          final teams = ref.read(teamsProvider);
          if (teams.isNotEmpty) {
            final joinedTeam = teams.lastWhere(
              (t) => t.slug == slug,
              orElse: () => teams.last,
            );
            ref.read(selectedTeamProvider.notifier).select(joinedTeam);
            ref.read(selectedChannelProvider.notifier).clear();
          }
        });
      }
    }

    slugController.dispose();
  }

  Future<void> _showProfileSetupDialog(String teamSlug) async {
    final auth = ref.read(simpleAuthProvider);
    final nameController = TextEditingController(text: auth.displayName ?? '');
    final emailController = TextEditingController(text: auth.email ?? '');
    final phoneController = TextEditingController();
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3E),
              title: const Text(
                'Sett opp profilen din',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Visningsnavn',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'E-post (valgfri)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Telefon (valgfri)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF02ac88),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final client = ref.read(msgrApiProvider);
                            final displayName = nameController.text.trim();
                            final email = emailController.text.trim();
                            final phone = phoneController.text.trim();
                            await client.updateMyProfile(
                              teamSlug,
                              displayName: displayName.isNotEmpty ? displayName : null,
                              email: email.isNotEmpty ? email : null,
                              phone: phone.isNotEmpty ? phone : null,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            // Profile update failed -- still allow entry
                            if (context.mounted) {
                              Navigator.of(context).pop(false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lagre profil'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _showInviteDialog() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    final client = ref.read(msgrApiProvider);
    String? inviteUrl;
    String? error;
    bool loading = true;

    // Generate invite link immediately
    try {
      final result = await client.createInviteLink(team.slug);
      final data = result['data'] ?? result;
      inviteUrl = data['url'] as String?;
    } catch (e) {
      error = e.toString();
    }
    loading = false;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Invite people',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share this link to invite people to ${team.name}:',
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 13))
                else if (inviteUrl != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            inviteUrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _InviteCopyButton(url: inviteUrl),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Link expires in 7 days.',
                  style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateChannelDialog() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    final nameController = TextEditingController();
    final iconController = TextEditingController();
    final searchController = TextEditingController();
    bool isPrivate = false;
    List<Map<String, dynamic>> allProfiles = [];
    Set<String> selectedMemberIds = {};
    String searchQuery = '';
    bool loadingProfiles = true;

    // Load team members via libmsgr
    final client = ref.read(msgrApiProvider);
    try {
      allProfiles = await client.getProfiles(team.slug);
    } catch (_) {
      // If loading profiles fails, continue without member selection
    }
    loadingProfiles = false;

    // Current user's profile id
    final currentProfileId = client.profileId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredProfiles = allProfiles.where((p) {
              if (searchQuery.isEmpty) return true;
              final name = (p['display_name'] ?? p['email'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3E),
              title: const Text(
                'Opprett kanal',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Channel name
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Kanalnavn',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          hintText: 'F.eks. general',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Icon field
                      TextField(
                        controller: iconController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ikon (emoji, valgfritt)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          hintText: '#',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Visibility toggle
                      Text(
                        'Synlighet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isPrivate = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isPrivate
                                      ? const Color(0xFF02ac88).withOpacity(0.2)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !isPrivate
                                        ? const Color(0xFF02ac88)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.public,
                                      color: !isPrivate
                                          ? const Color(0xFF02ac88)
                                          : Colors.white54,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Offentlig',
                                      style: TextStyle(
                                        color: !isPrivate ? Colors.white : Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isPrivate = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isPrivate
                                      ? const Color(0xFF02ac88).withOpacity(0.2)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPrivate
                                        ? const Color(0xFF02ac88)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: isPrivate
                                          ? const Color(0xFF02ac88)
                                          : Colors.white54,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Privat',
                                      style: TextStyle(
                                        color: isPrivate ? Colors.white : Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Member selection section
                      Text(
                        'Inviter medlemmer',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Selected members chips
                      if (selectedMemberIds.isNotEmpty || currentProfileId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // Creator chip (not removable)
                              if (currentProfileId != null)
                                _buildMemberChip(
                                  allProfiles,
                                  currentProfileId,
                                  isCreator: true,
                                  onRemove: null,
                                ),
                              // Selected members (removable)
                              ...selectedMemberIds
                                  .where((id) => id != currentProfileId)
                                  .map((id) => _buildMemberChip(
                                        allProfiles,
                                        id,
                                        isCreator: false,
                                        onRemove: () => setDialogState(() {
                                          selectedMemberIds.remove(id);
                                        }),
                                      )),
                            ],
                          ),
                        ),

                      // Search field
                      TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Sok etter medlemmer...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3), size: 18),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setDialogState(() => searchQuery = value);
                        },
                      ),
                      const SizedBox(height: 8),

                      // Profile list
                      if (loadingProfiles)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredProfiles.length,
                            itemBuilder: (context, index) {
                              final profile = filteredProfiles[index];
                              final profileId = profile['id']?.toString() ?? '';
                              final isCreator = profileId == currentProfileId;
                              final isSelected = selectedMemberIds.contains(profileId) || isCreator;
                              final displayName = profile['display_name']?.toString() ?? profile['email']?.toString() ?? 'Ukjent';

                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF3A3A5E),
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                title: Text(
                                  displayName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                subtitle: isCreator
                                    ? Text(
                                        'Oppretter',
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                      )
                                    : null,
                                trailing: isCreator
                                    ? Icon(Icons.check_circle, color: const Color(0xFF02ac88).withOpacity(0.5), size: 18)
                                    : isSelected
                                        ? const Icon(Icons.check_circle, color: Color(0xFF02ac88), size: 18)
                                        : Icon(Icons.circle_outlined, color: Colors.white.withOpacity(0.2), size: 18),
                                onTap: isCreator
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          if (selectedMemberIds.contains(profileId)) {
                                            selectedMemberIds.remove(profileId);
                                          } else {
                                            selectedMemberIds.add(profileId);
                                          }
                                        });
                                      },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Avbryt', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF02ac88),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Opprett'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        final icon = iconController.text.trim();
        final visibility = isPrivate ? 'private' : 'public';
        final memberIds = selectedMemberIds.isNotEmpty
            ? selectedMemberIds.toList()
            : null;
        await ref.read(channelListProvider.notifier).createChannel(
              teamSlug: team.slug,
              name: name,
              icon: icon.isNotEmpty ? icon : null,
              visibility: visibility,
              memberIds: memberIds,
            );
        // Refresh from server to ensure sidebar is in sync (the local
        // optimistic add may lack fields like kind, which causes the
        // channel to be filtered out of publicChannels).
        await ref.read(channelListProvider.notifier).refresh();
        // Auto-select newly created channel after microtask to avoid
        // _dependents.isEmpty assertion from modifying state during build.
        Future.microtask(() {
          if (!mounted) return;
          final channels = ref.read(channelListProvider).channels;
          if (channels.isNotEmpty) {
            final newChannel = channels.last;
            ref.read(selectedChannelProvider.notifier).select(newChannel);
          }
        });
      }
    }

    nameController.dispose();
    iconController.dispose();
    searchController.dispose();
  }

  Widget _buildMemberChip(
    List<Map<String, dynamic>> profiles,
    String profileId, {
    required bool isCreator,
    VoidCallback? onRemove,
  }) {
    final profile = profiles.where((p) => p['id']?.toString() == profileId).firstOrNull;
    final name = profile?['display_name']?.toString() ?? profile?['email']?.toString() ?? 'Ukjent';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCreator
            ? const Color(0xFF02ac88).withOpacity(0.15)
            : const Color(0xFF3A3A5E),
        borderRadius: BorderRadius.circular(16),
        border: isCreator
            ? Border.all(color: const Color(0xFF02ac88).withOpacity(0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (isCreator) ...[
            const SizedBox(width: 4),
            Icon(Icons.star, size: 12, color: const Color(0xFF02ac88).withOpacity(0.7)),
          ],
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 14, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  static String _nameToSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

// ---------------------------------------------------------------------------
// Welcome screen (no teams)
// ---------------------------------------------------------------------------

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
    this.error,
    required this.onCreateTeam,
    required this.onJoinTeam,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onCreateTeam;
  final VoidCallback onJoinTeam;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Color(0xFF02ac88),
              ),
              const SizedBox(height: 24),
              const Text(
                'Velkommen til Messngr!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Opprett et nytt team eller bli med i et eksisterende.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error.toString(),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreateTeam,
                  icon: const Icon(Icons.add),
                  label: const Text('Opprett team'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF02ac88),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onJoinTeam,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Bli med i team'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Last inn paa nytt',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful copy button that shows a checkmark after copying.
class _InviteCopyButton extends StatefulWidget {
  const _InviteCopyButton({required this.url});
  final String url;

  @override
  State<_InviteCopyButton> createState() => _InviteCopyButtonState();
}

class _InviteCopyButtonState extends State<_InviteCopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _copied ? Icons.check : Icons.copy,
        color: _copied ? Colors.greenAccent : Colors.white70,
        size: 18,
      ),
      tooltip: _copied ? 'Copied!' : 'Copy',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.url));
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
    );
  }
}

/// Banner that asks web users to enable push notifications.
/// Dismisses after subscription or manual close.
class _WebPushBanner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WebPushBanner> createState() => _WebPushBannerState();
}

class _WebPushBannerState extends ConsumerState<_WebPushBanner> {
  bool _dismissed = false;
  bool _subscribing = false;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('web_push_banner_dismissed') == true) {
        if (mounted) setState(() => _dismissed = true);
      }
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('web_push_banner_dismissed', true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    // Don't show if notifications already granted
    if (webPushImpl.isNotificationGranted()) return const SizedBox.shrink();

    final manager = ref.read(webPushManagerProvider);
    if (!manager.isAvailable) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1D4E3E),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Enable desktop notifications to stay updated',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _subscribing
                ? null
                : () async {
                    setState(() => _subscribing = true);
                    await manager.subscribe();
                    if (mounted) {
                      setState(() => _subscribing = false);
                      await _dismiss();
                    }
                  },
            child: _subscribing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 16),
            onPressed: () => _dismiss(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}
