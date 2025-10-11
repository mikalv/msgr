import 'dart:ui';

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
    final subtleColor = textColor.withOpacity(0.7);

    final mediaContent = _buildMediaContent(context, message.data, textColor, subtleColor);
    final bodyContent = _buildBodyContent(message.data, textColor);

    final children = <Widget>[];

    if (!isMine) {
      children.add(
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

    if (mediaContent != null) {
      children.add(mediaContent);
      if (bodyContent != null) {
        children.add(const SizedBox(height: 8));
      }
    }

    if (mediaContent == null && bodyContent == null) {
      children.add(
        SelectableText(
          message.body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: textColor,
            height: 1.4,
          ),
        ),
      );
    } else if (bodyContent != null) {
      children.add(bodyContent);
    }

    children.add(const SizedBox(height: 6));
    children.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (formattedTime.isNotEmpty)
            Text(
              formattedTime,
              style: theme.textTheme.labelSmall?.copyWith(
                color: subtleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (isMine) ...[
            const SizedBox(width: 6),
            _StatusIcon(message: message),
          ],
        ],
      ),
    );

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
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildMediaContent(
    BuildContext context,
    MsgrMessage data,
    Color textColor,
    Color subtleColor,
  ) {
    if (data is MsgrImageMessage) {
      final url = data.thumbnailUrl ?? data.url;
      if (url.isEmpty) {
        return null;
      }
      final ratio = _aspectRatio(
        data.width ?? data.thumbnailWidth,
        data.height ?? data.thumbnailHeight,
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => _BrokenMediaPlaceholder(
                  icon: Icons.broken_image_outlined,
                  color: subtleColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (data is MsgrVideoMessage) {
      final thumb = data.thumbnailUrl ?? data.url;
      final ratio = _aspectRatio(
        data.thumbnailWidth,
        data.thumbnailHeight,
        fallback: 16 / 9,
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.isNotEmpty)
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => _BrokenMediaPlaceholder(
                    icon: Icons.video_library_outlined,
                    color: subtleColor,
                  ),
                )
              else
                _BrokenMediaPlaceholder(
                  icon: Icons.video_library_outlined,
                  color: subtleColor,
                ),
              Container(
                color: Colors.black.withOpacity(0.25),
              ),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (data is MsgrAudioMessage) {
      final isVoice = data.kind == MsgrMessageKind.voice;
      final icon = isVoice ? Icons.mic : Icons.graphic_eq;
      final duration = _formatDuration(data.duration);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 10),
            if (data.waveform != null)
              SizedBox(
                width: 120,
                height: 32,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    samples: data.waveform!,
                    color: textColor,
                  ),
                ),
              )
            else
              Text(
                isVoice ? 'Lydklipp' : 'Lydmelding',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor,
                    ),
              ),
            if (duration != null) ...[
              const SizedBox(width: 12),
              Text(
                duration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: subtleColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ],
        ),
      );
    }

    if (data is MsgrFileMessage) {
      final size = _formatBytes(data.byteSize);
      return Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (size != null)
                    Text(
                      size,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: subtleColor,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download, size: 18, color: subtleColor),
          ],
        ),
      );
    }

    return null;
  }

  Widget? _buildBodyContent(MsgrMessage data, Color textColor) {
    if (data is MsgrTextMessage) {
      return SelectableText(
        data.body,
        style: TextStyle(color: textColor, height: 1.4),
      );
    }

    if (data is MsgrMarkdownMessage) {
      return SelectableText(
        data.markdown,
        style: TextStyle(color: textColor, height: 1.4),
      );
    }

    if (data is MsgrCodeMessage) {
      return SelectableText(
        data.code,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
        ),
      );
    }

    if (data is MsgrImageMessage) {
      if ((data.description ?? '').isEmpty) {
        return null;
      }
      return Text(
        data.description!,
        style: TextStyle(color: textColor, height: 1.3),
      );
    }

    if (data is MsgrVideoMessage) {
      if ((data.caption ?? '').isEmpty) {
        return null;
      }
      return Text(
        data.caption!,
        style: TextStyle(color: textColor, height: 1.3),
      );
    }

    if (data is MsgrAudioMessage) {
      if ((data.caption ?? '').isEmpty) {
        return null;
      }
      return Text(
        data.caption!,
        style: TextStyle(color: textColor, height: 1.3),
      );
    }

    if (data is MsgrFileMessage) {
      final caption = data.caption;
      if (caption == null || caption.isEmpty) {
        return null;
      }
      return Text(
        caption,
        style: TextStyle(color: textColor, height: 1.3),
      );
    }

    if (data is MsgrSystemMessage) {
      return Text(
        data.text,
        style: TextStyle(color: textColor, height: 1.3),
      );
    }

    if (data is MsgrLocationMessage) {
      return Text(
        data.label ?? '',
        style: TextStyle(color: textColor, height: 1.3),
      );
    }

    return null;
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

class _BrokenMediaPlaceholder extends StatelessWidget {
  const _BrokenMediaPlaceholder({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.08),
      child: Center(
        child: Icon(icon, size: 32, color: color.withOpacity(0.8)),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final step = width / samples.length;

    for (var i = 0; i < samples.length; i++) {
      final normalized = (samples[i] / 100).clamp(0.0, 1.0);
      final lineHeight = normalized * height;
      final x = i * step + step / 2;
      final yStart = (height - lineHeight) / 2;
      final yEnd = yStart + lineHeight;
      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}

double _aspectRatio(int? width, int? height, {double fallback = 4 / 3}) {
  if (width == null || width <= 0 || height == null || height <= 0) {
    return fallback;
  }
  return width / height;
}

String? _formatDuration(double? seconds) {
  if (seconds == null) return null;
  final duration = Duration(milliseconds: (seconds * 1000).round());
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$secs';
}

String? _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  if (unitIndex == 0) {
    return '${value.toInt()} ${units[unitIndex]}';
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}
