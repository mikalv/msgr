import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/CategorySelector.dart';
import 'package:messngr/features/chat/chat_page.dart';
import 'package:messngr/ui/widgets/conversation/conversations_list_widget.dart';
import 'package:messngr/ui/widgets/profile/profile_mode_switcher.dart';
import 'package:messngr/ui/widgets/room/room_list_widget.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:redux/redux.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static const double _tabletBreakpoint = 900;
  static const double _desktopBreakpoint = 1280;

  final List<String> _categories = const [
    'Direkte',
    'Teamkanaler',
    'Favoritter',
    'Arkiv',
  ];

  int _selectedCategory = 0;
  ProfileMode? _activeModeFilter;

  void _handleCategoryChanged(int index) {
    if (_selectedCategory != index) {
      setState(() {
        _selectedCategory = index;
      });
    }
  }

  void _openSettings(Store<AppState> store) {
    store.dispatch(
      NavigateShellToNewRouteAction(route: AppNavigation.settingsPath),
    );
  }

  void _openInvite(Store<AppState> store) {
    store.dispatch(
      NavigateShellToNewRouteAction(route: AppNavigation.inviteMemberPath),
    );
  }

  void _createRoom(Store<AppState> store) {
    final teamName = store.state.authState.currentTeamName;
    if (teamName == null) {
      return;
    }
    store.dispatch(NavigateShellToNewRouteAction(
        route: AppNavigation.createRoomPath + teamName, kUsePush: true));
  }

  void _createConversation(Store<AppState> store) {
    final teamName = store.state.authState.currentTeamName;
    if (teamName == null) {
      return;
    }
    store.dispatch(NavigateShellToNewRouteAction(
        route: AppNavigation.createConversationPath + teamName,
        kUsePush: true));
  }

  void _openDrawer() {
    Scaffold.maybeOf(context)?.openDrawer();
  }

  void _handleInboxFilterChanged(ProfileMode? mode) {
    if (_activeModeFilter == mode) {
      return;
    }
    setState(() {
      _activeModeFilter = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _HomeDesktopLayout(
            store: store,
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _handleCategoryChanged,
            onInvite: () => _openInvite(store),
            onSettings: () => _openSettings(store),
            onCreateRoom: () => _createRoom(store),
            onCreateConversation: () => _createConversation(store),
            onOpenDrawer: _openDrawer,
            modeFilter: _activeModeFilter,
            onModeFilterChanged: _handleInboxFilterChanged,
          );
        }

        if (constraints.maxWidth >= _tabletBreakpoint) {
          return _HomeTabletLayout(
            store: store,
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _handleCategoryChanged,
            onInvite: () => _openInvite(store),
            onSettings: () => _openSettings(store),
            onCreateRoom: () => _createRoom(store),
            onCreateConversation: () => _createConversation(store),
            onOpenDrawer: _openDrawer,
            modeFilter: _activeModeFilter,
            onModeFilterChanged: _handleInboxFilterChanged,
          );
        }

        return _HomeCompactLayout(
          store: store,
          categories: _categories,
          selectedCategory: _selectedCategory,
          onCategorySelected: _handleCategoryChanged,
          onInvite: () => _openInvite(store),
          onSettings: () => _openSettings(store),
          onCreateRoom: () => _createRoom(store),
          onCreateConversation: () => _createConversation(store),
          onOpenDrawer: _openDrawer,
          modeFilter: _activeModeFilter,
          onModeFilterChanged: _handleInboxFilterChanged,
        );
      },
    );
  }
}

class _HomeCompactLayout extends StatelessWidget {
  const _HomeCompactLayout({
    required this.store,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onInvite,
    required this.onSettings,
    required this.onCreateRoom,
    required this.onCreateConversation,
    required this.onOpenDrawer,
    required this.modeFilter,
    required this.onModeFilterChanged,
  });

