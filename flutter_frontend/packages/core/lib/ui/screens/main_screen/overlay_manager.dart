import 'package:flutter/widgets.dart';

class MsgrOverlayManager {
  static final MsgrOverlayManager appLoader = MsgrOverlayManager();
  ValueNotifier<bool> loaderShowingNotifier = ValueNotifier(true);

  void showOverlay() {
    // show from anywhere
    loaderShowingNotifier.value = true;
  }

  void hideOverlay() {
    // using to hide from anywhere
    loaderShowingNotifier.value = false;
  }
}
