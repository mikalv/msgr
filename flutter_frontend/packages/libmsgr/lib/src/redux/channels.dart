import 'package:libmsgr/libmsgr.dart';

/// This is used when we get a (one) new channel from the server.
class OnReceiveNewChannelAction {
  final Channel channel;

  OnReceiveNewChannelAction(this.channel);

  @override
  String toString() {
    return 'OnReceiveNewChannelAction{channel: $channel}';
  }
}

/// This is used when we get the whole list of channels from the server.
class OnReceiveChannelsAction {
  final List<Channel> channels;

  OnReceiveChannelsAction({required this.channels});

  @override
  String toString() {
    return 'OnReceiveChannelsAction{channels: $channels}';
  }
}
