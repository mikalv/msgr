import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messngr/config/theme/app_scaffold_theme.dart';
import 'package:messngr/config/theme/channel_list_view_theme.dart';
import 'package:messngr/config/theme/color_theme.dart';
import 'package:messngr/config/theme/message_widget_theme.dart';
import 'package:messngr/config/theme/text_theme.dart';

/// {@template appTheme}
/// Inherited widget providing the [AppThemeData] to the widget tree
/// {@endtemplate}
class AppTheme extends InheritedWidget {
  /// {@macro appTheme}
  const AppTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// {@macro appThemeData}
  final AppThemeData data;

  @override
  bool updateShouldNotify(AppTheme oldWidget) => data != oldWidget.data;

  /// Use this method to get the current [AppThemeData] instance
  static AppThemeData of(BuildContext context) {
    final appTheme = context.dependOnInheritedWidgetOfExactType<AppTheme>();

    assert(
      appTheme != null,
      'You must have a AppTheme widget at the top of your widget tree',
    );

    return appTheme!.data;
  }
}

class AppThemeData {
  /// The text themes used in the widgets
  final AppTextTheme textTheme;

  /// The color themes used in the widgets
  final AppColorTheme colorTheme;

  /// Theme for listing of both Room and Conversation, together aka Channel
  final ChannelListViewTheme channelListViewTheme;

  /// Theme for the message widget
  final MessageWidgetTheme messageWidgetTheme;

  /// App scaffold theme
  final AppScaffoldTheme appScaffoldTheme;

  factory AppThemeData({
    Brightness? brightness,
    AppTextTheme? textTheme,
    AppColorTheme? colorTheme,
    ChannelListViewTheme? channelListViewTheme,
    MessageWidgetTheme? messageWidgetTheme,
    AppScaffoldTheme? appScaffoldTheme,
  }) {
    brightness ??= colorTheme?.brightness ?? Brightness.light;
    final isDark = brightness == Brightness.dark;
    textTheme ??= isDark ? AppTextTheme.dark() : AppTextTheme.light();
    colorTheme ??= isDark ? AppColorTheme.dark() : AppColorTheme.light();
    return AppThemeData.raw(
      colorTheme: colorTheme,
      textTheme: textTheme,
      appScaffoldTheme: appScaffoldTheme ??
          AppScaffoldTheme(
            data: AppScaffoldThemeData(
              backgroundColor: colorTheme.appBg,
            ),
            child: const SizedBox(),
          ),
      channelListViewTheme: channelListViewTheme ??
          ChannelListViewTheme(
            data: ChannelListViewThemeData(
                primaryColor: colorTheme.accentPrimary,
                backgroundColor: colorTheme.appBg,
                margin:
                    const EdgeInsets.only(top: 5.0, bottom: 5.0, right: 20.0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 70, 79, 183),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                mainListHeaderStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                titleStyle: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
                messagePreviewStyle: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                ),
                unreadMessageCountStyle: const TextStyle(
                  color: Color.fromARGB(255, 200, 211, 216),
                  fontSize: 10.0,
                ),
                unreadMessageCountDecoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                timestampStyle: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12.0,
                )),
            child: const SizedBox(),
          ),
      messageWidgetTheme: messageWidgetTheme ??
          MessageWidgetTheme(
            data: MessageWidgetThemeData(
                titleStyle: textTheme.headlineBold,
                messageTextStyle: const TextStyle(
                  color: Color.fromARGB(255, 128, 128, 128),
                  fontSize: 14.0,
                ),
                senderTextStyle: const TextStyle(
                  color: Color.fromARGB(255, 8, 16, 19),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
                timestampStyle: const TextStyle(
                  color: Color.fromARGB(255, 194, 85, 237),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                ),
                mainMessageWidgetDecoration: const BoxDecoration(
                  color: Color.fromARGB(255, 96, 201, 194),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(15.0),
                    bottomRight: Radius.circular(15.0),
                  ),
                )),
            child: const SizedBox(),
          ),
    );
  }

  factory AppThemeData.fromColorAndTextTheme(
    AppColorTheme colorTheme,
    AppTextTheme textTheme,
  ) {
    return AppThemeData.raw(
        colorTheme: colorTheme,
        textTheme: textTheme,
        appScaffoldTheme: AppScaffoldTheme(
          data: AppScaffoldThemeData(
            backgroundColor: colorTheme.appBg,
          ),
          child: Container(),
        ),
        channelListViewTheme: ChannelListViewTheme(
          data: ChannelListViewThemeData(
            primaryColor: colorTheme.accentPrimary,
            backgroundColor: colorTheme.appBg,
          ),
          child: Container(),
        ),
        messageWidgetTheme: MessageWidgetTheme(
          data: MessageWidgetThemeData(
            titleStyle: textTheme.title,
            messageTextStyle: textTheme.body,
          ),
          child: Container(),
        ));
  }

  CupertinoThemeData getCupertinoThemeData(Brightness? brightness) {
    return CupertinoThemeData(
      barBackgroundColor: const Color.fromRGBO(0, 0, 0, 0.0),
      scaffoldBackgroundColor: const Color.fromRGBO(0, 0, 0, 0.0),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontSize: 14,
          color: brightness == Brightness.dark
              ? const Color.fromRGBO(255, 255, 255, 1.0)
              : const Color.fromRGBO(0, 0, 0, 1.0),
        ),
      ),
    );
  }

  /// Theme initialized with light
  factory AppThemeData.light() => AppThemeData(brightness: Brightness.light);

  /// Theme initialized with dark
  factory AppThemeData.dark() => AppThemeData(brightness: Brightness.dark);

  const AppThemeData.raw({
    required this.textTheme,
    required this.colorTheme,
    required this.channelListViewTheme,
    required this.appScaffoldTheme,
    required this.messageWidgetTheme,
  });
}
