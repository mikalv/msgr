import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/ui/widgets/message/message_widget.dart';
import 'package:messngr/ui/widgets/misc/better_stream_builder.dart';

typedef VoidCallBackWithFuture = Future<void> Function();

class MessageListWidget extends StatefulWidget {
  MessageListWidget(
      {super.key,
      this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
      ScrollController? scrollController,
      required this.stream,
      required this.teamName,
      this.physics,
      this.shrinkWrap = false,
      this.padding,
      this.reverse = false,
      this.primary,
      this.scrollDirection = Axis.vertical,
      this.cacheExtent,
      this.loadingWidget,
      this.loadMoreData,
      this.isLastPage = false,
      this.showTypingIndicator = true})
      : _scrollController = scrollController ?? ScrollController();

  /// Provides widget for loading view while pagination is enabled.
  final Widget? loadingWidget;

  /// Provides callback when user actions reaches to top and needs to load more
  /// chat
  final VoidCallBackWithFuture? loadMoreData;

  /// Provides flag if there is no more next data left in list.
  final bool? isLastPage;

  /// Provides flag for turn on/off typing indicator.
  final bool showTypingIndicator;

  /// {@template flutter.widgets.scroll_view.keyboardDismissBehavior}
  /// [ScrollViewKeyboardDismissBehavior] the defines how this [ScrollView] will
  /// dismiss the keyboard automatically.
  /// {@endtemplate}
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// {@template flutter.widgets.scroll_view.physics}
  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// Defaults to matching platform conventions. Furthermore, if [primary] is
  /// false, then the user cannot scroll if there is insufficient content to
  /// scroll, while if [primary] is true, they can always attempt to scroll.
  ///
  /// To force the scroll view to always be scrollable even if there is
  /// insufficient content, as if [primary] was true but without necessarily
  /// setting it to true, provide an [AlwaysScrollableScrollPhysics] physics
  /// object, as in:
  ///
  /// ```dart
  ///   physics: const AlwaysScrollableScrollPhysics(),
  /// ```
  ///
  /// To force the scroll view to use the default platform conventions and not
  /// be scrollable if there is insufficient content, regardless of the value of
  /// [primary], provide an explicit [ScrollPhysics] object, as in:
  ///
  /// ```dart
  ///   physics: const ScrollPhysics(),
  /// ```
  ///
  /// The physics can be changed dynamically (by providing a new object in a
  /// subsequent build), but new physics will only take effect if the _class_ of
  /// the provided object changes. Merely constructing a new instance with a
  /// different configuration is insufficient to cause the physics to be
  /// reapplied. (This is because the final object used is generated
  /// dynamically, which can be relatively expensive, and it would be
  /// inefficient to speculatively create this object each frame to see if the
  /// physics should be updated.)
  /// {@endtemplate}
  ///
  /// If an explicit [ScrollBehavior] is provided to [scrollBehavior], the
  /// [ScrollPhysics] provided by that behavior will take precedence after
  /// [physics].
  final ScrollPhysics? physics;

  /// {@template flutter.widgets.scroll_view.reverse}
  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  /// {@endtemplate}
  final bool reverse;

  /// {@template flutter.widgets.scroll_view.controller}
  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  ///
  /// Must be null if [primary] is true.
  ///
  /// A [ScrollController] serves several purposes. It can be used to control
  /// the initial scroll position (see [ScrollController.initialScrollOffset]).
  /// It can be used to control whether the scroll view should automatically
  /// save and restore its scroll position in the [PageStorage] (see
  /// [ScrollController.keepScrollOffset]). It can be used to read the current
  /// scroll position (see [ScrollController.offset]), or change it (see
  /// [ScrollController.animateTo]).
  /// {@endtemplate}
  final ScrollController _scrollController;

  /// {@template flutter.widgets.scroll_view.primary}
  /// Whether this is the primary scroll view associated with the parent
  /// [PrimaryScrollController].
  ///
  /// When this is true, the scroll view is scrollable even if it does not have
  /// sufficient content to actually scroll. Otherwise, by default the user can
  /// only scroll the view if it has sufficient content. See [physics].
  ///
  /// Also when true, the scroll view is used for default [ScrollAction]s. If a
  /// ScrollAction is not handled by an otherwise focused part of the
  /// application, the ScrollAction will be evaluated using this scroll view,
  /// for example, when executing [Shortcuts] key events like page up and down.
  ///
  /// On iOS, this also identifies the scroll view that will scroll to top in
  /// response to a tap in the status bar.
  /// {@endtemplate}
  ///
  /// Defaults to true when [scrollController] is null.
  final bool? primary;

  /// {@template flutter.widgets.scroll_view.shrinkWrap}
  /// Whether the extent of the scroll view in the [scrollDirection] should be
  /// determined by the contents being viewed.
  ///
  /// If the scroll view does not shrink wrap, then the scroll view will expand
  /// to the maximum allowed size in the [scrollDirection]. If the scroll view
  /// has unbounded constraints in the [scrollDirection], then [shrinkWrap] must
  /// be true.
  ///
  /// Shrink wrapping the content of the scroll view is significantly more
  /// expensive than expanding to the maximum allowed size because the content
  /// can expand and contract during scrolling, which means the size of the
  /// scroll view needs to be recomputed whenever the scroll position changes.
  ///
  /// Defaults to false.
  /// {@endtemplate}
  final bool shrinkWrap;

  /// {@template flutter.widgets.scroll_view.scrollDirection}
  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  /// {@endtemplate}
  final Axis scrollDirection;

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  final double? cacheExtent;

  final Stream<List<MMessage>> stream;

  final String teamName;

  /// The amount of space by which to inset the children.
  final EdgeInsetsGeometry? padding;

  @override
  State<MessageListWidget> createState() => _MessageListWidgetState();
}

class _MessageListWidgetState extends State<MessageListWidget> {
  final itemKey = GlobalKey();

  Future scrollToItem() async {
    final context = itemKey.currentContext!;
    await Scrollable.ensureVisible(context, alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return BetterStreamBuilder<List<MMessage>>(
      stream: widget.stream,
      errorBuilder: (context, error) {
        return Center(
          child: Text('An error occurred: $error'),
        );
      },
      noDataBuilder: (context) {
        return const Center(
          child: Text('There are no messages in this room yet. Write one :)'),
        );
      },
      comparator: const ListEquality().equals,
      builder: (context, List<MMessage> messages) {
        return ListView.builder(
          primary: widget.primary,
          reverse: widget.reverse,
          shrinkWrap: widget.shrinkWrap,
          physics: widget.physics,
          controller: widget._scrollController,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          scrollDirection: widget.scrollDirection,
          padding: widget.padding,
          cacheExtent: widget.cacheExtent,
          itemCount: messages.length,
          itemBuilder: (BuildContext context, int index) {
            final MMessage message = messages.elementAt(index);
            return MessageWidget(
                key: Key(message.id),
                message: message,
                teamName: widget.teamName);
          },
        );
      },
    );
  }
}
