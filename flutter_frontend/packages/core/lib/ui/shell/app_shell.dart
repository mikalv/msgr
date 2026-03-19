import 'package:flutter/material.dart';

import 'channel_sidebar.dart';
import 'mock_data.dart';
import 'shell_models.dart';
import 'shell_theme.dart';
import 'team_rail.dart';

/// Main responsive app shell wrapping the chat content area.
///
/// Layout strategy:
///   - Desktop (> 1024 px): `[TeamRail | ChannelSidebar | child]`
///   - Tablet  (600-1024 px): `[ChannelSidebar | child]` with a [Drawer] for
///     the team rail.
///   - Mobile  (< 600 px): Only [child] is shown; team and channel selection
///     happens through full-screen navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  /// The chat content area that fills the remaining space.
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTeamIndex = 0;
  String? _selectedChannelId;
  String? _selectedDmId;
  bool _sidebarCollapsed = false;

  MockTeam get _activeTeam => mockTeams[_selectedTeamIndex];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop: TeamRail + ChannelSidebar + content
  // ---------------------------------------------------------------------------
  Widget _buildDesktop() {
    return Row(
      children: [
        TeamRail(
          teams: mockTeams,
          selectedIndex: _selectedTeamIndex,
          onTeamSelected: _onTeamSelected,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebarCollapsed ? 0 : ShellTheme.sidebarWidth,
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: _sidebarCollapsed
              ? const SizedBox.shrink()
              : _buildSidebar(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet: ChannelSidebar + content, team rail in a Drawer
  // ---------------------------------------------------------------------------
  Widget _buildTablet() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        width: ShellTheme.teamRailWidth + ShellTheme.sidebarWidth,
        child: Row(
          children: [
            TeamRail(
              teams: mockTeams,
              selectedIndex: _selectedTeamIndex,
              onTeamSelected: (index) {
                _onTeamSelected(index);
                Navigator.of(context).pop(); // close drawer
              },
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile: content only (team/channel via navigation)
  // ---------------------------------------------------------------------------
  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Row(
          children: [
            TeamRail(
              teams: mockTeams,
              selectedIndex: _selectedTeamIndex,
              onTeamSelected: (index) {
                _onTeamSelected(index);
              },
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          _activeTeam.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: ShellTheme.sidebarBg,
        foregroundColor: ShellTheme.sidebarTextBright,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: widget.child,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared sidebar builder
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    return ChannelSidebar(
      teamName: _activeTeam.name,
      channels: mockChannels,
      dmContacts: mockDmContacts,
      selectedChannelId: _selectedChannelId,
      selectedDmId: _selectedDmId,
      onChannelSelected: (channel) {
        setState(() {
          _selectedChannelId = channel.id;
          _selectedDmId = null;
        });
      },
      onDmSelected: (dm) {
        setState(() {
          _selectedDmId = dm.id;
          _selectedChannelId = null;
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------
  void _onTeamSelected(int index) {
    setState(() {
      _selectedTeamIndex = index;
      _selectedChannelId = null;
      _selectedDmId = null;
    });
  }
}
