import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/ui/widgets/message/message_header.dart';
import 'package:messngr/utils/helpers.dart';

class MessageWidget extends StatelessWidget {
  final MMessage message;
  final String teamName;
  late final TeamRepositories repos;
  late final Profile profile;

  /// The action to perform when a link is tapped
  final void Function(String)? onLinkTap;

  MessageWidget(
      {super.key,
      this.onLinkTap,
      required this.message,
      required this.teamName}) {
    repos = LibMsgr().repositoryFactory.getRepositories(teamName);
    profile = repos.profileRepository.fetchByID(message.fromProfileID);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context).messageWidgetTheme;
    final Container msg = Container(
      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
      constraints: const BoxConstraints(minWidth: 200, minHeight: 100),
      width: 500,
      decoration: theme.data.mainMessageWidgetDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MessageWidgetHeader(message: message, profile: profile),
          const SizedBox(height: 8.0),
          MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: theme.data.messageTextStyle,
            ),
            extensionSet: md.ExtensionSet(
              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
              <md.InlineSyntax>[
                md.EmojiSyntax(),
                ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
              ],
            ),
            onTapLink: (
              String link,
              String? href,
              String title,
            ) {
              if (link.startsWith('@')) {
                /*final mentionedUser = message.mentionedUsers.firstWhereOrNull(
                (u) => '@${u.name}' == link,
              );*

              if (mentionedUser == null) return;

              onMentionTap?.call(mentionedUser);*/
              } else {
                if (onLinkTap != null) {
                  onLinkTap!(link);
                } else {
                  launchURL(context, link);
                }
              }
            },
          ),
        ],
      ),
    );

    return Row(
      children: <Widget>[
        msg,
        IconButton(
          icon: message.hasReactions
              ? const Icon(Icons.favorite)
              : const Icon(Icons.favorite_border),
          iconSize: 30.0,
          color: message.hasReactions
              ? Theme.of(context).primaryColor
              : Colors.blueGrey,
          onPressed: () {},
        )
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<MMessage>('message', message))
      ..add(DiagnosticsProperty('roomID', message.roomID))
      ..add(DiagnosticsProperty('conversationID', message.conversationID))
      ..add(DiagnosticsProperty('teamName', teamName))
      ..add(DiagnosticsProperty('createdAt', message.createdAt))
      ..add(DiagnosticsProperty('updatedAt', message.updatedAt))
      ..add(DiagnosticsProperty('isMsgRead', message.isMsgRead));
  }
}
