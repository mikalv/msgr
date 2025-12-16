import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/utils/emoji_parser.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:redux/redux.dart';

extension ContextHelper on BuildContext {
  Store<AppState> get store {
    return StoreProvider.of<AppState>(this);
  }

  AppState get state {
    return store.state;
  }
}

/// Extensions on [Uri]
extension UriX on Uri {
  /// Return the URI adding the http scheme if it is missing
  Uri get withScheme {
    if (hasScheme) return this;
    return Uri.parse('http://${toString()}');
  }
}

/// Extension on String which implements different types string validations.
extension ValidateString on String {
  bool get isImageUrl {
    final imageUrlRegExp = RegExp(imageUrlRegExpression);
    return imageUrlRegExp.hasMatch(this) || startsWith('data:image');
  }

  bool get fromMemory => startsWith('data:image');

  bool get isAllEmoji {
    for (String s in EmojiParser().unemojify(this).split(' ')) {
      if (!s.startsWith(':') || !s.endsWith(':')) {
        return false;
      }
    }
    return true;
  }

  bool get isUrl => Uri.tryParse(this)?.isAbsolute ?? false;
}

extension DateTimeCompare on DateTime {
  bool isBeforeOrEqualTo(DateTime other) {
    return isBefore(other) || isAtSameMomentAs(other);
  }
}
