import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/team_list_provider.dart';
import 'package:core/ui/shell/member_panel.dart';

/// Right-side panel for channel settings: Overview, Members, Webhooks.
class ChannelSettingsPanel extends ConsumerStatefulWidget {
  const ChannelSettingsPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<ChannelSettingsPanel> createState() => _ChannelSettingsPanelState();
}

class _ChannelSettingsPanelState extends ConsumerState<ChannelSettingsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(selectedChannelProvider);
    if (channel == null) return const SizedBox.shrink();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '# ${channel.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorColor: const Color(0xFF007A5A),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Members'),
              Tab(text: 'Webhooks'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(channel: channel),
                _MembersTab(),
                _WebhooksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview Tab
// ---------------------------------------------------------------------------

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.channel});
  final SlackChannel channel;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  late TextEditingController _topicController;
  bool _savingTopic = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.channel.topic ?? '');
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Channel name'),
        _value('# ${ch.name}'),
        const SizedBox(height: 16),

        _label('Visibility'),
        _value(ch.visibility == ChannelVisibility.private ? '🔒 Private' : '🌍 Public'),
        const SizedBox(height: 16),

        _label('Topic'),
        TextField(
          controller: _topicController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Set a topic...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _savingTopic ? null : _saveTopic,
            child: _savingTopic
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save topic', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Future<void> _saveTopic() async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    setState(() => _savingTopic = true);
    try {
      final client = ref.read(msgrApiProvider);
      // TODO: add updateChannelTopic API method
      await client.post('/api/teams/${team.slug}/channels/${channel.id}/topic', body: {
        'topic': _topicController.text.trim(),
      });
    } catch (_) {}
    if (mounted) setState(() => _savingTopic = false);
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  Widget _value(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      );
}

// ---------------------------------------------------------------------------
// Members Tab (reuses MemberPanel logic)
// ---------------------------------------------------------------------------

class _MembersTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  List<Map<String, dynamic>>? _members;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    setState(() => _loading = true);
    try {
      final client = ref.read(msgrApiProvider);
      final members = await client.getChannelMembers(team.slug, channel.id);
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    final client = ref.read(msgrApiProvider);
    final allProfiles = await client.getProfiles(team.slug);
    final currentIds = (_members ?? []).map((m) => m['profile_id'] as String?).whereType<String>().toSet();
    final available = allProfiles.where((p) => !currentIds.contains(p['id']?.toString())).toList();

    if (available.isEmpty || !mounted) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _QuickAddMemberDialog(available: available),
    );

    if (selected != null && selected.isNotEmpty) {
      await client.addChannelMembers(team.slug, channel.id, selected);
      _loadMembers();
    }
  }

  Future<void> _removeMember(String profileId, String name) async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Remove member', style: TextStyle(color: Colors.white)),
        content: Text('Remove $name?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(msgrApiProvider).removeChannelMember(team.slug, channel.id, profileId);
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(simpleAuthProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text('${_members?.length ?? 0} members', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                onPressed: _addMember,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.builder(
                  itemCount: _members?.length ?? 0,
                  itemBuilder: (ctx, i) {
                    final m = _members![i];
                    final pid = m['profile_id'] as String? ?? '';
                    final name = m['display_name'] as String? ?? '';
                    final role = m['role'] as String? ?? 'member';
                    final isMe = pid == auth.profileId;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blueGrey.shade600,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Row(
                        children: [
                          Text(name + (isMe ? ' (you)' : ''), style: const TextStyle(color: Colors.white, fontSize: 13)),
                          if (role == 'admin') ...[
                            const SizedBox(width: 4),
                            Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                          ],
                        ],
                      ),
                      trailing: isMe ? null : IconButton(
                        icon: Icon(Icons.close, size: 14, color: Colors.white.withValues(alpha: 0.3)),
                        onPressed: () => _removeMember(pid, name),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _QuickAddMemberDialog extends StatefulWidget {
  const _QuickAddMemberDialog({required this.available});
  final List<Map<String, dynamic>> available;

  @override
  State<_QuickAddMemberDialog> createState() => _QuickAddMemberDialogState();
}

class _QuickAddMemberDialogState extends State<_QuickAddMemberDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3E),
      title: const Text('Add members', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 280,
        height: 300,
        child: ListView.builder(
          itemCount: widget.available.length,
          itemBuilder: (ctx, i) {
            final p = widget.available[i];
            final id = p['id']?.toString() ?? '';
            final name = p['display_name']?.toString() ?? '';
            final sel = _selected.contains(id);
            return ListTile(
              dense: true,
              title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              trailing: Icon(sel ? Icons.check_circle : Icons.circle_outlined,
                  size: 20, color: sel ? Colors.greenAccent : Colors.white24),
              onTap: () => setState(() => sel ? _selected.remove(id) : _selected.add(id)),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A5A)),
          child: Text('Add (${_selected.length})'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Webhooks Tab
// ---------------------------------------------------------------------------

class _WebhooksTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WebhooksTab> createState() => _WebhooksTabState();
}

class _WebhooksTabState extends ConsumerState<_WebhooksTab> {
  List<Map<String, dynamic>>? _webhooks;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
  }

  Future<void> _loadWebhooks() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    setState(() => _loading = true);
    try {
      final client = ref.read(msgrApiProvider);
      final all = await client.getWebhooks(team.slug);
      final channel = ref.read(selectedChannelProvider);
      // Filter to current channel
      final filtered = channel != null
          ? all.where((w) => w['channel_id'] == channel.id).toList()
          : all;
      if (mounted) setState(() { _webhooks = filtered; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createWebhook() async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Create webhook', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Webhook name',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            hintText: 'e.g. GitHub, CI/CD',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A5A)),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    nameController.dispose();
    if (result == null || result.isEmpty) return;

    try {
      final client = ref.read(msgrApiProvider);
      await client.createWebhook(team.slug, channelId: channel.id, name: result);
      _loadWebhooks();
    } catch (_) {}
  }

  Future<void> _deleteWebhook(String id, String name) async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Delete webhook', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$name"? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(msgrApiProvider).deleteWebhook(team.slug, id);
      _loadWebhooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text('Incoming webhooks', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create', style: TextStyle(fontSize: 12)),
                onPressed: _createWebhook,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _webhooks == null || _webhooks!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.webhook, size: 32, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 8),
                          Text('No webhooks yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Create one to receive messages from external services',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _webhooks!.length,
                      itemBuilder: (ctx, i) {
                        final w = _webhooks![i];
                        final id = w['id']?.toString() ?? '';
                        final name = w['name']?.toString() ?? 'Webhook';
                        final url = w['url']?.toString() ?? '';
                        final count = w['message_count'] ?? 0;

                        return Card(
                          color: const Color(0xFF333344),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                                      onPressed: () => _deleteWebhook(id, name),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(url, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'monospace'),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: url));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('URL copied'), duration: Duration(seconds: 2)),
                                        );
                                      },
                                      child: Icon(Icons.copy, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('$count messages received', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
