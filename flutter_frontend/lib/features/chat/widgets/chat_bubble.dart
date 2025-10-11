import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';
import 'package:msgr_messages/msgr_messages.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = message.insertedAt ?? message.sentAt;
    final formattedTime = timestamp != null
        ? DateFormat.Hm().format(timestamp.toLocal())
        : '';

    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: isMine ? const Radius.circular(20) : const Radius.circular(8),
      bottomRight: isMine ? const Radius.circular(8) : const Radius.circular(20),
    );

    final background = isMine
        ? null
        : ChatTheme.otherBubbleColor(theme);

    final gradient = isMine ? ChatTheme.selfBubbleGradient(theme) : null;
    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: EdgeInsetsDirectional.only(
          start: isMine ? 80 : 8,
          end: isMine ? 8 : 80,
          top: 6,
          bottom: 6,
        ),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: gradient,
          color: background,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withOpacity(0.06)
                : background,
            borderRadius: borderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _MessageContent(
              message: message,
              isMine: isMine,
              textColor: textColor,
              formattedTime: formattedTime,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.formattedTime,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msgrMessage = message.message;

    final mediaWidget = _buildMediaAttachment(context, msgrMessage, isMine);
    final captionText = _resolveCaption(msgrMessage)?.trim();
    final bodyText = _resolveBody(msgrMessage)?.trim();

    final contentChildren = <Widget>[];

    if (!isMine) {
      contentChildren.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 8,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                message.profileName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (mediaWidget != null) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 8));
      }
      contentChildren.add(mediaWidget);
    }

    final textToShow = captionText?.isNotEmpty == true
        ? captionText
        : (bodyText?.isNotEmpty == true ? bodyText : null);

    if (textToShow != null) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 8));
      }
      contentChildren.add(
        SelectableText(
          textToShow,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: textColor,
            height: 1.4,
          ),
        ),
      );
    }

    if (contentChildren.isNotEmpty) {
      contentChildren.add(const SizedBox(height: 6));
    }

    contentChildren.add(
      _MessageMetaRow(
        formattedTime: formattedTime,
        textColor: textColor,
        isMine: isMine,
        message: message,
      ),
    );

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: contentChildren,
    );
  }

  static Widget? _buildMediaAttachment(
    BuildContext context,
    MsgrMessage message,
    bool isMine,
  ) {
    final theme = Theme.of(context);

    if (message is MsgrImageMessage) {
      final displayUrl = message.thumbnailUrl ?? message.url;
      if (displayUrl.isEmpty) return null;
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          displayUrl,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    if (message is MsgrVideoMessage) {
      return _VideoAttachmentView(video: message);
    }

    if (message is MsgrAudioMessage) {
      return _AudioAttachmentView(audio: message, isMine: isMine);
    }

    if (message is MsgrFileMessage) {
      return _FileAttachmentView(file: message, isMine: isMine);
    }

    return null;
  }

  static String? _resolveCaption(MsgrMessage message) {
    if (message is MsgrImageMessage) {
      return message.description;
    }
    if (message is MsgrVideoMessage) {
      return message.caption;
    }
    if (message is MsgrAudioMessage) {
      return message.caption;
    }
    if (message is MsgrFileMessage) {
      return message.caption;
    }
    return null;
  }

  static String? _resolveBody(MsgrMessage message) {
    if (message is MsgrTextMessage) {
      return message.body;
    }
    if (message is MsgrMarkdownMessage) {
      return message.markdown;
    }
    if (message is MsgrCodeMessage) {
      return message.code;
    }
    if (message is MsgrSystemMessage) {
      return message.text;
    }
    if (message is MsgrLocationMessage) {
      return message.label;
    }
    return null;
  }
}

class _MessageMetaRow extends StatelessWidget {
  const _MessageMetaRow({
    required this.formattedTime,
    required this.textColor,
    required this.isMine,
    required this.message,
  });

  final String formattedTime;
  final Color textColor;
  final bool isMine;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (formattedTime.isNotEmpty)
          Text(
            formattedTime,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        if (isMine) ...[
          const SizedBox(width: 6),
          _StatusIcon(message: message),
        ],
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isLocal || message.status == 'sending') {
      return SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.onPrimaryContainer.withOpacity(0.85),
          ),
        ),
      );
    }

    final color = theme.colorScheme.onPrimaryContainer;
    switch (message.status) {
      case 'sent':
        return Icon(Icons.check, size: 14, color: color);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: color);
      case 'read':
        return Icon(Icons.done_all,
            size: 14, color: color.withOpacity(0.9));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _AudioAttachmentView extends StatelessWidget {
  const _AudioAttachmentView({
    required this.audio,
    required this.isMine,
  });

  final MsgrAudioMessage audio;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveform = audio.waveform ?? const [];
    final samples = waveform.isNotEmpty
        ? waveform.take(40).toList(growable: false)
        : const [0.15, 0.35, 0.22, 0.55, 0.28, 0.48, 0.32];
    final duration = audio.duration;
    final durationLabel = duration != null ? _formatDuration(duration) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMine
            ? theme.colorScheme.onPrimaryContainer.withOpacity(0.08)
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                audio.kind == MsgrMessageKind.voice
                    ? Icons.mic
                    : Icons.audiotrack,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  audio.caption?.isNotEmpty == true
                      ? audio.caption!
                      : audio.mimeType ?? 'Lydklipp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (durationLabel != null)
                Text(
                  durationLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final sample in samples)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.2),
                      child: Container(
                        height: math.max(12, 40 * sample.clamp(0.08, 1.0)),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAttachmentView extends StatelessWidget {
  const _VideoAttachmentView({required this.video});

  final MsgrVideoMessage video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = video.thumbnailUrl;
    final duration = video.duration;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: thumbnail != null && thumbnail.isNotEmpty
                ? Image.network(
                    thumbnail,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        if (duration != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FileAttachmentView extends StatelessWidget {
  const _FileAttachmentView({
    required this.file,
    required this.isMine,
  });

  final MsgrFileMessage file;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeLabel =
        file.byteSize != null ? _formatBytes(file.byteSize!) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMine
            ? theme.colorScheme.onPrimaryContainer.withOpacity(0.08)
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.insert_drive_file,
              color: theme.colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.fileName.isNotEmpty ? file.fileName : 'Vedlegg',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (file.mimeType != null || sizeLabel != null)
                  Text(
                    [file.mimeType, sizeLabel]
                        .where((value) => value != null && value.isNotEmpty)
                        .join(' • '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(double seconds) {
  final totalSeconds = seconds.round();
  final minutes = totalSeconds ~/ 60;
  final remainingSeconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  final rawExponent = (math.log(bytes) / math.log(1024)).floor();
  final exponent = rawExponent.clamp(0, units.length - 1) as int;
  final divisor = math.pow(1024, exponent).toDouble();
  final value = bytes / divisor;
  final precision = value >= 100 || exponent == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[exponent]}';
}