  final Store<AppState> store;
  final List<String> categories;
  final int selectedCategory;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback onInvite;
  final VoidCallback onSettings;
  final VoidCallback onCreateRoom;
  final VoidCallback onCreateConversation;
  final VoidCallback onOpenDrawer;
  final ProfileMode? modeFilter;
  final ValueChanged<ProfileMode?> onModeFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('home_compact_layout'),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      child: Column(
        children: [
          CategorySelector(
            categories: categories,
            initialIndex: selectedCategory,
            onCategorySelected: onCategorySelected,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _HomeActionStrip(
                    onSettings: onSettings,
                    onInvite: onInvite,
                    onCreateRoom: onCreateRoom,
                    onCreateConversation: onCreateConversation,
                    onOpenDrawer: onOpenDrawer,
                  ),
                  const SizedBox(height: 16),
                  ProfileModeSwitcher(
                    onFilterChanged: onModeFilterChanged,
                    initialFilter: modeFilter,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _HomeChatPanel(compact: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTabletLayout extends StatelessWidget {
  const _HomeTabletLayout({
    required this.store,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onInvite,
    required this.onSettings,
    required this.onCreateRoom,
    required this.onCreateConversation,
    required this.onOpenDrawer,
    required this.modeFilter,
    required this.onModeFilterChanged,
  });

  final Store<AppState> store;
  final List<String> categories;
  final int selectedCategory;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback onInvite;
  final VoidCallback onSettings;
  final VoidCallback onCreateRoom;
  final VoidCallback onCreateConversation;
  final VoidCallback onOpenDrawer;
  final ProfileMode? modeFilter;
  final ValueChanged<ProfileMode?> onModeFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('home_medium_layout'),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 340,
                  child: _HomeInboxPanel(
                    store: store,
                    categories: categories,
                    selectedCategory: selectedCategory,
                    onCategorySelected: onCategorySelected,
                    onCreateConversation: onCreateConversation,
                    onCreateRoom: onCreateRoom,
                    modeFilter: modeFilter,
                    onFilterChanged: onModeFilterChanged,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeActionStrip(
                        onSettings: onSettings,
                        onInvite: onInvite,
                        onCreateRoom: onCreateRoom,
                        onCreateConversation: onCreateConversation,
                        onOpenDrawer: onOpenDrawer,
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _HomeChatPanel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDesktopLayout extends StatelessWidget {
  const _HomeDesktopLayout({
    required this.store,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onInvite,
    required this.onSettings,
    required this.onCreateRoom,
    required this.onCreateConversation,
    required this.onOpenDrawer,
    required this.modeFilter,
    required this.onModeFilterChanged,
  });

  final Store<AppState> store;
  final List<String> categories;
  final int selectedCategory;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback onInvite;
  final VoidCallback onSettings;
  final VoidCallback onCreateRoom;
  final VoidCallback onCreateConversation;
  final VoidCallback onOpenDrawer;
  final ProfileMode? modeFilter;
  final ValueChanged<ProfileMode?> onModeFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('home_large_layout'),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HomeSidebar(
                  categories: categories,
                  selectedCategory: selectedCategory,
                  onCategorySelected: onCategorySelected,
                  onCreateConversation: onCreateConversation,
                  onInvite: onInvite,
                  onSettings: onSettings,
                ),
                const SizedBox(width: 28),
                SizedBox(
                  width: 360,
                  child: _HomeInboxPanel(
                    store: store,
                    onCreateConversation: onCreateConversation,
                    onCreateRoom: onCreateRoom,
                    modeFilter: modeFilter,
                    onFilterChanged: onModeFilterChanged,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeActionStrip(
                        onSettings: onSettings,
                        onInvite: onInvite,
                        onCreateRoom: onCreateRoom,
                        onCreateConversation: onCreateConversation,
                        dense: true,
                        onOpenDrawer: onOpenDrawer,
                      ),
                      const SizedBox(height: 18),
                      Expanded(child: _HomeChatPanel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSidebar extends StatelessWidget {
  const _HomeSidebar({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onCreateConversation,
    required this.onInvite,
    required this.onSettings,
  });

  final List<String> categories;
  final int selectedCategory;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback onCreateConversation;
  final VoidCallback onInvite;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('home_large_sidebar'),
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.32),
            blurRadius: 42,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Messngr',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Snakk sammen, hvor som helst',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.76),
            ),
          ),
          const SizedBox(height: 32),
          CategorySelector(
            categories: categories,
            initialIndex: selectedCategory,
            onCategorySelected: onCategorySelected,
            scrollDirection: Axis.vertical,
            backgroundColor: Colors.transparent,
          ),
          const Spacer(),
          _SidebarButton(
            icon: Icons.add_comment_rounded,
            label: 'Ny chat',
            onPressed: onCreateConversation,
          ),
          const SizedBox(height: 12),
          _SidebarButton(
            icon: Icons.group_add_rounded,
            label: 'Inviter',
            onPressed: onInvite,
          ),
          const SizedBox(height: 12),
          _SidebarButton(
            icon: Icons.settings_outlined,
            label: 'Innstillinger',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _HomeInboxPanel extends StatelessWidget {
  const _HomeInboxPanel({
    required this.store,
    required this.onCreateConversation,
    required this.onCreateRoom,
    this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    required this.modeFilter,
    required this.onFilterChanged,
  });

  final Store<AppState> store;
  final VoidCallback onCreateConversation;
  final VoidCallback onCreateRoom;
  final List<String>? categories;
  final int? selectedCategory;
  final ValueChanged<int>? onCategorySelected;
  final ProfileMode? modeFilter;
  final ValueChanged<ProfileMode?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('home_inbox_panel'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Innboks',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onCreateConversation,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Ny'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Søk i samtaler',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 16),
          ProfileModeSwitcher(
            onFilterChanged: onFilterChanged,
            initialFilter: modeFilter,
          ),
          if (categories != null &&
              selectedCategory != null &&
              onCategorySelected != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < categories!.length; i++)
                  ChoiceChip(
                    label: Text(categories![i]),
                    selected: selectedCategory == i,
                    onSelected: (_) => onCategorySelected!(i),
                    selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: selectedCategory == i
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    backgroundColor:
                        theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(overscroll: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RoomListWidget(
                      context: context,
                      rooms: store.state.teamState?.rooms ?? [],
                      store: store,
                    ),
                    const SizedBox(height: 24),
                    ConversationsListWidget(
                      context: context,
                      conversations: store.state.teamState?.conversations ?? [],
                      store: store,
                      modeFilter: modeFilter,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCreateRoom,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Nytt rom'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionStrip extends StatelessWidget {
  const _HomeActionStrip({
    required this.onSettings,
    required this.onInvite,
    required this.onCreateRoom,
    required this.onCreateConversation,
    required this.onOpenDrawer,
    this.dense = false,
  });

  final VoidCallback onSettings;
  final VoidCallback onInvite;
  final VoidCallback onCreateRoom;
  final VoidCallback onCreateConversation;
  final VoidCallback onOpenDrawer;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final buttonPadding = dense
        ? const EdgeInsets.symmetric(horizontal: 14)
        : const EdgeInsets.symmetric(horizontal: 18);

    return Container(
      key: dense
          ? const Key('home_action_strip_dense')
          : const Key('home_action_strip'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        spacing: 8,
        children: [
          _ActionChip(
            icon: Icons.menu_rounded,
            label: 'Meny',
            onPressed: onOpenDrawer,
            padding: buttonPadding,
          ),
          _ActionChip(
            icon: Icons.settings_outlined,
            label: 'Innstillinger',
            onPressed: onSettings,
            padding: buttonPadding,
          ),
          _ActionChip(
            icon: Icons.group_add_rounded,
            label: 'Inviter',
            onPressed: onInvite,
            padding: buttonPadding,
          ),
          _ActionChip(
            icon: Icons.meeting_room_outlined,
            label: 'Nytt rom',
            onPressed: onCreateRoom,
            padding: buttonPadding,
          ),
          _ActionChip(
            icon: Icons.chat_rounded,
            label: 'Ny samtale',
            onPressed: onCreateConversation,
            padding: buttonPadding,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.padding,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: padding,
        elevation: 0,
        backgroundColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.08),
        foregroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HomeChatPanel extends StatelessWidget {
  const _HomeChatPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(compact ? 24 : 36);

    return Container(
      key: compact
          ? const Key('home_chat_panel_compact')
          : const Key('home_chat_panel'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: borderRadius,
        boxShadow: compact
            ? []
            : [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 24),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: const ChatPage(),
      ),
    );
  }
}
