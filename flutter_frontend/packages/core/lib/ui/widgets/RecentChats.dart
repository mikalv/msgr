import 'package:flutter/material.dart';
import 'package:core/ui/widgets/conversation/conversations_list_widget.dart';
import 'package:core/ui/widgets/channel/channel_list_widget.dart';

class RecentChats extends StatelessWidget {
  const RecentChats({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            ChannelListWidget(context: context),
            ConversationsListWidget(context: context)
          ],
        ),
      ),
    );
  }
}
