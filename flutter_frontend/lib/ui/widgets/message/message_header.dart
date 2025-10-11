import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessageWidgetHeader extends StatelessWidget {
  final MMessage message;
  final Profile profile;
  const MessageWidgetHeader(
      {super.key, required this.message, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context).messageWidgetTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8.0),
            decoration: const BoxDecoration(color: Colors.yellow),
            child: Text(
              profile.toString(),
              style: theme.data.senderTextStyle,
            ),
          ),
        ),
        const SizedBox(width: 50.0),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 8.0),
            decoration: const BoxDecoration(color: Colors.green),
            child: Text(
              timeago.format(message.createdAt),
              textAlign: TextAlign.right,
              style: theme.data.timestampStyle,
            ),
          ),
        )
      ],
    );
  }
}
