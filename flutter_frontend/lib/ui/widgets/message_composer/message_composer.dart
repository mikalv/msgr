import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/platform_ext.dart';

const _kCommandTrigger = '/';
const _kMentionTrigger = '@';

class MessageComposer extends StatefulWidget {
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextEditingController? controller;
  final Color backgroundColor;
  final Color submitButtonColor;
  final String hintText;
  final double height;

  /// The maximum lines of text the input can span.
  final int? maxLines;

  /// The minimum lines of text the input can span.
  final int? minLines;

  /// {@macro flutter.widgets.editableText.textCapitalization}
  final TextCapitalization textCapitalization;
  final Widget submitIcon;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  /// Restoration ID to save and restore the state of the MessageInput.
  final String? restorationId;

  /// Wrap [MessageComposer] with a [SafeArea widget]
  final bool? enableSafeArea;

  /// Maximum Height for the TextField to grow before it starts scrolling.
  final double maxHeight;

  /// Autofocus property passed to the TextField
  final bool autofocus;

  /// The focus node associated to the TextField.
  final FocusNode focusNode;

  /// Disable autoCorrect by passing false
  /// autoCorrect is enabled by default
  final bool autoCorrect;

  /// If true the attachments button will not be displayed.
  final bool disableAttachments;

  /// Use this property to hide/show the commands button.
  final bool showCommandsButton;

  /// The type of action button to use for the keyboard.
  final TextInputAction? textInputAction;

  /// The keyboard type assigned to the TextField.
  final TextInputType? keyboardType;

  /// Function called after sending the message.
  final void Function(MMessage)? onMessageSent;

  /// Function called right before sending the message.
  ///
  /// Use this to transform the message.
  final FutureOr<MMessage> Function(MMessage)? preMessageSending;

  /// Disable the mentions overlay by passing false
  /// Enabled by default
  final bool enableMentionsOverlay;

  const MessageComposer(
      {super.key,
      this.controller,
      this.backgroundColor = const Color.fromARGB(255, 28, 170, 90),
      this.submitButtonColor = Colors.red,
      required this.onChanged,
      required this.onSubmitted,
      this.textCapitalization = TextCapitalization.sentences,
      this.textInputAction = TextInputAction.send,
      this.height = 70.0,
      this.iconSize = 25.0,
      this.maxLines,
      this.minLines,
      this.autofocus = true,
      required this.focusNode,
      this.padding = const EdgeInsets.symmetric(horizontal: 8.0),
      this.submitIcon = const Icon(Icons.send),
      this.hintText = 'Send a message...',
      this.showCommandsButton = true,
      this.disableAttachments = false,
      this.onMessageSent,
      this.preMessageSending,
      this.maxHeight = 150,
      this.keyboardType = TextInputType.text,
      this.enableSafeArea = false,
      this.restorationId,
      this.enableMentionsOverlay = true,
      this.autoCorrect = true});

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
  }

  Widget buildTextField() {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAttachments(),
            LimitedBox(
              maxHeight: widget.maxHeight,
              maxWidth: MediaQuery.of(context).size.width - 200,
              child: Focus(
                skipTraversal: true,
                onKeyEvent: _handleKeyPressed,
                child: TextField(
                  key: const Key('messageInputText'),
                  autofocus: widget.autofocus,
                  maxLines: widget.maxLines,
                  textInputAction: widget.textInputAction,
                  controller: widget.controller,
                  textCapitalization: widget.textCapitalization,
                  restorationId: widget.restorationId,
                  onChanged: widget.onChanged,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                  ),
                  focusNode: widget.focusNode,
                  autocorrect: widget.autoCorrect,
                  keyboardType: widget.keyboardType,
                  onSubmitted: (value) => widget.onSubmitted!(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    return const SizedBox();
  }

  KeyEventResult _handleKeyPressed(FocusNode node, KeyEvent event) {
    if (kIsWeb || isDesktop) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        widget.onSubmitted!(widget.controller!.text);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding,
      height: widget.height,
      color: widget.backgroundColor,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.photo),
            iconSize: widget.iconSize,
            color: Theme.of(context).primaryColor,
            onPressed: () {},
          ),
          Flex(
            direction: Axis.horizontal,
            children: [
              buildTextField(),
              IconButton(
                icon: widget.submitIcon,
                iconSize: widget.iconSize,
                color: widget.submitButtonColor,
                onPressed: () {
                  widget.onSubmitted!(widget.controller!.text);
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}
