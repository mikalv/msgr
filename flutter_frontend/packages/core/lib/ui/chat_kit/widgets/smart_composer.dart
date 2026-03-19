import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/draft_provider.dart';
import 'package:core/providers/messages_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/team_list_provider.dart';

import 'message_status_indicator.dart';
import 'outgoing_queue_indicator.dart';

/// Wrapper around [ChatComposer] that integrates draft persistence and
/// delivery-state awareness.
///
/// Features:
/// - Auto-saves draft text on change (debounced 500 ms)
/// - Restores draft when channel is selected
/// - Clears draft on send
/// - Shows delivery status of last sent message
/// - Shows outgoing queue count above composer
class SmartComposer extends ConsumerStatefulWidget {
  const SmartComposer({
    super.key,
    this.pendingCount = 0,
  });

  /// Number of messages queued for sending (shown above the composer).
  final int pendingCount;

  @override
  ConsumerState<SmartComposer> createState() => _SmartComposerState();
}

class _SmartComposerState extends ConsumerState<SmartComposer> {
  late final ChatComposerController _controller;
  Timer? _debounce;
  String? _restoredChannelId;

  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _controller = ChatComposerController();
    _controller.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onComposerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Restore draft for the currently selected channel.
  void _restoreDraft(String channelId) {
    if (_restoredChannelId == channelId) return;
    _restoredChannelId = channelId;

    final draft = ref.read(channelDraftProvider(channelId));
    if (draft != null && draft.isNotEmpty) {
      _controller.setText(draft);
    } else {
      _controller.setText('');
    }
  }

  /// Called on every text change. Debounces the draft save.
  void _onComposerChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _persistDraft);
  }

  /// Save the current text as a draft.
  void _persistDraft() {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;

    final text = _controller.value.text;
    ref.read(channelDraftsProvider.notifier).updateDraft(channel.id, text);
  }

  /// Submit handler: send message and clear draft.
  void _onSubmit(ChatComposerResult result) {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;

    final text = result.text.trim();
    if (text.isEmpty) return;

    // Send message via the messages provider.
    ref.read(channelMessagesProvider.notifier).sendMessage(
          channel.id,
          text,
        );

    // Clear composer and draft.
    _controller.clear();
    ref.read(channelDraftsProvider.notifier).clearDraft(channel.id);
    _restoredChannelId = null;
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(selectedChannelProvider);
    final messagesState = ref.watch(channelMessagesProvider);
    final isSending =
        messagesState.messages.any((m) => m.status == MessageStatus.sending);

    // Restore draft when channel changes.
    if (channel != null) {
      _restoreDraft(channel.id);
    }

    // Find the last sent message status for the indicator.
    final lastOwnMessage = messagesState.messages
        .where((m) => m.senderProfileId == 'me')
        .toList();
    final lastStatus =
        lastOwnMessage.isNotEmpty ? lastOwnMessage.last.status : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutgoingQueueIndicator(pendingCount: widget.pendingCount),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ChatComposer(
                controller: _controller,
                onSubmit: _onSubmit,
                isSending: isSending,
              ),
            ),
            if (lastStatus != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 18, left: 4, right: 8),
                child: MessageStatusIndicator(
                  status: lastStatus,
                  size: 14,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
