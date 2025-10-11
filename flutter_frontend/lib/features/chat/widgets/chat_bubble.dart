import 'dart:ui';
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
            child: _MessageContent(
              message: message,
              isMine: isMine,
              textColor: textColor,
              formattedTime: formattedTime,
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
